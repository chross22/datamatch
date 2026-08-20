# A satellite series with cloud gaps and a coarser gap-free model series, on
# different grids, so the join has to work across resolutions as well as fill.
gappy_sources <- function(gap_fraction = 0.3, seed = 42) {
  set.seed(seed)
  satellite <- do.call(rbind, lapply(1:3, function(m) {
    g <- expand.grid(x = seq(-70, -69, by = 0.25), y = seq(42, 43, by = 0.25))
    g$CHL <- 1 + m + stats::runif(nrow(g), 0, 0.2)
    g$CHL[sample(nrow(g), round(nrow(g) * gap_fraction))] <- NA
    g$YEAR <- 2020; g$MONTH <- m; g$DAY <- 1L
    g
  }))
  model <- do.call(rbind, lapply(1:3, function(m) {
    g <- expand.grid(x = seq(-70, -69, by = 0.5), y = seq(42, 43, by = 0.5))
    # Spatially varying, not just offset: a uniform field has zero variance, and
    # rescaling to match a zero spread is undefined.
    g$CHL_MODEL <- 10 + m + (g$y - 42) * 2
    g$YEAR <- 2020; g$MONTH <- m; g$DAY <- 1L
    g
  }))
  list(
    satellite = sf::st_as_sf(satellite, coords = c("x", "y"), crs = 4326),
    model = sf::st_as_sf(model, coords = c("x", "y"), crs = 4326)
  )
}

test_that("gaps are filled and observed values left alone", {
  sources <- gappy_sources()
  before <- sources$satellite$CHL

  filled <- fill_satellite_gaps(sources$satellite, sources$model,
                                 c(CHL = "CHL_MODEL"))

  expect_false(any(is.na(filled$CHL)))
  # Where the satellite saw something, that value must survive untouched.
  observed <- !is.na(before)
  expect_equal(filled$CHL[observed], before[observed])
})

test_that("the source of every value is recorded", {
  sources <- gappy_sources(gap_fraction = 0.3)
  gaps <- is.na(sources$satellite$CHL)

  filled <- fill_satellite_gaps(sources$satellite, sources$model,
                                 c(CHL = "CHL_MODEL"))

  expect_true("CHL_source" %in% names(filled))
  expect_equal(filled$CHL_source == "model", unname(gaps))
  expect_equal(sum(filled$CHL_source == "satellite"), sum(!gaps))
})

test_that("filled values come from the matching time step", {
  # The model value differs by month, so a fill that ignored time would show up
  # as the wrong month's number.
  sources <- gappy_sources()

  filled <- fill_satellite_gaps(sources$satellite, sources$model,
                                 c(CHL = "CHL_MODEL"))

  # The model field is 10 + month + a latitude term spanning 0 to 2, so each
  # month's filled values sit in a band that no other month overlaps.
  for (m in 1:3) {
    from_model <- filled$CHL[filled$MONTH == m & filled$CHL_source == "model"]
    if (length(from_model) == 0) next
    expect_true(all(from_model >= 10 + m & from_model <= 12 + m))
  }
})

test_that("nothing is rescaled by default, so the seam stays visible", {
  # The model runs an order of magnitude above the satellite here. Left as is,
  # that discontinuity is obvious; silently smoothing it would hide that two
  # different measurements had been spliced.
  sources <- gappy_sources()

  filled <- fill_satellite_gaps(sources$satellite, sources$model,
                                 c(CHL = "CHL_MODEL"))

  expect_gt(mean(filled$CHL[filled$CHL_source == "model"]),
            mean(filled$CHL[filled$CHL_source == "satellite"]) + 5)
})

test_that("rescaling brings the filled values onto the satellite's scale", {
  sources <- gappy_sources()

  rescaled <- fill_satellite_gaps(sources$satellite, sources$model,
                                   c(CHL = "CHL_MODEL"), rescale = TRUE)

  from_model <- rescaled$CHL[rescaled$CHL_source == "model"]
  from_satellite <- rescaled$CHL[rescaled$CHL_source == "satellite"]

  # Not identical - the model still carries its own spatial pattern - but the
  # gross offset should be gone.
  expect_lt(abs(mean(from_model) - mean(from_satellite)), 2)
})

