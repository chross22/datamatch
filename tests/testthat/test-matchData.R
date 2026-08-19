# Helpers -----------------------------------------------------------------

# Species observations: points with known lon/lat and YEAR/MONTH/DAY columns.
make_observations <- function(year_col = "YEAR", month_col = "MONTH", day_col = "DAY") {
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
# accessCopernicus()'s real daily-resolution output shape), each carrying a
# "thetao" value. Grid points are placed exactly on top of the species points
# so nearest-feature matching is deterministic. Jan has two days (1 and 15,
# matching the two January species points below) with deliberately different
# thetao values at the same locations, so a test can confirm matchData()
# picks the value for the correct day rather than whichever day happens to
# come first in env.
make_env <- function() {
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
  observations <- make_observations(year_col = "Year", month_col = "Month", day_col = "Day")
  env <- make_env()

  result <- matchData(observations, env)

  expect_true(all(c("YEAR", "MONTH", "DAY") %in% names(result)))
})

test_that("matchData joins the correct environmental value via nearest feature and matching day", {
  observations <- make_observations()
  env <- make_env()

  result <- matchData(observations, env)

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
  observations <- make_observations()
  env <- make_env()

  result <- matchData(observations, env)

  expect_equal(nrow(result), nrow(observations))
})

test_that("matchData assigns LAT and LON correctly (not swapped)", {
  observations <- make_observations()
  env <- make_env()

  result <- matchData(observations, env)
  row <- result[result$id == 1, ]

  expect_equal(row$LON, -70.0, tolerance = 1e-6)
  expect_equal(row$LAT, 42.0, tolerance = 1e-6)
})

test_that("matchData drops YEAR/MONTH duplication from the env side", {
  observations <- make_observations()
  env <- make_env()

  result <- matchData(observations, env)

  # YEAR/MONTH should appear exactly once each (from observations), not duplicated
  expect_equal(sum(names(result) == "YEAR"), 1)
  expect_equal(sum(names(result) == "MONTH"), 1)
})

# Monthly-resolution environmental data ------------------------------------

# Monthly products (e.g. Copernicus "...P1M-m" means) carry one time step per
# month, conventionally stamped on a single nominal day. Observations still fall
# on arbitrary days, so a day-exact join would match nothing.
make_monthly_env <- function(nominal_day = 1) {
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
  expect_equal(detect_temporal_resolution(make_env()), "day")
  expect_equal(detect_temporal_resolution(make_monthly_env()), "month")
})

test_that("detect_temporal_resolution prefers month over year when ambiguous", {
  # One month of monthly data looks identical to one year of annual data. Falling
  # back to "month" keeps unmatched observations unmatched (and warned about),
  # rather than silently matching them to another month's time step.
  one_month <- make_monthly_env()
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
  observations <- make_observations()
  # Env data is stamped on day 15; observations are on days 1 and 15. A day-exact
  # join would drop both January-day-1 and February-day-1 observations entirely.
  env <- make_monthly_env(nominal_day = 15)

  result <- matchData(observations, env)

  expect_equal(nrow(result), nrow(observations))
  expect_false(any(is.na(result$thetao)))
  # Point 1: Jan, on grid point 1 -> January value at that location
  expect_equal(result$thetao[result$id == 1], 11)
  # Point 3: Feb, on grid point 5 -> February value
  expect_equal(result$thetao[result$id == 3], 29)
})

test_that("matchData still matches per-day when env data is daily", {
  observations <- make_observations()
  env <- make_env()

  # Explicitly requesting month resolution against daily data is ambiguous by
  # design; auto-detection is what keeps daily data matching per day.
  result <- matchData(observations, env, temporal_resolution = "day")

  expect_equal(result$thetao[result$id == 2], 115)
})

test_that("matchData works on species data with no day column at monthly resolution", {
  observations <- make_observations()
  observations$DAY <- NULL
  env <- make_monthly_env()

  result <- matchData(observations, env)

  expect_equal(nrow(result), nrow(observations))
  expect_false(any(is.na(result$thetao)))
})

test_that("matchData resolves an exact day column ahead of a prefix match", {
  observations <- make_observations()
  observations$day_night <- c("D", "N", "D")
  env <- make_env()

  # Both "DAY" and "day_night" start with "day"; the exact match must win rather
  # than the lookup failing as ambiguous. "day_night" is used rather than a
  # day-of-year name because those are excluded before the tiebreak is reached.
  expect_no_error(matchData(observations, env))
})

# Time column lookup is a prefix match, on purpose ---------------------------

