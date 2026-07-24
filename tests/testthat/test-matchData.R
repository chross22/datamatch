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

# Environmental data: a small grid of points per YEAR/MONTH, each carrying
# a "thetao" value. Grid points are placed exactly on top of the species
# points so nearest-feature matching is deterministic.
make_env_dat <- function() {
  grid <- expand.grid(
    lon = c(-70.0, -69.5, -69.0),
    lat = c(42.0, 42.5, 43.0)
  )
  jan <- cbind(grid, YEAR = 2020, MONTH = 1, thetao = 10 + seq_len(nrow(grid)))
  feb <- cbind(grid, YEAR = 2020, MONTH = 2, thetao = 20 + seq_len(nrow(grid)))
  df <- rbind(jan, feb)

  sf::st_as_sf(df, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
}

# Tests ---------------------------------------------------------------------

test_that("matchData renames YEAR/MONTH/DAY columns regardless of input naming", {
  speciesDat <- make_species_dat(year_col = "Year", month_col = "Month", day_col = "Day")
  envDat <- make_env_dat()

  result <- matchData(speciesDat, envDat)

  expect_true(all(c("YEAR", "MONTH", "DAY") %in% names(result)))
})

test_that("matchData joins the correct environmental value via nearest feature", {
  speciesDat <- make_species_dat()
  envDat <- make_env_dat()

  result <- matchData(speciesDat, envDat)

  # Species point 1 sits exactly on env grid point 1 for Jan 2020
  expect_equal(result$thetao[result$id == 1], 11)
  # Species point 3 is in Feb 2020, should pull from the Feb subset
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
