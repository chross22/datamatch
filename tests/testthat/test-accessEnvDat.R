# These tests deliberately do NOT mock terra::rast.
#
# `rast` is an S4 generic whose methods call `rast()` internally. Mocking it with
# local_mocked_bindings(.package = "terra") replaces the binding inside terra's
# own namespace, so those internal calls hit the mock too and recurse until the C
# stack overflows - which is what every test in this file used to do, regardless
# of how the helper captured the original function first.
#
# Writing a real raster to a temp file and pointing accessEnvDat at it avoids the
# problem entirely, and exercises the actual read path rather than a stand-in.
# Only `copernicus_cache` (where the file lives), `fs::file_exists` (whether it
# counts as cached), and the downloader itself need mocking. All three are
# datamatch's own, so no `.package` argument is needed - local_mocked_bindings
# defaults to the package under test.

# A raster whose layers are named the way Copernicus names them, with the depth
# suffix 3D variables carry, and each layer filled with a value identifying it.
copernicus_style_raster <- function(layer_names, values = seq_along(layer_names)) {
  r <- terra::rast(nrows = 2, ncols = 2, nlyrs = length(layer_names))
  for (i in seq_along(layer_names)) terra::values(r[[i]]) <- rep(values[i], 4)
  names(r) <- layer_names
  r
}

test_that("layers are matched by name, not by position", {
  # THE regression this guards. Copernicus returns layers in the NetCDF's own
  # order, which is alphabetical by code: asking for thetao then so gets back so
  # then thetao. Naming positionally labelled salinity as temperature and
  # temperature as salinity, silently, in every multi-variable download.
  returned <- copernicus_style_raster(
    c("so_depth=0.494025", "thetao_depth=0.494025"), values = c(32.7, 6.2))

  ordered <- order_layers(returned, c("thetao", "so"))

  expect_equal(unname(terra::values(ordered[[1]])[1]), 6.2)   # thetao first
  expect_equal(unname(terra::values(ordered[[2]])[1]), 32.7)  # so second
})

test_that("the depth suffix does not prevent matching", {
  returned <- copernicus_style_raster(
    c("thetao_depth=0.494025", "mlotst", "uo_depth=0.494025", "zos"),
    values = c(6.2, 54.2, 0.016, -0.498))

  # A mixture of 3D variables (suffixed) and 2D ones (not), requested in an
  # order matching neither the file's nor the alphabet's.
  ordered <- order_layers(returned, c("zos", "thetao", "uo", "mlotst"))

  expect_equal(unname(vapply(1:4, function(i) terra::values(ordered[[i]])[1], numeric(1))),
               c(-0.498, 6.2, 0.016, 54.2))
})

test_that("a variable the download omitted is named", {
  returned <- copernicus_style_raster(c("thetao_depth=0.494025", "so_depth=0.494025"))

  expect_error(order_layers(returned, c("thetao", "so", "uo", "vo")), "uo, vo")
  # And says what did arrive, so the cause is diagnosable from the message.
  expect_error(order_layers(returned, c("thetao", "uo")), "It contains: thetao, so")
})

test_that("a depth range spanning several levels is reported as such", {
  returned <- copernicus_style_raster(
    c("thetao_depth=0.494025", "thetao_depth=1.541375"))

  expect_error(order_layers(returned, "thetao"), "several model levels")
  expect_error(order_layers(returned, "thetao"), "0.494025")
})

test_that("a single requested variable passes through unchanged", {
  returned <- copernicus_style_raster("thetao_depth=0.494025", values = 6.2)

  ordered <- order_layers(returned, "thetao")

  expect_equal(terra::nlyr(ordered), 1)
  expect_equal(unname(terra::values(ordered)[1]), 6.2)
})

# Builds a real raster file with one layer per variable. accessEnvDat assigns
# column names positionally from `vars` after reading, so only the layer *count*
# has to match.
write_fake_raster <- function(vars) {
  path <- tempfile(fileext = ".tif")
  r <- terra::rast(nrows = 2, ncols = 2, nlyrs = length(vars))
  terra::values(r) <- seq_len(4 * length(vars))
  names(r) <- vars
  terra::writeRaster(r, path, overwrite = TRUE)
  path
}

test_that("accessEnvDat returns an sf object with correct columns (monthly dataset)", {
  vars <- c("thetao", "so")
  raster_path <- write_fake_raster(vars)

  local_mocked_bindings(copernicus_cache = function(...) raster_path)
  local_mocked_bindings(
    file_exists = function(...) TRUE,
    .package = "fs"
  )

  result <- accessEnvDat(
    product_id = "GLOBAL_TEST",
    dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1M-m", # "M" -> monthly
    vars = vars,
    years = 2020,
    months = 1,
    bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45)
  )

  expect_s3_class(result, "sf")
  expect_true(all(vars %in% names(result)))
  expect_true(all(c("YEAR", "MONTH", "DAY") %in% names(result)))
  expect_equal(unique(result$YEAR), 2020)
  expect_equal(unique(result$MONTH), 1)
  expect_equal(unique(result$DAY), 1) # monthly dataset -> only day 1 pulled
})

