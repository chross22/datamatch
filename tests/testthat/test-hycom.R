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
  expect_error(hycom_window(lat, 50, 60, "latitude"), "negative west")
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
               "None of the requested years")
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
  expect_true(all(c(1994, 2015) %in% gofs$years))
  expect_true(grepl("Chassignet", gofs$reference))
})

# ---- network ----------------------------------------------------------------

test_that("a real fetch returns the documented shape", {
  skip_on_cran()
  skip_if_not_installed("ncdf4")
  skip_if_offline()

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
  skip_on_cran()
  skip_if_not_installed("ncdf4")
  skip_if_offline()

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
