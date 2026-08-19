# HYCOM is read over OPeNDAP, so the network tests are skipped by default. What
# is checked without it is the part that fails quietly: which variables need a
# depth index, how the grid window is cut, and what is refused up front.

test_that("every HYCOM entry is fully specified", {
  catalog <- hycom_variables()

  expect_gt(length(catalog), 0)
  for (name in names(catalog)) {
    entry <- catalog[[name]]
    for (field in c("variable", "label", "units", "description")) {
      expect_true(nzchar(entry[[field]] %||% ""),
                  info = paste(name, "is missing", field))
    }
    expect_true(is.logical(entry$surface), info = name)
  }
})

test_that("HYCOM reuses the shared names, with matching units", {
  shared <- intersect(names(hycom_variables()), names(copernicus_variables()))
  expect_true(all(c("SST", "SSS", "BOTT", "BOTS", "SSH", "UO", "VO") %in% shared))

  for (name in shared) {
    expect_equal(hycom_variables()[[name]]$units,
                 copernicus_variables()[[name]]$units,
                 info = paste(name, "has different units in the two catalogs"))
  }
})

test_that("bottom fields are their own variables, not depth levels", {
  # This is the reason to reach for HYCOM: GLORYS12V1 publishes no bottom
  # salinity and datamatch has to derive one from the whole depth column.
  expect_equal(hycom_variables()$BOTS$variable, "salinity_bottom")
  expect_false(hycom_variables()$BOTS$surface)
  expect_equal(hycom_variables()$BOTT$variable, "water_temp_bottom")

  # Surface entries do index into the depth axis.
  expect_true(hycom_variables()$SST$surface)
  expect_equal(hycom_variables()$SST$variable, "water_temp")
})

test_that("hycom_window cuts a contiguous slice from real coordinates", {
  # Deliberately non-uniform, as HYCOM's latitude axis is: anything derived from
  # values[2] - values[1] would be wrong at most latitudes.
  lat <- c(40.0, 40.04, 40.10, 40.20, 40.40, 40.80)

  window <- hycom_window(lat, 40.04, 40.20, "latitude")
  expect_equal(window$start, 2)
  expect_equal(window$count, 3)
  expect_equal(window$values, c(40.04, 40.10, 40.20))

  expect_error(hycom_window(lat, 50, 60, "latitude"),
               "selects no latitude")
})

test_that("an unknown variable or archive is refused before connecting", {
  bb <- list(xmin = -69, xmax = -68, ymin = 43, ymax = 44)

  expect_error(accessHYCOM(vars = c("SST", "CHL"), years = 2010, months = 6,
                           bounding_box = bb),
               "Not HYCOM variables: CHL")
  expect_error(accessHYCOM(vars = "SST", years = 2010, months = 6,
                           bounding_box = bb, archive = "nope"),
               "Unknown archive")
})

test_that("the requested hour must land on the model's step", {
  bb <- list(xmin = -69, xmax = -68, ymin = 43, ymax = 44)

  # HYCOM is three-hourly, so 13:00 does not exist and asking for it would
  # silently return nothing for every day.
  expect_error(accessHYCOM(vars = "SST", years = 2010, months = 6,
                           bounding_box = bb, hour = 13),
               "must be a multiple of 3")
  expect_error(accessHYCOM(vars = "SST", years = 2010, months = 6,
                           bounding_box = bb, hour = 25),
               "must be a multiple of 3")
})

test_that("years outside the archive are refused or warned about", {
  bb <- list(xmin = -69, xmax = -68, ymin = 43, ymax = 44)

  expect_error(accessHYCOM(vars = "SST", years = 1970, months = 6,
                           bounding_box = bb),
               "every requested day is outside it")
  expect_error(accessHYCOM(vars = "SST", bounding_box = bb),
               "`years` and `months` are required")
  expect_error(accessHYCOM(vars = "SST", years = 2010, months = 6,
                           dates = "2010-06-01", bounding_box = bb),
               "already names which days")
})

test_that("a bounding box missing an edge says which", {
  expect_error(accessHYCOM(vars = "SST", years = 2010, months = 6,
                           bounding_box = list(xmin = -69, xmax = -68)),
               "bounding_box is missing")
})

test_that("the archive catalog describes what it serves", {
  gofs <- hycom_archives()$GLBv53X

  expect_true(grepl("%d", gofs$url))
  expect_equal(gofs$step_hours, 3L)
  expect_equal(gofs$start, as.Date("1994-01-01"))
  expect_equal(gofs$end, as.Date("2015-12-31"))
  expect_true(grepl("Chassignet", gofs$reference))
})

# ---- network ----------------------------------------------------------------