test_that("accessEnvDat loops over all days for a daily dataset", {
  vars <- c("thetao")
  raster_path <- write_fake_raster(vars)

  local_mocked_bindings(copernicus_cache = function(...) raster_path)
  local_mocked_bindings(
    file_exists = function(...) TRUE,
    .package = "fs"
  )

  result <- accessEnvDat(
    product_id = "GLOBAL_TEST",
    dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1D-m", # "D" -> daily
    vars = vars,
    years = 2020,
    months = 2, # Feb 2020, leap year -> 29 days
    bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45)
  )

  expect_equal(sort(unique(result$DAY)), 1:29)
})

test_that("accessEnvDat calls the downloader when data are not cached locally", {
  vars <- c("thetao")
  raster_path <- write_fake_raster(vars)
  download_called <- FALSE

  local_mocked_bindings(copernicus_cache = function(...) raster_path)
  # The file is reported as absent so the download branch runs, even though it
  # is really on disk for the subsequent read.
  local_mocked_bindings(
    file_exists = function(...) FALSE,
    .package = "fs"
  )
  local_mocked_bindings(
    download_copernicus_subset = function(...) {
      download_called <<- TRUE
      invisible(0)
    }
  )

  accessEnvDat(
    product_id = "GLOBAL_TEST",
    dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1M-m",
    vars = vars,
    years = 2020,
    months = 1,
    bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45)
  )

  expect_true(download_called)
})

test_that("accessEnvDat re-downloads when overwrite = TRUE, even if cached", {
  vars <- c("thetao")
  raster_path <- write_fake_raster(vars)
  download_called <- FALSE

  local_mocked_bindings(copernicus_cache = function(...) raster_path)
  local_mocked_bindings(
    file_exists = function(...) TRUE, # file "exists" locally...
    .package = "fs"
  )
  local_mocked_bindings(
    download_copernicus_subset = function(...) {
      download_called <<- TRUE
      invisible(0)
    }
  )

  accessEnvDat(
    product_id = "GLOBAL_TEST",
    dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1M-m",
    vars = vars,
    years = 2020,
    months = 1,
    bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45),
    overwrite = TRUE # ...but overwrite is TRUE
  )

  expect_true(download_called)
})

test_that("accessEnvDat does not download when data are already cached", {
  vars <- c("thetao")
  raster_path <- write_fake_raster(vars)
  download_called <- FALSE

  local_mocked_bindings(copernicus_cache = function(...) raster_path)
  local_mocked_bindings(
    file_exists = function(...) TRUE,
    .package = "fs"
  )
  local_mocked_bindings(
    download_copernicus_subset = function(...) {
      download_called <<- TRUE
      invisible(0)
    }
  )

  accessEnvDat(
    product_id = "GLOBAL_TEST",
    dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1M-m",
    vars = vars,
    years = 2020,
    months = 1,
    bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45)
  )

  # The point of the cache: a file already on disk is read, not re-fetched.
  expect_false(download_called)
})

test_that("accessEnvDat covers every requested year and month", {
  vars <- c("thetao")
  raster_path <- write_fake_raster(vars)

  local_mocked_bindings(copernicus_cache = function(...) raster_path)
  local_mocked_bindings(
    file_exists = function(...) TRUE,
    .package = "fs"
  )

  result <- accessEnvDat(
    product_id = "GLOBAL_TEST",
    dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1M-m",
    vars = vars,
    years = c(2019, 2020),
    months = c(1, 6, 12),
    bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45)
  )

  expect_equal(sort(unique(result$YEAR)), c(2019, 2020))
  expect_equal(sort(unique(result$MONTH)), c(1, 6, 12))
  # One grid (4 cells) per year x month combination.
  expect_equal(nrow(result), 4 * 2 * 3)
})

test_that("catalog names become the result's column names", {
  # The caller asked for SST, so the column is SST - not the thetao code that
  # went to the API.
  raster_path <- write_fake_raster(c("thetao", "so"))

  local_mocked_bindings(copernicus_cache = function(...) raster_path)
  local_mocked_bindings(
    file_exists = function(...) TRUE,
    .package = "fs"
  )

  result <- accessEnvDat(
    product_id = "GLOBAL_TEST",
    dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1M-m",
    vars = c("SST", "SSS"),
    years = 2020, months = 1,
    bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45)
  )

  expect_true(all(c("SST", "SSS") %in% names(result)))
  expect_false(any(c("thetao", "so") %in% names(result)))
})

