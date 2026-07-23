# Helper: builds a tiny in-memory raster with layers named after `vars`,
# standing in for what terra::rast(ofile) would normally read from disk.
make_fake_raster <- function(vars) {
  r <- terra::rast(nrows = 2, ncols = 2, nlyrs = length(vars))
  terra::values(r) <- seq_len(4 * length(vars))
  names(r) <- vars
  r
}

test_that("accessEnvDat returns an sf object with correct columns (monthly dataset)", {
  vars <- c("thetao", "so")

  local_mocked_bindings(
    copernicus_path = function(...) tempfile(fileext = ".nc"),
    .package = "copernicus"
  )
  local_mocked_bindings(
    file_exists = function(...) TRUE,
    .package = "fs"
  )
  local_mocked_bindings(
    rast = function(...) make_fake_raster(vars),
    .package = "terra"
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

  local_mocked_bindings(
    copernicus_path = function(...) tempfile(fileext = ".nc"),
    .package = "copernicus"
  )
  local_mocked_bindings(
    file_exists = function(...) TRUE,
    .package = "fs"
  )
  local_mocked_bindings(
    rast = function(...) make_fake_raster(vars),
    .package = "terra"
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
  download_called <- FALSE

  local_mocked_bindings(
    copernicus_path = function(...) tempfile(fileext = ".nc"),
    .package = "copernicus"
  )
  local_mocked_bindings(
    file_exists = function(...) FALSE,
    .package = "fs"
  )
  local_mocked_bindings(
    download_copernicus_cli_subset = function(...) {
      download_called <<- TRUE
      TRUE
    },
    .package = "copernicus"
  )
  local_mocked_bindings(
    rast = function(...) make_fake_raster(vars),
    .package = "terra"
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
  download_called <- FALSE

  local_mocked_bindings(
    copernicus_path = function(...) tempfile(fileext = ".nc"),
    .package = "copernicus"
  )
  local_mocked_bindings(
    file_exists = function(...) TRUE, # file "exists" locally...
    .package = "fs"
  )
  local_mocked_bindings(
    download_copernicus_cli_subset = function(...) {
      download_called <<- TRUE
      TRUE
    },
    .package = "copernicus"
  )
  local_mocked_bindings(
    rast = function(...) make_fake_raster(vars),
    .package = "terra"
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