test_that("a satellite series with no gaps is returned unchanged", {
  sources <- gappy_sources(gap_fraction = 0)

  filled <- fill_satellite_gaps(sources$satellite, sources$model,
                                 c(CHL = "CHL_MODEL"))

  expect_equal(filled$CHL, sources$satellite$CHL)
  expect_true(all(filled$CHL_source == "satellite"))
})

test_that("a time step the model lacks leaves those gaps unfilled", {
  sources <- gappy_sources()
  # Model covers only months 1 and 2.
  partial <- sources$model[sources$model$MONTH %in% 1:2, ]

  filled <- fill_satellite_gaps(sources$satellite, partial, c(CHL = "CHL_MODEL"))

  # Month 3's gaps have nothing to fill from, and must stay NA rather than
  # borrowing another month's values.
  march_gaps <- filled$MONTH == 3 & filled$CHL_source == "satellite" &
    is.na(filled$CHL)
  expect_true(any(march_gaps))
})

test_that("unnamed vars assume the same column name in both sources", {
  sources <- gappy_sources()
  model <- sources$model
  names(model)[names(model) == "CHL_MODEL"] <- "CHL"

  filled <- fill_satellite_gaps(sources$satellite, model, "CHL")

  expect_false(any(is.na(filled$CHL)))
})

test_that("missing columns are reported with what is available", {
  sources <- gappy_sources()

  expect_error(fill_satellite_gaps(sources$satellite, sources$model,
                                    c(NOPE = "CHL_MODEL")), "NOPE")
  expect_error(fill_satellite_gaps(sources$satellite, sources$model,
                                    c(CHL = "MISSING")), "Model has")
})

# `<var>_source` is provenance, but it travels with the variable it describes
# rather than being left behind by it. Both resamplers were written expecting a
# source column to ride along - they carry a non-numeric column as a categorical
# - but covariate_columns() used to strip it, so it never arrived and the record
# of which source a value came from was lost at the first resample.

test_that("covariate_columns reports <var>_source but not bookkeeping", {
  d <- sf::st_as_sf(
    data.frame(x = c(1, 2), y = c(1, 2), SST = c(4, 5),
               SST_source = c("satellite", "model"), BOTS_depth = c(80, 90),
               YEAR = 2010L, MONTH = 6L, DAY = 1L),
    coords = c("x", "y"), crs = 4326)

  cols <- covariate_columns(d)
  expect_true("SST_source" %in% cols)
  expect_true("SST" %in% cols)
  # The mean of two depths is not the depth any value came from.
  expect_false("BOTS_depth" %in% cols)
  # Time and geometry are never covariates.
  expect_false(any(c("YEAR", "MONTH", "DAY", "geometry") %in% cols))
})

test_that("the internal per-row source tag stays out of covariate_columns", {
  d <- sf::st_as_sf(
    data.frame(x = c(1, 2), y = c(1, 2), SST = c(4, 5),
               YEAR = 2010L, MONTH = 6L, DAY = 1L),
    coords = c("x", "y"), crs = 4326)
  d <- stamp_source(d, "hycom", c("GLBv53X", "GLBy930"))

  expect_true(".datamatch_source" %in% names(d))
  expect_false(".datamatch_source" %in% covariate_columns(d))
})

test_that("a source column survives upscaling, as the commonest value", {
  sources <- gappy_sources(gap_fraction = 0.3)
  filled <- fill_satellite_gaps(sources$satellite, sources$model,
                                c(CHL = "CHL_MODEL"))

  # No `vars`: the default is covariate_columns(), which is the whole point -
  # a caller should not have to enumerate columns to keep provenance.
  coarser <- upscale_grid(filled, to = 0.5, min_coverage = 0)

  expect_true("CHL_source" %in% names(coarser))
  expect_true(all(coarser$CHL_source %in% c("satellite", "model")))
  # Carried as a category, not averaged into something that is neither.
  expect_false(any(is.na(coarser$CHL_source) & !is.na(coarser$CHL)))
})
