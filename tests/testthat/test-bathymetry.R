# A small synthetic marmap `bathy` object, so the conversion and attachment
# logic can be tested without hitting the NOAA server.
mock_bathy <- function(lon = seq(-70, -66, by = 0.5), lat = seq(41, 44, by = 0.5)) {
  # marmap stores a matrix of elevations with lon as rows and lat as columns,
  # land positive and depth negative.
  elevation <- outer(lon, lat, function(x, y) {
    depth <- -50 - 200 * (x + 70) / 4    # deepens offshore to the east
    ifelse(y > 43.8, 30, depth)          # a strip of land along the north edge
  })
  dimnames(elevation) <- list(lon, lat)
  class(elevation) <- "bathy"
  elevation
}

test_that("bathymetry_layers converts elevation to positive depth plus terrain", {
  skip_if_not_installed("marmap")

  layers <- bathymetry_layers(mock_bathy())

  expect_setequal(names(layers), c("DEPTH", "SLOPE", "ASPECT", "TPI"))
  expect_equal(terra::crs(layers, describe = TRUE)$code, "4326")

  depth <- terra::values(layers[["DEPTH"]], na.rm = TRUE)
  # marmap gives depth as negative elevation; the model wants a positive
  # magnitude, matching the original's log(abs(bat)).
  expect_true(all(depth > 0))
})

test_that("TPI is positive on a bank and negative in a basin", {
  skip_if_not_installed("marmap")

  # The sign is the whole point of the variable and is easy to invert, since it
  # is computed on depth (positive down) rather than on elevation. A bank has to
  # come out positive; taking terra's TPI unnegated would make it negative.
  lon <- seq(-70, -66, by = 0.5)
  lat <- seq(41, 44, by = 0.5)
  elevation <- outer(lon, lat, function(x, y) rep(-200, length(x)))
  bank <- which(lon == -68)
  basin <- which(lon == -67)
  elevation[bank, ] <- -50    # shallow ridge: a local high
  elevation[basin, ] <- -400  # deep trough: a local low
  dimnames(elevation) <- list(lon, lat)
  class(elevation) <- "bathy"

  tpi <- bathymetry_layers(elevation)[["TPI"]]
  values <- terra::as.data.frame(tpi, xy = TRUE, na.rm = TRUE)

  on_bank <- values$TPI[abs(values$x - (-68)) < 0.01]
  in_basin <- values$TPI[abs(values$x - (-67)) < 0.01]

  expect_true(all(on_bank > 0))
  expect_true(all(in_basin < 0))
})

test_that("land is masked rather than becoming negative depth", {
  skip_if_not_installed("marmap")

  layers <- bathymetry_layers(mock_bathy())
  depth <- terra::values(layers[["DEPTH"]])

  # The synthetic grid has a land strip, so some cells must be NA. Left
  # unmasked they would be negative depths, which the model would read as
  # very shallow water rather than as "not water".
  expect_true(any(is.na(depth)))
  expect_false(any(depth < 0, na.rm = TRUE))
})

test_that("attach_bathymetry adds the requested layers at each point", {
  skip_if_not_installed("marmap")

  layers <- bathymetry_layers(mock_bathy())
  dat <- data.frame(lon = c(-69.5, -67.5), lat = c(42.0, 42.5))

  out <- attach_bathymetry(dat, layers, c("DEPTH", "SLOPE"))

  expect_true(all(c("DEPTH", "SLOPE") %in% names(out)))
  expect_equal(nrow(out), 2)
  expect_false("ASPECT" %in% names(out))
  # Depth increases offshore in the synthetic grid, so the eastern point is deeper.
  expect_gt(out$DEPTH[2], out$DEPTH[1])
})

test_that("attach_bathymetry reports layers that are not available", {
  skip_if_not_installed("marmap")

  layers <- bathymetry_layers(mock_bathy())
  dat <- data.frame(lon = -69, lat = 42)

  expect_error(attach_bathymetry(dat, layers, "RUGOSITY"), "RUGOSITY")
  expect_error(attach_bathymetry(dat, layers, "RUGOSITY"), "Available")
})