test_that("a real fetch returns the documented shape", {
  skip_if_no_network()

  bb <- list(xmin = -69, xmax = -68.5, ymin = 43, ymax = 43.5)
  hy <- try(accessHYCOM(vars = c("SST", "BOTT", "BOTS"),
                        dates = "2010-06-15", bounding_box = bb), silent = TRUE)
  skip_if(inherits(hy, "try-error"), "HYCOM THREDDS server unreachable")

  expect_s3_class(hy, "sf")
  expect_true(all(c("SST", "BOTT", "BOTS", "YEAR", "MONTH", "DAY") %in% names(hy)))
  expect_equal(attr(hy, "datamatch_step"), "day")
  # A daily snapshot carries no HOUR; only the three-hourly form does.
  expect_false("HOUR" %in% names(hy))

  # Gulf of Maine in June: warm surface over cold, salty bottom water. A check
  # that the fields are not swapped, not a validation of the model.
  expect_true(all(hy$SST > 5 & hy$SST < 25))
  expect_true(all(hy$BOTT < hy$SST))
  expect_true(all(hy$BOTS > 30 & hy$BOTS < 36))
})

test_that("three-hourly carries an HOUR column and aggregates to a daily mean", {
  skip_if_no_network()

  bb <- list(xmin = -69, xmax = -68.5, ymin = 43, ymax = 43.5)
  steps <- try(accessHYCOM(vars = "SST", frequency = "3hourly",
                           dates = "2010-06-15", bounding_box = bb),
               silent = TRUE)
  skip_if(inherits(steps, "try-error"), "HYCOM THREDDS server unreachable")

  expect_true("HOUR" %in% names(steps))
  expect_equal(attr(steps, "datamatch_step"), "hour")
  expect_equal(detect_temporal_resolution(steps), "hour")
  # Every hour present must land on the three-hourly step.
  expect_true(all(unique(steps$HOUR) %% 3 == 0))

  # And it must aggregate without tripping the coverage check, which would
  # happen if the denominator were assumed to be 24 rather than 8.
  daily <- upscale_time(steps, to = "day")
  expect_false("HOUR" %in% names(daily))
  expect_false(all(is.na(daily$SST)))
  expect_equal(detect_temporal_resolution(daily), "day")
})

# ---- the archive chain ------------------------------------------------------

test_that("the archives reach from the reanalysis to 2024", {
  archives <- hycom_archives()

  expect_true(all(c("GLBv53X", "GLBy930") %in% names(archives)))
  expect_equal(archives$GLBv53X$kind, "reanalysis")
  # Everything after the reanalysis is operational output, not a reanalysis.
  for (name in setdiff(names(archives), "GLBv53X")) {
    expect_equal(archives[[name]]$kind, "operational", info = name)
  }

  # Layout differs: the reanalysis is one dataset per year, the rest single
  # aggregations, and hycom_open() has to tell them apart.
  expect_equal(archives$GLBv53X$layout, "per_year")
  expect_true(grepl("%d", archives$GLBv53X$url))
  expect_equal(archives$GLBy930$layout, "single")
  expect_false(grepl("%d", archives$GLBy930$url))

  expect_equal(max(do.call(c, lapply(archives, function(a) a$end))),
               as.Date("2024-09-05"))
})

test_that("hycom_covering reports every archive spanning a date", {
  # The reanalysis alone early on.
  expect_equal(hycom_covering("2010-06-15"), "GLBv53X")

  # Overlapping, which is why nothing here picks one.
  expect_setequal(hycom_covering("2015-06-15"), c("GLBv53X", "GLBv563"))
  expect_setequal(hycom_covering("2019-06-15"), c("GLBv930", "GLBy930"))

  # Past the end of the record.
  expect_length(hycom_covering("2025-06-15"), 0)
})

test_that("a request outside an archive names the ones that hold it", {
  bb <- list(xmin = -69, xmax = -68.5, ymin = 43, ymax = 43.5)

  # A dead end is much less useful than the next call to make.
  expect_error(accessHYCOM(vars = "BOTS", dates = "2019-06-15",
                           bounding_box = bb),
               "GLBy930")
  expect_error(accessHYCOM(vars = "BOTS", dates = "2019-06-15",
                           bounding_box = bb),
               "every requested day is outside it")

  # Past every archive, there is nothing to point at. The date has to be in the
  # past for this to be the message that comes back: a future one is caught
  # earlier, by the check that it has not happened yet, which is the more useful
  # thing to say about it.
  expect_error(accessHYCOM(vars = "BOTS", dates = "2025-06-15",
                           bounding_box = bb),
               "No archive in hycom_archives")

  expect_error(accessHYCOM(vars = "BOTS", dates = "2030-06-15",
                           bounding_box = bb),
               "have not happened yet")
})