test_that("the product and dataset are inferred from catalog names", {
  # Both are omitted here; the catalog knows SST and SSS are physical variables.
  raster_path <- write_fake_raster(c("thetao", "so"))
  requested <- NULL

  local_mocked_bindings(
    copernicus_cache = function(...) {
      requested <<- c(...)
      raster_path
    }
  )
  local_mocked_bindings(
    file_exists = function(...) TRUE,
    .package = "fs"
  )

  result <- accessEnvDat(
    vars = c("SST", "SSS"),
    years = 2020, months = 1,
    bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45)
  )

  expect_true(all(c("SST", "SSS") %in% names(result)))
  # The inferred identifiers reach the cache path, which is built from them.
  expect_true(any(grepl("GLOBAL_MULTIYEAR_PHY_001_030", requested)))
})

test_that("mixing datasets is refused before any download is attempted", {
  downloaded <- FALSE
  local_mocked_bindings(
    download_copernicus_subset = function(...) {
      downloaded <<- TRUE
      invisible(0)
    }
  )

  expect_error(
    accessEnvDat(vars = c("SST", "CHL"), years = 2020, months = 1,
                 bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45)),
    "different Copernicus datasets"
  )
  expect_false(downloaded)
})

test_that("a depth range spanning several levels is an error, end to end", {
  # What this really looks like in a download: the same variable code on more
  # than one layer, one per model level. Layers are matched by name now, so an
  # unrelated extra layer is harmless - a repeated one is not, because there is
  # no way to know which level the caller wanted.
  raster_path <- write_fake_raster(c("thetao_depth=0.494025", "thetao_depth=1.541375"))

  local_mocked_bindings(copernicus_cache = function(...) raster_path)
  local_mocked_bindings(
    file_exists = function(...) TRUE,
    .package = "fs"
  )

  expect_error(
    accessEnvDat(
      product_id = "GLOBAL_TEST",
      dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1M-m",
      vars = "SST",
      years = 2020, months = 1,
      bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45)
    ),
    "several model levels"
  )
})

test_that("a variable missing from the download names it, not the depth range", {
  # The old failure mode was a column count that could only guess at the cause
  # and blamed the depth range for everything. A variable the dataset does not
  # serve is now reported as itself.
  raster_path <- write_fake_raster(c("thetao", "so"))

  local_mocked_bindings(copernicus_cache = function(...) raster_path)
  local_mocked_bindings(
    file_exists = function(...) TRUE,
    .package = "fs"
  )

  expect_error(
    accessEnvDat(
      product_id = "GLOBAL_TEST",
      dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1M-m",
      vars = c("SST", "SSS", "UO", "VO"),
      years = 2020, months = 1,
      bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45)
    ),
    "did not return: uo, vo"
  )
})

# ---- downloading only what is missing, in parallel ---------------------------

test_that("only the days that are not cached are downloaded", {
  raster_path <- write_fake_raster("thetao")
  requested <- character(0)

  local_mocked_bindings(copernicus_cache = function(...) raster_path)
  # Odd days are cached, even days are not. The path is the same file for all of
  # them, so the decision is driven by the call count rather than the name.
  call <- 0
  local_mocked_bindings(
    file_exists = function(...) {
      call <<- call + 1
      call %% 2 == 1
    },
    .package = "fs"
  )
  local_mocked_bindings(
    download_copernicus_subset = function(time, ...) {
      requested <<- c(requested, format(time))
      invisible(0)
    }
  )

  accessEnvDat(
    product_id = "GLOBAL_TEST",
    dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1D-m",
    vars = "thetao",
    years = 2020, months = 4,   # 30 days
    bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45),
    n_workers = 1
  )

  # The 15 uncached days, and not the 15 already on disk.
  expect_equal(length(requested), 15)
  expect_equal(requested, format(as.Date(paste0("2020-04-", seq(2, 30, by = 2)))))
})

