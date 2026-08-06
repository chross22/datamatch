# Plotting is verified by what it returns and by the helpers underneath it: the
# functions return the data they drew, so the computation can be checked exactly
# even though the picture cannot. Each plot is sent to a null device, which still
# exercises every drawing call and so still fails on a malformed one.
plot_fixture <- function(months = 1:6, gap_in = integer(0), seed = 1) {
  set.seed(seed)
  out <- do.call(rbind, lapply(months, function(m) {
    g <- expand.grid(x = seq(-70, -69, by = 0.25), y = seq(42, 43, by = 0.25))
    g$SST <- 10 + m - (g$y - 42)
    g$CHL <- 1 + m / 10
    if (m %in% gap_in) g$CHL[sample(nrow(g), round(nrow(g) * 0.75))] <- NA
    g$YEAR <- 2020L
    g$MONTH <- as.integer(m)
    g$DAY <- 1L
    g
  }))
  sf::st_as_sf(out, coords = c("x", "y"), crs = 4326)
}

quietly <- function(expr) {
  path <- tempfile(fileext = ".png")
  grDevices::png(path)
  on.exit({
    grDevices::dev.off()
    unlink(path)
  }, add = TRUE)
  force(expr)
}

test_that("plot_env returns the raster it drew", {
  env <- plot_fixture()

  layer <- quietly(plot_env(env, "SST"))

  expect_s4_class(layer, "SpatRaster")
  expect_equal(names(layer), "SST")
  # One time step, not all of them.
  expect_equal(terra::ncell(layer), 25)
})

test_that("plot_env selects the time step it was asked for", {
  env <- plot_fixture()

  by_index <- quietly(plot_env(env, "SST", time = 3))
  by_name <- quietly(plot_env(env, "SST", time = c(MONTH = 3)))

  expect_equal(terra::values(by_index), terra::values(by_name))
  # SST is 10 + month - (lat - 42) over latitudes 42 to 43, so the area mean of
  # the third step is 10 + 3 - 0.5.
  expect_equal(mean(terra::values(by_index), na.rm = TRUE), 12.5)
})

test_that("plot_env defaults to the first covariate and the first step", {
  env <- plot_fixture()

  layer <- quietly(plot_env(env))

  expect_equal(names(layer), "SST")
  expect_equal(mean(terra::values(layer), na.rm = TRUE), 10.5)
})

test_that("an impossible time step is refused with what is available", {
  env <- plot_fixture()

  expect_error(quietly(plot_env(env, "SST", time = 99)), "outside the 6")
  expect_error(quietly(plot_env(env, "SST", time = c(MONTH = 99))), "No time step")
  expect_error(quietly(plot_env(env, "SST", time = c(NOPE = 1))), "not a time column")
})

test_that("plot_coverage measures the fraction of cells carrying a value", {
  # CHL is 75% missing in months 2 and 5 and complete elsewhere; SST never.
  env <- plot_fixture(gap_in = c(2, 5))

  coverage <- quietly(plot_coverage(env))

  sst <- coverage[coverage$variable == "SST", ]
  chl <- coverage[coverage$variable == "CHL", ]

  # The grid is 25 cells and 75% of them are blanked, which rounds to 19 removed.
  gapped <- (25 - round(25 * 0.75)) / 25

  expect_true(all(sst$coverage == 1))
  expect_equal(chl$coverage[c(2, 5)], c(gapped, gapped))
  expect_true(all(chl$coverage[-c(2, 5)] == 1))
})

test_that("plot_series reduces each step to one number per variable", {
  env <- plot_fixture()

  series <- quietly(plot_series(env, "SST"))

  expect_equal(nrow(series), 6)
  # SST is 10 + month - (lat - 42), and latitude runs 42 to 43, so the mean over
  # the area is 10 + month - 0.5.
  expect_equal(series$value, 10 + 1:6 - 0.5)
  expect_true(all(series$lower <= series$value))
  expect_true(all(series$upper >= series$value))
})

test_that("plot_series honours the summary it is given", {
  env <- plot_fixture()

  highest <- quietly(plot_series(env, "SST", fun = max))

  # The warmest cell each month is the southern edge, where the latitude term is 0.
  expect_equal(highest$value, 10 + 1:6)
})

test_that("plot_series refuses when nothing numeric is left to plot", {
  env <- plot_fixture()
  env$SRC <- factor("satellite")

  expect_error(quietly(plot_series(env, "SRC")), "No numeric variables")
})

test_that("plot_matched keeps unmatched observations rather than dropping them", {
  env <- plot_fixture(months = 1:2)
  observations <- sf::st_as_sf(
    data.frame(lon = c(-69.5, -69.5, -69.5), lat = c(42.5, 42.5, 42.5),
               YEAR = 2020L, MONTH = c(1L, 2L, 11L)),
    coords = c("lon", "lat"), crs = 4326)
  matched <- suppressWarnings(matchData(observations, env))

  values <- quietly(plot_matched(matched, "SST"))

  expect_length(values, 3)
  # November has no environmental data, so that observation is NA - and is still
  # one of the three points returned.
  expect_true(is.na(values[3]))
  expect_false(any(is.na(values[1:2])))
})

test_that("categorical columns can be mapped rather than erroring", {
  env <- plot_fixture()
  env$SRC <- factor(rep(c("satellite", "model"), length.out = nrow(env)),
                    levels = c("satellite", "model"))

  layer <- quietly(plot_env(env, "SRC"))

  expect_s4_class(layer, "SpatRaster")
  expect_setequal(stats::na.omit(unique(terra::values(layer)[, 1])), c(1, 2))
})

test_that("step labels drop components that never vary", {
  # A single year of monthly data should be labelled by month, not by a repeated
  # year that carries no information.
  one_year <- time_steps(plot_fixture())
  expect_equal(one_year$labels, sprintf("%02d", 1:6))

  two_years <- time_steps(rbind(plot_fixture(months = 1:2),
                                within(plot_fixture(months = 1:2), YEAR <- 2021L)))
  expect_true(all(grepl("^20[12][01]-", two_years$labels)))
})

test_that("time steps come back in chronological order", {
  # Downloads are assembled per work item and need not arrive sorted; a series
  # plotted in arrival order would be meaningless.
  env <- plot_fixture(months = 1:3)
  shuffled <- env[order(-env$MONTH), ]

  steps <- time_steps(shuffled)

  expect_equal(steps$table$MONTH, 1:3)
})

test_that("axis labelling thins out for long series", {
  expect_equal(pretty_steps(6), 1:6)
  expect_lte(length(pretty_steps(180)), 12)
  expect_equal(pretty_steps(180)[1], 1)
})
