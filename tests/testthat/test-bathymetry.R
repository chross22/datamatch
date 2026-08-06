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

  expect_setequal(names(layers), c("DEPTH", "SLOPE", "ASPECT"))
  expect_equal(terra::crs(layers, describe = TRUE)$code, "4326")

  depth <- terra::values(layers[["DEPTH"]], na.rm = TRUE)
  # marmap gives depth as negative elevation; the model wants a positive
  # magnitude, matching the original's log(abs(bat)).
  expect_true(all(depth > 0))
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

  expect_setequal(names(variables), c("DEPTH", "SLOPE", "ASPECT"))
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