test_that("one day's failure does not abandon the rest", {
  # Under a cluster an error thrown in a worker aborts the whole batch. Days are
  # expensive enough that losing the ones already in flight to a single bad
  # request is worth avoiding, so failures are collected rather than raised.
  raster_path <- write_fake_raster("thetao")
  attempted <- character(0)

  local_mocked_bindings(copernicus_cache = function(...) raster_path)
  local_mocked_bindings(file_exists = function(...) FALSE, .package = "fs")
  local_mocked_bindings(
    download_copernicus_subset = function(time, ...) {
      attempted <<- c(attempted, format(time))
      if (format(time) == "2020-01-02") stop("503 from the API")
      invisible(0)
    }
  )

  expect_error(
    accessEnvDat(
      product_id = "GLOBAL_TEST",
      dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1D-m",
      vars = "thetao",
      years = 2020, months = 1,
      bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45),
      n_workers = 1
    ),
    "1 of 31 day\\(s\\) could not be downloaded"
  )

  # Every day was attempted, not just those up to the failure.
  expect_equal(length(attempted), 31)
  # And the error says which one, so the cause is findable.
  expect_error(
    accessEnvDat(
      product_id = "GLOBAL_TEST",
      dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1D-m",
      vars = "thetao", years = 2020, months = 1,
      bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45),
      n_workers = 1
    ),
    "2020-01-02: 503 from the API"
  )
})

test_that("nothing is downloaded, and no cluster started, when all days are cached", {
  raster_path <- write_fake_raster("thetao")
  clustered <- FALSE

  local_mocked_bindings(copernicus_cache = function(...) raster_path)
  local_mocked_bindings(file_exists = function(...) TRUE, .package = "fs")
  local_mocked_bindings(
    download_copernicus_subset = function(...) stop("should not be called")
  )
  local_mocked_bindings(
    makeCluster = function(...) {
      clustered <<- TRUE
      stop("should not be called")
    },
    .package = "parallel"
  )

  result <- accessEnvDat(
    product_id = "GLOBAL_TEST",
    dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1D-m",
    vars = "thetao",
    years = 2020, months = 1,
    bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45),
    n_workers = 8   # would otherwise be a cluster of 8
  )

  # A fully cached fetch should not pay for workers it has no work for.
  expect_false(clustered)
  expect_equal(sort(unique(result$DAY)), 1:31)
})

# ---- daily covariates --------------------------------------------------------

test_that("frequency = 'daily' selects the daily dataset and expands the month", {
  raster_path <- write_fake_raster("thetao")
  used <- NULL

  local_mocked_bindings(copernicus_cache = function(...) raster_path)
  local_mocked_bindings(file_exists = function(...) FALSE, .package = "fs")
  local_mocked_bindings(
    download_copernicus_subset = function(dataset_id, ...) {
      used <<- dataset_id
      invisible(0)
    }
  )

  result <- accessEnvDat(
    vars = "SST",
    years = 2020, months = 2,       # leap year -> 29 days
    bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45),
    frequency = "daily", n_workers = 1
  )

  expect_equal(used, "cmems_mod_glo_phy_my_0.083deg_P1D-m")
  expect_equal(sort(unique(result$DAY)), 1:29)
})

test_that("the monthly default is unchanged", {
  raster_path <- write_fake_raster("thetao")
  used <- NULL

  local_mocked_bindings(copernicus_cache = function(...) raster_path)
  local_mocked_bindings(file_exists = function(...) FALSE, .package = "fs")
  local_mocked_bindings(
    download_copernicus_subset = function(dataset_id, ...) {
      used <<- dataset_id
      invisible(0)
    }
  )

  result <- accessEnvDat(
    vars = "SST",
    years = 2020, months = 2,
    bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45),
    n_workers = 1
  )

  expect_equal(used, "cmems_mod_glo_phy_my_0.083deg_P1M-m")
  expect_equal(unique(result$DAY), 1)
})

test_that("an explicit dataset_id wins over frequency, with a warning", {
  # The dataset is published at one step. Following `frequency` instead would
  # request the same monthly field once per day of the month.
  raster_path <- write_fake_raster("thetao")

  local_mocked_bindings(copernicus_cache = function(...) raster_path)
  local_mocked_bindings(file_exists = function(...) TRUE, .package = "fs")

  expect_warning(
    result <- accessEnvDat(
      product_id = "GLOBAL_TEST",
      dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1M-m",   # monthly
      vars = "thetao",
      years = 2020, months = 1,
      bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45),
      frequency = "daily"                                    # ...but asked daily
    ),
    "is monthly, but frequency = \"daily\""
  )

  expect_equal(unique(result$DAY), 1)
})

test_that("a variable with no daily dataset is refused before downloading", {
  local_mocked_bindings(
    download_copernicus_subset = function(...) stop("should not be called")
  )

  # PP is a monthly composite; the daily ocean colour dataset has no such field.
  expect_error(
    accessEnvDat(
      vars = "PP", years = 2020, months = 1,
      bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45),
      frequency = "daily"
    ),
    "no daily dataset for: PP"
  )

  # And the phytoplankton types, which the daily dataset does not carry either.
  expect_error(
    accessEnvDat(
      vars = c("DIATO", "DINO"), years = 2020, months = 1,
      bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45),
      frequency = "daily"
    ),
    "DIATO, DINO"
  )
})
