# Helpers -----------------------------------------------------------------

# Species observations: points with known lon/lat and YEAR/MONTH/DAY columns.
make_species_dat <- function(year_col = "YEAR", month_col = "MONTH", day_col = "DAY") {
  df <- data.frame(
    id    = 1:3,
    lon   = c(-70.0, -69.5, -69.0),
    lat   = c(42.0, 42.5, 43.0),
    year  = c(2020, 2020, 2020),
    month = c(1, 1, 2),
    day   = c(1, 15, 1)
  )
  names(df)[names(df) == "year"]  <- year_col
  names(df)[names(df) == "month"] <- month_col
  names(df)[names(df) == "day"]   <- day_col

  sf::st_as_sf(df, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
}

# Environmental data: a small grid of points per YEAR/MONTH/DAY (matching
# accessEnvDat()'s real daily-resolution output shape), each carrying a
# "thetao" value. Grid points are placed exactly on top of the species points
# so nearest-feature matching is deterministic. Jan has two days (1 and 15,
# matching the two January species points below) with deliberately different
# thetao values at the same locations, so a test can confirm matchData()
# picks the value for the correct day rather than whichever day happens to
# come first in envDat.
make_env_dat <- function() {
  grid <- expand.grid(
    lon = c(-70.0, -69.5, -69.0),
    lat = c(42.0, 42.5, 43.0)
  )
  jan1 <- cbind(grid, YEAR = 2020, MONTH = 1, DAY = 1, thetao = 10 + seq_len(nrow(grid)))
  jan15 <- cbind(grid, YEAR = 2020, MONTH = 1, DAY = 15, thetao = 110 + seq_len(nrow(grid)))
  feb1 <- cbind(grid, YEAR = 2020, MONTH = 2, DAY = 1, thetao = 20 + seq_len(nrow(grid)))
  df <- rbind(jan1, jan15, feb1)

  sf::st_as_sf(df, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
}

# Tests ---------------------------------------------------------------------

test_that("matchData renames YEAR/MONTH/DAY columns regardless of input naming", {
  speciesDat <- make_species_dat(year_col = "Year", month_col = "Month", day_col = "Day")
  envDat <- make_env_dat()

  result <- matchData(speciesDat, envDat)

  expect_true(all(c("YEAR", "MONTH", "DAY") %in% names(result)))
})

test_that("matchData joins the correct environmental value via nearest feature and matching day", {
  speciesDat <- make_species_dat()
  envDat <- make_env_dat()

  result <- matchData(speciesDat, envDat)

  # Species point 1: Jan 1 2020, sits exactly on env grid point 1 -> the Jan-1 value
  expect_equal(result$thetao[result$id == 1], 11)
  # Species point 2: Jan 15 2020 at lon=-69.5/lat=42.5 (grid point 5) - must
  # pull the Jan-15 value (115), not Jan-1's (15) at that same location, which
  # is exactly the bug this test guards against (matching by YEAR/MONTH only,
  # ignoring DAY, previously let the join pick either day's value arbitrarily)
  expect_equal(result$thetao[result$id == 2], 115)
  # Species point 3: Feb 1 2020, should pull from the Feb subset
  expect_equal(result$thetao[result$id == 3], 29)
})

test_that("matchData returns one row per species observation", {
  speciesDat <- make_species_dat()
  envDat <- make_env_dat()

  result <- matchData(speciesDat, envDat)

  expect_equal(nrow(result), nrow(speciesDat))
})

test_that("matchData assigns LAT and LON correctly (not swapped)", {
  speciesDat <- make_species_dat()
  envDat <- make_env_dat()

  result <- matchData(speciesDat, envDat)
  row <- result[result$id == 1, ]

  expect_equal(row$LON, -70.0, tolerance = 1e-6)
  expect_equal(row$LAT, 42.0, tolerance = 1e-6)
})

test_that("matchData drops YEAR/MONTH duplication from the env side", {
  speciesDat <- make_species_dat()
  envDat <- make_env_dat()

  result <- matchData(speciesDat, envDat)

  # YEAR/MONTH should appear exactly once each (from speciesDat), not duplicated
  expect_equal(sum(names(result) == "YEAR"), 1)
  expect_equal(sum(names(result) == "MONTH"), 1)
})

# Monthly-resolution environmental data ------------------------------------

# Monthly products (e.g. Copernicus "...P1M-m" means) carry one time step per
# month, conventionally stamped on a single nominal day. Observations still fall
# on arbitrary days, so a day-exact join would match nothing.
make_monthly_env_dat <- function(nominal_day = 1) {
  grid <- expand.grid(
    lon = c(-70.0, -69.5, -69.0),
    lat = c(42.0, 42.5, 43.0)
  )
  jan <- cbind(grid, YEAR = 2020, MONTH = 1, DAY = nominal_day, thetao = 10 + seq_len(nrow(grid)))
  feb <- cbind(grid, YEAR = 2020, MONTH = 2, DAY = nominal_day, thetao = 20 + seq_len(nrow(grid)))
  df <- rbind(jan, feb)

  sf::st_as_sf(df, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
}

test_that("detect_temporal_resolution reads resolution off the time steps", {
  expect_equal(detect_temporal_resolution(make_env_dat()), "day")
  expect_equal(detect_temporal_resolution(make_monthly_env_dat()), "month")
})

test_that("detect_temporal_resolution prefers month over year when ambiguous", {
  # One month of monthly data looks identical to one year of annual data. Falling
  # back to "month" keeps unmatched observations unmatched (and warned about),
  # rather than silently matching them to another month's time step.
  one_month <- make_monthly_env_dat()
  one_month <- one_month[one_month$MONTH == 1, ]
  expect_equal(detect_temporal_resolution(one_month), "month")

  # Several years, each a single identical month, is positive evidence of annual data.
  annual <- rbind(
    cbind(expand.grid(lon = -70, lat = 42), YEAR = 2020, MONTH = 1, DAY = 1, thetao = 1),
    cbind(expand.grid(lon = -70, lat = 42), YEAR = 2021, MONTH = 1, DAY = 1, thetao = 2)
  )
  annual <- sf::st_as_sf(annual, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
  expect_equal(detect_temporal_resolution(annual), "year")
})

test_that("matchData matches monthly env data whose nominal day never matches observations", {
  speciesDat <- make_species_dat()
  # Env data is stamped on day 15; observations are on days 1 and 15. A day-exact
  # join would drop both January-day-1 and February-day-1 observations entirely.
  envDat <- make_monthly_env_dat(nominal_day = 15)

  result <- matchData(speciesDat, envDat)

  expect_equal(nrow(result), nrow(speciesDat))
  expect_false(any(is.na(result$thetao)))
  # Point 1: Jan, on grid point 1 -> January value at that location
  expect_equal(result$thetao[result$id == 1], 11)
  # Point 3: Feb, on grid point 5 -> February value
  expect_equal(result$thetao[result$id == 3], 29)
})

test_that("matchData still matches per-day when env data is daily", {
  speciesDat <- make_species_dat()
  envDat <- make_env_dat()

  # Explicitly requesting month resolution against daily data is ambiguous by
  # design; auto-detection is what keeps daily data matching per day.
  result <- matchData(speciesDat, envDat, temporal_resolution = "day")

  expect_equal(result$thetao[result$id == 2], 115)
})

test_that("matchData works on species data with no day column at monthly resolution", {
  speciesDat <- make_species_dat()
  speciesDat$DAY <- NULL
  envDat <- make_monthly_env_dat()

  result <- matchData(speciesDat, envDat)

  expect_equal(nrow(result), nrow(speciesDat))
  expect_false(any(is.na(result$thetao)))
})

test_that("matchData resolves an exact day column ahead of a prefix match", {
  speciesDat <- make_species_dat()
  speciesDat$dayofyear <- c(1, 15, 32)
  envDat <- make_env_dat()

  # Both "DAY" and "dayofyear" start with "day"; the exact match must win rather
  # than the lookup failing as ambiguous.
  expect_no_error(matchData(speciesDat, envDat))
})

test_that("matchData keeps observations in periods with no env data, as NA", {
  speciesDat <- make_species_dat()
  # Env data covers January only; the February observation has no match.
  envDat <- make_monthly_env_dat()
  envDat <- envDat[envDat$MONTH == 1, ]

  expect_warning(result <- matchData(speciesDat, envDat), "No environmental data")

  expect_equal(nrow(result), nrow(speciesDat))
  expect_true(is.na(result$thetao[result$id == 3]))
  expect_false(is.na(result$thetao[result$id == 1]))
})

test_that("matchData does not depend on the order periods appear in speciesDat", {
  speciesDat <- make_species_dat()
  envDat <- make_env_dat()

  # Reversing row order puts the chronologically last period first. The previous
  # implementation initialized its accumulator only on the chronologically first
  # period, so this ordering made it fail outright.
  reversed <- speciesDat[rev(seq_len(nrow(speciesDat))), ]

  result <- matchData(reversed, envDat)

  expect_equal(nrow(result), nrow(speciesDat))
  expect_equal(result$thetao[result$id == 2], 115)
})