test_that("a prefixed time column is not recognised, but is named in the error", {
  observations <- make_observations(month_col = "obs_month")
  env <- make_env()

  # "obs_month" does not begin with "month", so it is not picked up. The error
  # has to point at it, or the user is left guessing which column was wanted.
  expect_error(matchData(observations, env), "no column for 'MONTH'")
  expect_error(matchData(observations, env), "obs_month")
})

test_that("a suffixed time column still works, since the match ignores case", {
  observations <- make_observations(month_col = "month_utc")
  env <- make_env()

  expect_no_error(matchData(observations, env))
})

test_that("a day-of-year column is never used as the day of the month", {
  observations <- make_observations(day_col = "jday")
  observations$jday <- c(1, 15, 32)
  env <- make_env()

  # "jday" is day-of-year. Taken as DAY it would group every row into a period
  # no source covers, and the join would come back all NA behind only a vague
  # warning. Erroring is the honest outcome; the message may suggest it, but
  # the rename is the user's to make.
  expect_error(matchData(observations, env), "no column for 'DAY'")
  expect_error(matchData(observations, env), "jday")
})

test_that("a yearday column is never used as the year", {
  observations <- make_observations(year_col = "yearday")
  observations$yearday <- c(1, 15, 32)
  env <- make_env()

  # "yearday" does begin with "year", so the prefix rule alone would accept it.
  expect_error(matchData(observations, env), "no column for 'YEAR'")
  expect_error(matchData(observations, env), "yearday")
})

test_that("an exact day column still wins over a day-of-year column beside it", {
  observations <- make_observations()
  observations$dayofyear <- c(1, 15, 32)
  env <- make_env()

  result <- matchData(observations, env)

  # Excluding day-of-year names must not disturb the ordinary case: DAY is used,
  # and "dayofyear" survives as one of `dat`'s own columns.
  expect_equal(result$thetao[result$id == 2], 115)
  expect_true("dayofyear" %in% names(result))
})

test_that("the missing-column error stays plain when nothing looks close", {
  observations <- make_observations()
  observations$MONTH <- NULL
  env <- make_env()

  message <- tryCatch(matchData(observations, env),
                      error = function(e) conditionMessage(e))

  expect_match(message, "no column for 'MONTH'")
  expect_false(grepl("similar name", message, fixed = TRUE))
})

test_that("matchData keeps observations in periods with no env data, as NA", {
  observations <- make_observations()
  # Env data covers January only; the February observation has no match.
  env <- make_monthly_env()
  env <- env[env$MONTH == 1, ]

  expect_warning(result <- matchData(observations, env), "No data in `source`")

  expect_equal(nrow(result), nrow(observations))
  expect_true(is.na(result$thetao[result$id == 3]))
  expect_false(is.na(result$thetao[result$id == 1]))
})

test_that("matchData does not depend on the order periods appear in observations", {
  observations <- make_observations()
  env <- make_env()

  # Reversing row order puts the chronologically last period first. The previous
  # implementation initialized its accumulator only on the chronologically first
  # period, so this ordering made it fail outright.
  reversed <- observations[rev(seq_len(nrow(observations))), ]

  result <- matchData(reversed, env)

  expect_equal(nrow(result), nrow(observations))
  expect_equal(result$thetao[result$id == 2], 115)
})

test_that("a missing CRS is named, on whichever side it is missing", {
  env <- sf::st_as_sf(
    data.frame(x = rep(seq(-70, -68, by = 1), 2), y = rep(c(42, 43), each = 3),
               SST = 1:6, YEAR = 2010L, MONTH = 1L, DAY = 1L),
    coords = c("x", "y"), crs = 4326)
  obs <- data.frame(lon = -69.5, lat = 42.2, YEAR = 2010L, MONTH = 1L)

  # sf's own message - "crs not found: is it missing?" - is true but says
  # neither which object nor what to do about it.
  expect_error(
    matchData(sf::st_as_sf(obs, coords = c("lon", "lat")), env),
    "`dat` has no coordinate reference system")

  env_no_crs <- env
  sf::st_crs(env_no_crs) <- NA
  expect_error(
    matchData(sf::st_as_sf(obs, coords = c("lon", "lat"), crs = 4326), env_no_crs),
    "`source` has no coordinate reference system")
})

test_that("projected observations match the same cells as geographic ones", {
  env <- sf::st_as_sf(
    data.frame(x = rep(seq(-70, -68, by = 0.5), 3), y = rep(c(42, 42.5, 43), each = 5),
               SST = 1:15, YEAR = 2010L, MONTH = 1L, DAY = 1L),
    coords = c("x", "y"), crs = 4326)
  obs <- data.frame(lon = c(-69.5, -68.5), lat = c(42.2, 42.7),
                    YEAR = 2010L, MONTH = 1L)

  geographic <- sf::st_as_sf(obs, coords = c("lon", "lat"), crs = 4326)
  projected <- sf::st_transform(geographic, 32619)

  expect_equal(suppressWarnings(matchData(projected, env))$SST,
               suppressWarnings(matchData(geographic, env))$SST)
})