test_that("the longitude window handles both of HYCOM's conventions", {
  # GLBv0.08 runs -180 to 180; GLBy0.08 runs 0 to 360. The same box has to work
  # against either, which is not true of a naive comparison.
  west <- seq(-180, 179.92, by = 0.08)
  east <- seq(0, 359.92, by = 0.08)

  a <- hycom_lon_window(west, -69, -68.5)
  b <- hycom_lon_window(east, -69, -68.5)

  # Same cells, same returned coordinates, negative west from both.
  expect_equal(a$values, b$values, tolerance = 1e-8)
  expect_true(all(a$values >= -69 & a$values <= -68.5))
  expect_true(all(b$values >= -69 & b$values <= -68.5))

  # On a global 0-360 axis every longitude wraps to something real, so this can
  # only fail on a regional grid - which is the case worth checking anyway.
  regional <- seq(280, 300, by = 0.08)
  expect_error(hycom_lon_window(regional, 20, 30), "selects no longitude")
})

# Reading across archives. The network is not needed for any of this: what is
# checked is which archive each day is assigned to, that the seam is announced,
# and that provenance survives per row rather than collapsing to one label.

test_that("a continuous read prefers the reanalysis wherever it reaches", {
  archives <- hycom_archives()

  # 2014-07-01 onward is covered by GLBv563 as well, but GLBv53X runs to the end
  # of 2015 and is one consistent hindcast, so it wins while it lasts.
  chosen <- datamatch:::hycom_archive_per_day(
    as.Date(c("1995-01-01", "2014-08-01", "2015-12-31")), archives)
  expect_equal(unname(chosen), rep("GLBv53X", 3))
})

test_that("a continuous read falls through to the operational archives after 2015", {
  archives <- hycom_archives()

  chosen <- datamatch:::hycom_archive_per_day(as.Date("2019-06-15"), archives)
  expect_true(chosen %in% hycom_covering("2019-06-15"))
  expect_false(chosen == "GLBv53X")

  # Every day of the stated record gets an archive.
  spread <- seq(as.Date("1994-06-01"), as.Date("2024-06-01"), by = "3 months")
  chosen <- datamatch:::hycom_archive_per_day(spread, archives)
  expect_false(any(is.na(chosen)))
})

test_that("days outside every archive come back NA rather than being invented", {
  archives <- hycom_archives()
  expect_true(is.na(datamatch:::hycom_archive_per_day(as.Date("1980-01-01"), archives)))
  expect_true(is.na(datamatch:::hycom_archive_per_day(as.Date("2030-01-01"), archives)))
})

test_that("an unknown archive names 'continuous' among the options", {
  expect_error(
    accessHYCOM(vars = "SST", dates = "2010-06-15", archive = "nope",
                bounding_box = list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)),
    "continuous"
  )
})

test_that("provenance is per row when a fetch spans archives", {
  # stamp_source() is where the two cases part: one tag for the object when a
  # fetch came from one archive, one tag per row when it did not.
  d <- sf::st_as_sf(
    data.frame(x = c(1, 2, 3), y = c(1, 2, 3), SST = c(4, 5, 6)),
    coords = c("x", "y"), crs = 4326)

  one <- stamp_source(d, "hycom", "GLBv53X")
  expect_equal(source_of(one), "hycom:GLBv53X")
  expect_null(datamatch:::row_sources(one))

  many <- stamp_source(d, "hycom", c("GLBv53X", "GLBv53X", "GLBy930"))
  expect_equal(datamatch:::row_sources(many),
               c("hycom:GLBv53X", "hycom:GLBv53X", "hycom:GLBy930"))
  expect_equal(source_of(many), "hycom:GLBv53X+hycom:GLBy930")
})

test_that("matchData carries a per-row source into <var>_source", {
  source_dat <- sf::st_as_sf(
    data.frame(x = c(-69, -67), y = c(42, 43), SST = c(8, 9),
               YEAR = c(2015L, 2019L), MONTH = c(6L, 6L), DAY = c(15L, 15L)),
    coords = c("x", "y"), crs = 4326)
  source_dat <- stamp_source(source_dat, "hycom", c("GLBv53X", "GLBy930"))

  obs <- sf::st_as_sf(
    data.frame(x = c(-69, -67), y = c(42, 43),
               YEAR = c(2015L, 2019L), MONTH = c(6L, 6L), DAY = c(15L, 15L)),
    coords = c("x", "y"), crs = 4326)

  matched <- matchData(obs, source_dat, temporal_resolution = "day")

  expect_equal(nrow(matched), 2)
  expect_equal(matched$SST_source, c("hycom:GLBv53X", "hycom:GLBy930"))
  # The bookkeeping column does not survive into the result.
  expect_false(".datamatch_source" %in% names(matched))
})
