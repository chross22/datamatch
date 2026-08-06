# A regular grid of points over a fixed area, in the shape accessEnvDat() returns.
# `value` is a function of position, so what an aggregation should produce is
# known analytically rather than by comparison with the code under test.
grid_of <- function(res, months = 1L, value = function(x, y) y,
                    gap_fraction = 0, seed = 42) {
  set.seed(seed)
  out <- do.call(rbind, lapply(months, function(m) {
    g <- expand.grid(x = seq(-70, -69, by = res), y = seq(42, 43, by = res))
    g$V <- value(g$x, g$y)
    if (gap_fraction > 0) {
      g$V[sample(nrow(g), round(nrow(g) * gap_fraction))] <- NA
    }
    g$YEAR <- 2020L
    g$MONTH <- as.integer(m)
    g$DAY <- 1L
    g
  }))
  sf::st_as_sf(out, coords = c("x", "y"), crs = 4326)
}

test_that("grid_resolution reads the spacing off the coordinates", {
  expect_equal(unname(grid_resolution(grid_of(0.25))), c(0.25, 0.25))
  expect_equal(unname(grid_resolution(grid_of(0.1))), c(0.1, 0.1))
})

test_that("upscaling to a coarser grid produces the analytic cell mean", {
  # V is latitude, so the mean over a cell is the cell's centre latitude.
  coarse <- upscale_grid(grid_of(0.1), to = 0.5, min_coverage = 0)

  centres <- sf::st_coordinates(coarse)[, 2]
  expect_equal(coarse$V, centres, tolerance = 1e-8)
})

test_that("the resampled object keeps the input's shape", {
  fine <- grid_of(0.1, months = 1:3)
  coarse <- upscale_grid(fine, to = 0.5)

  expect_s3_class(coarse, "sf")
  expect_setequal(names(coarse), names(fine))
  expect_setequal(unique(coarse$MONTH), 1:3)
  expect_equal(unname(grid_resolution(coarse)), c(0.5, 0.5))
})

test_that("a stated resolution is anchored so two products land on one grid", {
  # The two sources have different extents and different resolutions. Upscaled to
  # the same target resolution they must land on identical cells, or joining them
  # is impossible - which is the entire reason for regridding.
  a <- grid_of(0.1)
  b <- sf::st_as_sf(
    data.frame(x = rep(seq(-69.93, -69.03, by = 0.05), 2),
               y = rep(c(42.07, 42.57), each = 19),
               V = 1, YEAR = 2020L, MONTH = 1L, DAY = 1L),
    coords = c("x", "y"), crs = 4326)

  ga <- upscale_grid(a, to = 0.25, min_coverage = 0)
  gb <- upscale_grid(b, to = 0.25, min_coverage = 0)

  ca <- sf::st_coordinates(ga)
  cb <- sf::st_coordinates(gb)
  # Every cell centre in the smaller result must coincide with one in the larger.
  expect_true(all(paste(cb[, 1], cb[, 2]) %in% paste(ca[, 1], ca[, 2])))
})

test_that("upscaling onto another object's grid adopts that grid exactly", {
  fine <- grid_of(0.1)
  coarse <- grid_of(0.5)

  onto <- upscale_grid(fine, to = coarse)

  expect_equal(unname(grid_resolution(onto)), unname(grid_resolution(coarse)))
  expect_setequal(
    paste(sf::st_coordinates(onto)[, 1], sf::st_coordinates(onto)[, 2]),
    paste(sf::st_coordinates(coarse)[, 1], sf::st_coordinates(coarse)[, 2]))
})

test_that("min_coverage turns a mostly-empty cell into NA", {
  gappy <- grid_of(0.1, gap_fraction = 0.7)

  strict <- upscale_grid(gappy, to = 0.5, min_coverage = 0.5)
  loose <- upscale_grid(gappy, to = 0.5, min_coverage = 0)

  # With 70% of source cells missing, no target cell clears half coverage.
  expect_true(all(is.na(strict$V)))
  # Without the guard the same cells all report a value, which is the point of
  # having the guard: the number is available either way and says nothing about
  # how much went into it.
  expect_false(any(is.na(loose$V)))
})

test_that("keep_counts reports the fraction behind each value", {
  gappy <- grid_of(0.1, gap_fraction = 0.5)

  out <- upscale_grid(gappy, to = 0.5, min_coverage = 0, keep_counts = TRUE)

  expect_true("V_coverage" %in% names(out))
  expect_true(all(out$V_coverage >= 0 & out$V_coverage <= 1))
  # Roughly half the source cells carried a value.
  expect_equal(mean(out$V_coverage), 0.5, tolerance = 0.2)
})

test_that("methods other than the mean give the summary they name", {
  fine <- grid_of(0.1)

  cell_min <- upscale_grid(fine, to = 0.5, method = "min", min_coverage = 0)
  cell_max <- upscale_grid(fine, to = 0.5, method = "max", min_coverage = 0)
  cell_mean <- upscale_grid(fine, to = 0.5, method = "mean", min_coverage = 0)

  expect_true(all(cell_min$V < cell_mean$V))
  expect_true(all(cell_max$V > cell_mean$V))
})