test_that("the deprecated argument names still work, with a warning", {
  # taupatch and any script written against the old signature call these by
  # name. Breaking them silently would be worse than carrying the shim.
  observations <- make_observations()
  env <- make_env()

  # Both names warn, so both have to be caught or the second escapes the test.
  expect_warning(
    expect_warning(matchData(speciesDat = observations, envDat = env),
                   "`speciesDat` is now `dat`"),
    "`envDat` is now `source`")

  old <- suppressWarnings(matchData(speciesDat = observations, envDat = env))
  new <- matchData(dat = observations, source = env)

  expect_equal(sf::st_drop_geometry(old), sf::st_drop_geometry(new))
})

test_that("the new names work positionally and by name", {
  observations <- make_observations()
  env <- make_env()

  expect_equal(sf::st_drop_geometry(matchData(observations, env)),
               sf::st_drop_geometry(matchData(dat = observations, source = env)))
  expect_silent(matchData(observations, env))
})

test_that("a colliding column is suffixed rather than overwriting the caller's", {
  # The suffix is ".matched" now: the join is no longer specific to
  # environmental data, so ".env" described only one use of it.
  observations <- make_observations()
  env <- make_env()
  observations$thetao <- seq_len(nrow(observations)) * 100

  result <- matchData(observations, env)

  expect_true(all(c("thetao", "thetao.matched") %in% names(result)))
  # The caller's own column is untouched.
  expect_equal(result$thetao, seq_len(nrow(observations)) * 100)
})

test_that("neither side has to be observations or a covariate grid", {
  # The generalisation this rename is about: two gridded products matched to
  # each other, with nothing species-shaped involved.
  grid_a <- sf::st_as_sf(
    data.frame(x = rep(seq(-70, -69, by = 0.5), 2), y = rep(c(42, 43), each = 3),
               SST = 1:6, YEAR = 2010L, MONTH = 1L, DAY = 1L),
    coords = c("x", "y"), crs = 4326)
  grid_b <- sf::st_as_sf(
    data.frame(x = c(-69.75, -69.25), y = c(42, 43),
               CHL = c(0.5, 0.9), YEAR = 2010L, MONTH = 1L, DAY = 1L),
    coords = c("x", "y"), crs = 4326)

  result <- matchData(grid_a, grid_b)

  expect_equal(nrow(result), nrow(grid_a))
  expect_true(all(c("SST", "CHL") %in% names(result)))
  expect_false(anyNA(result$CHL))
})

test_that("rows come back in the order they went in", {
  # Rows are processed a period at a time, so without restoring the order they
  # come back grouped by period. Anyone aligning the result against the input by
  # position - cbind(), or assigning a column straight across - would get
  # silently mismatched rows, which is the worst kind of wrong.
  env <- sf::st_as_sf(
    do.call(rbind, lapply(1:3, function(m) {
      g <- expand.grid(x = c(-70, -69), y = c(42, 43))
      g$SST <- m
      g$YEAR <- 2015L
      g$MONTH <- as.integer(m)
      g$DAY <- 1L
      g
    })),
    coords = c("x", "y"), crs = 4326)

  # Deliberately out of period order, and with a period repeated.
  observations <- sf::st_as_sf(
    data.frame(lon = rep(-69.5, 4), lat = 42.5, YEAR = 2015L,
               MONTH = c(3L, 1L, 3L, 2L), id = 1:4),
    coords = c("lon", "lat"), crs = 4326)

  result <- matchData(observations, env)

  expect_equal(result$id, observations$id)
  # And the covariate follows its own row, not merely the row count.
  expect_equal(result$SST, observations$MONTH)

  # The bookkeeping column used to restore the order must not leak out.
  expect_false(any(grepl("datamatch_row", names(result))))
  expect_equal(rownames(result), as.character(seq_len(nrow(result))))
})

# ---- hourly matching --------------------------------------------------------

test_that("hourly source matches on the hour", {
  hours <- expand.grid(x = c(-70, -69.5), y = c(42, 42.5), HOUR = c(3L, 14L))
  hours$V <- ifelse(hours$HOUR == 3, 1, 99)
  hours$YEAR <- 2015L; hours$MONTH <- 6L; hours$DAY <- 15L
  source <- sf::st_as_sf(hours, coords = c("x", "y"), crs = 4326)
  attr(source, "datamatch_step") <- "hour"

  obs <- sf::st_as_sf(
    data.frame(x = c(-70, -70), y = c(42, 42),
               YEAR = 2015L, MONTH = 6L, DAY = 15L, HOUR = c(3L, 14L)),
    coords = c("x", "y"), crs = 4326)

  matched <- matchData(obs, source)

  # Two observations at one place, an hour apart, must not receive the same
  # value - which is exactly what matching at daily resolution would do.
  expect_equal(matched$V, c(1, 99))
})

