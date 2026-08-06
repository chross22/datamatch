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

test_that("a layer count that does not match the request is an error", {
  # Names are assigned positionally, so a depth range spanning several model
  # levels would silently mislabel columns. Stopping is the lesser evil.
  raster_path <- write_fake_raster(c("thetao", "so", "extra_level"))

  local_mocked_bindings(copernicus_cache = function(...) raster_path)
  local_mocked_bindings(
    file_exists = function(...) TRUE,
    .package = "fs"
  )

  expect_error(
    accessEnvDat(
      product_id = "GLOBAL_TEST",
      dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1M-m",
      vars = c("SST", "SSS"),
      years = 2020, months = 1,
      bounding_box = list(xmin = -70, xmax = -60, ymin = 40, ymax = 45)
    ),
    "depth range spans several model levels"
  )
})