test_that("downscaling returns the finer grid over the same area", {
  coarse <- grid_of(0.5)

  fine <- downscale_grid(coarse, to = 0.1)

  expect_equal(unname(grid_resolution(fine)), c(0.1, 0.1))
  expect_gt(nrow(fine), nrow(coarse))
})

test_that("nearest replicates coarse values rather than inventing new ones", {
  coarse <- grid_of(0.5)

  fine <- downscale_grid(coarse, to = 0.1, method = "nearest")

  # Every fine value has to be one the coarse grid actually held.
  expect_true(all(stats::na.omit(fine$V) %in% coarse$V))
})

test_that("bilinear produces intermediate values that nearest does not", {
  coarse <- grid_of(0.5)

  smooth <- downscale_grid(coarse, to = 0.1, method = "bilinear")

  expect_gt(length(unique(stats::na.omit(smooth$V))), length(unique(coarse$V)))
})

test_that("idw fills gaps that bilinear and nearest propagate", {
  gappy <- grid_of(0.1, gap_fraction = 0.6)

  by_bilinear <- downscale_grid(gappy, to = 0.05, method = "bilinear")
  by_nearest <- downscale_grid(gappy, to = 0.05, method = "nearest")
  by_idw <- downscale_grid(gappy, to = 0.05, method = "idw")

  expect_gt(sum(is.na(by_bilinear$V)), 0)
  expect_gt(sum(is.na(by_nearest$V)), 0)
  # idw does not promise to fill everything - a target cell with no source point
  # inside the search radius still has nothing to draw on, and inventing one
  # from further away is the behaviour the radius exists to prevent. What it
  # promises is to fill across holes rather than propagate them, which is a
  # difference of degree large enough to assert.
  expect_lt(sum(is.na(by_idw$V)), sum(is.na(by_bilinear$V)) / 10)
})

test_that("gaps survive as NA rather than being dropped", {
  # A cell outside the study area and a cell over a cloud gap are both NA in the
  # raster. Only the first should disappear from the result.
  gappy <- grid_of(0.1, gap_fraction = 0.4)

  out <- downscale_grid(gappy, to = 0.05, method = "nearest")

  expect_gt(sum(is.na(out$V)), 0)
})

test_that("resampling the wrong way is refused and names the other function", {
  fine <- grid_of(0.1)
  coarse <- grid_of(0.5)

  expect_error(upscale_grid(coarse, to = 0.1), "downscale_grid")
  expect_error(downscale_grid(fine, to = 0.5), "upscale_grid")
  # The error has to show both resolutions, since the target is often another
  # dataset whose resolution is not visible at the call site.
  expect_error(upscale_grid(coarse, to = 0.1), "0.5")
})

test_that("categorical columns survive upscaling as factors", {
  fine <- grid_of(0.1)
  fine$SRC <- factor(rep(c("satellite", "model"), length.out = nrow(fine)),
                     levels = c("satellite", "model"))

  out <- upscale_grid(fine, to = 0.5, min_coverage = 0)

  expect_s3_class(out$SRC, "factor")
  expect_setequal(levels(out$SRC), c("satellite", "model"))
  expect_true(all(as.character(out$SRC) %in% c("satellite", "model")))
})

test_that("a blanket method leaves categorical columns to a safe one", {
  # Asking for the mean of the numeric variables should not require enumerating
  # every column just because a _source column came along for the ride.
  fine <- grid_of(0.1)
  fine$SRC <- factor(rep(c("satellite", "model"), length.out = nrow(fine)))

  expect_no_error(upscale_grid(fine, to = 0.5, method = "mean", min_coverage = 0))
  expect_no_error(downscale_grid(grid_of(0.5), to = 0.1, method = "bilinear"))
})

test_that("naming a categorical with an impossible method is an error", {
  fine <- grid_of(0.1)
  fine$SRC <- factor(rep(c("satellite", "model"), length.out = nrow(fine)))
  coarse <- grid_of(0.5)
  coarse$SRC <- factor(rep(c("satellite", "model"), length.out = nrow(coarse)))

  expect_error(upscale_grid(fine, to = 0.5, method = c(SRC = "mean")), "not numeric")
  # idw is refused for categoricals too: a distance-weighted average of level
  # codes lands between them and decodes to whichever level sits at that number.
  expect_error(downscale_grid(coarse, to = 0.1, method = c(SRC = "idw")), "not numeric")
})

test_that("per-variable methods are applied per variable", {
  fine <- grid_of(0.1)
  fine$W <- fine$V

  out <- upscale_grid(fine, to = 0.5, method = c(V = "min", W = "max"),
                      min_coverage = 0)

  expect_true(all(out$V < out$W))
})

test_that("unknown methods and columns are reported", {
  fine <- grid_of(0.1)

  expect_error(upscale_grid(fine, to = 0.5, method = "bilinear"), "Unknown method")
  expect_error(downscale_grid(grid_of(0.5), to = 0.1, method = "mean"), "Unknown method")
  expect_error(upscale_grid(fine, to = 0.5, vars = "NOPE"), "NOPE")
  expect_error(upscale_grid(fine, to = 0.5, method = c(NOPE = "mean")), "NOPE")
})

test_that("an invalid target is rejected before any work happens", {
  fine <- grid_of(0.1)

  expect_error(upscale_grid(fine, to = -1), "positive resolution")
  expect_error(upscale_grid(fine, to = "0.5"), "positive resolution")
})