test_that("an hour column is found however it is spelled", {
  hours <- expand.grid(x = -70, y = 42, HOUR = c(3L, 14L))
  hours$V <- c(1, 99)
  hours$YEAR <- 2015L; hours$MONTH <- 6L; hours$DAY <- 15L
  source <- sf::st_as_sf(hours, coords = c("x", "y"), crs = 4326)
  attr(source, "datamatch_step") <- "hour"

  obs <- sf::st_as_sf(
    data.frame(x = -70, y = 42, year = 2015L, month = 6L, day = 15L,
               Hour_utc = 14L),
    coords = c("x", "y"), crs = 4326)

  expect_equal(matchData(obs, source)$V, 99)
})

test_that("matching hourly against data with no hour says so", {
  source <- sf::st_as_sf(
    data.frame(x = -70, y = 42, V = 1, YEAR = 2015L, MONTH = 6L, DAY = 15L),
    coords = c("x", "y"), crs = 4326)
  obs <- sf::st_as_sf(
    data.frame(x = -70, y = 42, YEAR = 2015L, MONTH = 6L, DAY = 15L, HOUR = 3L),
    coords = c("x", "y"), crs = 4326)

  expect_error(matchData(obs, source, temporal_resolution = "hour"),
               "no HOUR column")
})

test_that("HOUR is not treated as a covariate to be joined on", {
  hours <- expand.grid(x = -70, y = 42, HOUR = c(3L, 14L))
  hours$V <- c(1, 99)
  hours$YEAR <- 2015L; hours$MONTH <- 6L; hours$DAY <- 15L
  source <- sf::st_as_sf(hours, coords = c("x", "y"), crs = 4326)
  attr(source, "datamatch_step") <- "hour"

  obs <- sf::st_as_sf(
    data.frame(x = -70, y = 42, YEAR = 2015L, MONTH = 6L, DAY = 15L, HOUR = 3L),
    coords = c("x", "y"), crs = 4326)

  matched <- matchData(obs, source)
  # The observation's own HOUR survives, and does not gain a .matched twin.
  expect_equal(matched$HOUR, 3L)
  expect_false("HOUR.matched" %in% names(matched))
})

# ---- geometries other than points -------------------------------------------

test_that("lines and polygons can be matched, not just points", {
  src <- sf::st_as_sf(expand.grid(x = c(-70, -69.5), y = c(42, 42.5)),
                      coords = c("x", "y"), crs = 4326)
  src$V <- 1:4
  src$YEAR <- 2020L; src$MONTH <- 1L; src$DAY <- 1L

  # A tow track and a statistical area, which are what survey data actually
  # looks like. Both used to fail on the LON/LAT assignment, because
  # st_coordinates() returns one row per vertex rather than per feature.
  track <- sf::st_sf(
    YEAR = 2020L, MONTH = 1L, DAY = 1L,
    geometry = sf::st_sfc(sf::st_linestring(rbind(c(-70, 42), c(-69.5, 42.5))),
                          crs = 4326))
  area <- sf::st_sf(
    YEAR = 2020L, MONTH = 1L, DAY = 1L,
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(-70, 42), c(-69.5, 42), c(-69.5, 42.5), c(-70, 42.5), c(-70, 42)))),
      crs = 4326))

  for (geometry in list(track, area)) {
    matched <- matchData(geometry, src)

    expect_equal(nrow(matched), 1)
    expect_false(is.na(matched$V))
    # One representative point per feature, not one per vertex.
    expect_length(matched$LON, 1)
    expect_length(matched$LAT, 1)
    # And it lies within the feature's own bounding box.
    box <- sf::st_bbox(geometry)
    expect_gte(matched$LON, box[["xmin"]])
    expect_lte(matched$LON, box[["xmax"]])
  }
})

test_that("points still report their own coordinates exactly", {
  src <- sf::st_as_sf(data.frame(x = -70, y = 42, V = 1, YEAR = 2020L,
                                 MONTH = 1L, DAY = 1L),
                      coords = c("x", "y"), crs = 4326)
  obs <- sf::st_as_sf(data.frame(x = -69.9, y = 42.1, YEAR = 2020L,
                                 MONTH = 1L, DAY = 1L),
                      coords = c("x", "y"), crs = 4326)

  # The representative-point path must not perturb ordinary point data.
  matched <- matchData(obs, src)
  expect_equal(matched$LON, -69.9)
  expect_equal(matched$LAT, 42.1)
})
