# CCMP is downloaded over HTTPS, so network tests are skipped by default. The
# rest checks what fails quietly: the longitude convention, which is unique to
# this source, and what is refused before 33 MB is fetched.

test_that("every CCMP entry is fully specified", {
  catalog <- ccmp_variables()

  expect_gt(length(catalog), 0)
  for (name in names(catalog)) {
    entry <- catalog[[name]]
    for (field in c("variable", "label", "units", "description")) {
      expect_true(nzchar(entry[[field]] %||% ""),
                  info = paste(name, "is missing", field))
    }
  }
})

test_that("CCMP reuses the wind names, with matching units", {
  shared <- intersect(names(ccmp_variables()), names(copernicus_variables()))
  expect_true(all(c("WSPD", "UWND", "VWND") %in% shared))

  for (name in shared) {
    expect_equal(ccmp_variables()[[name]]$units,
                 copernicus_variables()[[name]]$units,
                 info = paste(name, "has different units in the two catalogs"))
  }
})

test_that("asking CCMP for stress explains why it cannot have it", {
  bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

  # Stress is roughly quadratic in speed and needs a drag coefficient, so it is
  # not recoverable from these winds. Pointing at the source that has it beats
  # a bare "not a CCMP variable".
  expect_error(accessCCMP(vars = c("UWND", "TAUX"), dates = "2010-06-15",
                          bounding_box = bb),
               "Not CCMP variables: TAUX")
  expect_error(accessCCMP(vars = c("UWND", "TAUX"), dates = "2010-06-15",
                          bounding_box = bb),
               "carries no wind stress")
  expect_error(accessCCMP(vars = "TAU", dates = "2010-06-15",
                          bounding_box = bb),
               "accessEnvDat")
})

test_that("longitudes round-trip between the two conventions", {
  # CCMP is the one source here on a 0-360 grid. A Northwest Atlantic box asked
  # for as -70 would otherwise select a stretch of the Indian Ocean.
  expect_equal(to_360(-70), 290)
  expect_equal(to_360(-1), 359)
  expect_equal(to_360(0), 0)
  expect_equal(to_360(70), 70)

  expect_equal(to_180(290), -70)
  expect_equal(to_180(359), -1)
  expect_equal(to_180(70), 70)

  # Whatever a caller passes must come back unchanged.
  for (value in c(-179.875, -70, -0.125, 0.125, 70, 179.875)) {
    expect_equal(to_180(to_360(value)), value, info = as.character(value))
  }
})

test_that("the requested hour must be one CCMP analyses", {
  bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

  # Six-hourly, so 13:00 does not exist and would silently return nothing.
  expect_error(accessCCMP(vars = "WSPD", dates = "2010-06-15",
                          bounding_box = bb, hour = 13),
               "must be one of 0, 6, 12, 18")
  expect_error(accessCCMP(vars = "WSPD", dates = "2010-06-15",
                          bounding_box = bb, hour = 3),
               "must be one of")
})

test_that("days before the record begins are refused or warned about", {
  bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

  expect_error(accessCCMP(vars = "WSPD", dates = "1980-06-15",
                          bounding_box = bb),
               "begins 1993-01-01")
  expect_error(accessCCMP(vars = "WSPD", bounding_box = bb),
               "`years` and `months` are required")
  expect_error(accessCCMP(vars = "WSPD", years = 2010, months = 6,
                          dates = "2010-06-15", bounding_box = bb),
               "already names which days")
  expect_error(accessCCMP(vars = "WSPD", dates = "2010-06-15",
                          bounding_box = list(xmin = -70, xmax = -66)),
               "bounding_box is missing")
  expect_error(accessCCMP(vars = "WSPD", dates = "2010-06-15",
                          bounding_box = bb, version = "v99"),
               "Unknown CCMP version")
})

test_that("the version catalog describes what it serves", {
  spec <- ccmp_versions()$`v03.1`

  expect_true(grepl("^https", spec$root))
  expect_equal(spec$step_hours, 6L)
  expect_equal(spec$start, as.Date("1993-01-01"))
  expect_true(grepl("Mears", spec$reference))

  # The pattern takes year, month, then the full date.
  built <- sprintf(spec$pattern, 2010L, 6L, 2010L, 6L, 15L)
  expect_equal(built, "Y2010/M06/CCMP_Wind_Analysis_20100615_V03.1_L4.nc")
})

# ---- network ----------------------------------------------------------------

test_that("a real fetch returns negative-west coordinates", {
  skip_on_cran()
  skip_if_not_installed("ncdf4")
  skip_if_offline()

  bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
  wind <- try(accessCCMP(vars = c("UWND", "VWND", "WSPD"),
                         dates = "2010-06-15", bounding_box = bb), silent = TRUE)
  skip_if(inherits(wind, "try-error"), "RSS CCMP server unreachable")

  expect_s3_class(wind, "sf")
  expect_equal(attr(wind, "datamatch_step"), "day")

  # The whole point of the conversion: what comes back must overlay the other
  # sources, not sit 360 degrees away from them.
  coords <- sf::st_coordinates(wind)
  expect_true(all(coords[, 1] >= -70 & coords[, 1] <= -66))
  expect_true(all(coords[, 2] >= 41 & coords[, 2] <= 44))

  # WSPD is analysed separately but should still sit near the component
  # magnitude; far from it would mean the variables are mislabelled.
  magnitude <- sqrt(wind$UWND^2 + wind$VWND^2)
  expect_lt(max(abs(magnitude - wind$WSPD)), 1)
})

test_that("six-hourly carries four steps and aggregates to a daily mean", {
  skip_on_cran()
  skip_if_not_installed("ncdf4")
  skip_if_offline()

  bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
  steps <- try(accessCCMP(vars = c("UWND", "VWND"), frequency = "6hourly",
                          dates = "2010-06-15", bounding_box = bb),
               silent = TRUE)
  skip_if(inherits(steps, "try-error"), "RSS CCMP server unreachable")

  expect_setequal(unique(steps$HOUR), c(0L, 6L, 12L, 18L))
  expect_equal(detect_temporal_resolution(steps), "hour")
  # Four steps a day, not 24 - the coverage check has to know that or a whole
  # day would score a sixth of its coverage and come back NA.
  expect_equal(sub_daily_steps(sf::st_drop_geometry(steps)), 4L)

  daily <- upscale_time(steps, to = "day")
  expect_false(any(is.na(daily$UWND)))
  expect_equal(detect_temporal_resolution(daily), "day")
})