test_that("bathymetry variables are fully described", {
  variables <- bathymetry_variables()

  expect_setequal(names(variables), c("DEPTH", "SLOPE", "ASPECT", "TPI"))
  for (name in names(variables)) {
    for (field in c("label", "units", "description")) {
      expect_true(nzchar(variables[[name]][[field]] %||% ""),
                  info = paste(name, "is missing", field))
    }
  }
})

test_that("attach_bathymetry works on sf points as well as data frames", {
  skip_if_not_installed("marmap")

  layers <- bathymetry_layers(mock_bathy())
  plain <- data.frame(lon = c(-69.5, -67.5), lat = c(42.0, 42.5))
  spatial <- sf::st_as_sf(plain, coords = c("lon", "lat"), crs = 4326)

  # accessEnvDat() returns sf, observations are usually a plain data frame;
  # both must work without the caller converting first.
  from_plain <- attach_bathymetry(plain, layers, "DEPTH")
  from_sf <- attach_bathymetry(spatial, layers, "DEPTH")

  expect_equal(from_plain$DEPTH, from_sf$DEPTH)
})

test_that("differently named coordinate columns are supported", {
  skip_if_not_installed("marmap")

  layers <- bathymetry_layers(mock_bathy())
  dat <- data.frame(longitude = -69.5, latitude = 42.0)

  result <- attach_bathymetry(dat, layers, "DEPTH",
                               coords = c("longitude", "latitude"))

  expect_false(is.na(result$DEPTH))
  expect_error(attach_bathymetry(dat, layers, "DEPTH"), "Coordinate column")
})

test_that("a malformed bounding box is reported before any download", {
  skip_if_not_installed("marmap")

  expect_error(fetch_bathymetry(list(xmin = -70, xmax = -66)), "ymin, ymax")
})

test_that("an already-downloaded grid is read rather than re-requested", {
  skip_if_not_installed("marmap")

  # marmap names its cache file from the box and resolution. Reproducing that
  # is what lets an existing download be read directly, so if the convention
  # ever moves, this is the test that notices.
  path <- tempfile()
  dir.create(path)
  bb <- list(xmin = -70, xmax = -68, ymin = 42, ymax = 43)

  expect_equal(basename(marmap_cache_file(bb, 10, path)),
               "marmap_coord_-70;42;-68;43_res_10.csv")

  # The corner order is marmap's, not the caller's: a box written the other way
  # round must resolve to the same file.
  flipped <- list(xmin = -68, xmax = -70, ymin = 43, ymax = 42)
  expect_equal(marmap_cache_file(flipped, 10, path),
               marmap_cache_file(bb, 10, path))

  # Resolution is part of the name, so two resolutions do not collide.
  expect_false(identical(marmap_cache_file(bb, 4, path),
                         marmap_cache_file(bb, 10, path)))
})

test_that("fetch_bathymetry reads a cached grid without contacting NOAA", {
  skip_if_not_installed("marmap")

  path <- tempfile()
  dir.create(path)
  bb <- list(xmin = -70, xmax = -68, ymin = 42, ymax = 43)

  # A cache file written by hand, so a NOAA request would be visible as a
  # failure rather than quietly succeeding. Wide enough for terrain(), which
  # needs a 3x3 neighbourhood and errors on anything thinner.
  grid <- expand.grid(V1 = seq(-70, -68, by = 0.4), V2 = seq(42, 43, by = 0.2))
  grid$V3 <- -100 - (grid$V1 + 70) * 20
  utils::write.table(grid, file.path(path, "marmap_coord_-70;42;-68;43_res_10.csv"),
                     sep = ",", row.names = FALSE, col.names = TRUE)

  local_mocked_bindings(
    getNOAA.bathy = function(...) stop("NOAA should not be contacted"),
    .package = "marmap"
  )

  layers <- fetch_bathymetry(bb, resolution = 10, path = path)

  expect_s4_class(layers, "SpatRaster")
  expect_true("DEPTH" %in% names(layers))
})
