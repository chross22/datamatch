#' Static seafloor variables
#'
#' Bathymetry and the terrain measures derived from it. These are *static* — they
#' do not vary by month or year — so they are fetched once for a study area and
#' attached to every time step, unlike the Copernicus variables.
#'
#' Sourced from NOAA ETOPO via `marmap::getNOAA.bathy()`.
#'
#' @return a named list, one entry per variable, each with `label`, `units`, and
#'   `description`
#' @examples
#' names(bathymetry_variables())
#' @seealso [fetch_bathymetry()], [variable_dictionary()]
#' @export
bathymetry_variables <- function() {
  list(
    DEPTH = list(
      label = "Water depth", units = "m",
      description = paste("Seafloor depth from NOAA ETOPO, as a positive number",
                          "of metres. Depth spans several orders of magnitude",
                          "across the shelf and slope, so it is usually worth",
                          "log-transforming.")
    ),
    SLOPE = list(
      label = "Bottom slope", units = "degrees",
      description = paste("Steepness of the seafloor, computed from the depth",
                          "grid. Picks out shelf breaks and canyon edges, where",
                          "zooplankton often aggregate.")
    ),
    ASPECT = list(
      label = "Bottom aspect", units = "degrees",
      description = paste("Compass direction the seafloor slope faces, computed",
                          "from the depth grid. Meaningless where the bottom is",
                          "flat, so expect noise in deep basins.")
    ),
    TPI = list(
      label = "Topographic position index", units = "m",
      description = paste("A cell's depth relative to the mean of the eight cells",
                          "around it. Positive on banks, ledges, and seamounts;",
                          "negative in basins and channels; near zero on both flat",
                          "bottom and uniform slopes. Separates local highs from",
                          "lows, which raw depth cannot: a 100 m bank top and a",
                          "100 m basin floor are the same depth and very different",
                          "places. Scale-dependent - it describes position within",
                          "the immediate neighbourhood, so its meaning follows the",
                          "resolution of the grid it was computed on.")
    )
  )
}

#' Fetch static bathymetry for a study area
#'
#' Downloads NOAA ETOPO bathymetry via `marmap::getNOAA.bathy()` and derives
#' slope and aspect from it.
#'
#' The bounding box takes the same shape as `accessEnvDat()`'s, so a single
#' definition of the study area serves both.
#'
#' `marmap` caches downloads into the working directory by default, which
#' scatters them wherever R happened to be started. Passing `path` keeps a run's
#' downloads together.
#'
#' @param bounding_box named list with `xmin`, `xmax`, `ymin`, `ymax`
#' @param resolution grid resolution in arc-minutes, as `marmap` defines it;
#'   smaller is finer and slower. 4 is roughly 7 km at mid latitudes.
#' @param path directory for `marmap`'s download cache; created if absent
#' @param keep whether `marmap` should cache the downloaded grid for reuse
#' @return a `terra::SpatRaster` with one layer per variable in
#'   `bathymetry_variables()`, in EPSG:4326
#' @examples
#' \dontrun{
#' bathy <- fetch_bathymetry(
#'   bounding_box = list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
#' )
#' terra::plot(bathy[["DEPTH"]])
#' }
#' @export
fetch_bathymetry <- function(bounding_box, resolution = 4, path = tempdir(),
                             keep = TRUE) {
  if (!requireNamespace("marmap", quietly = TRUE)) {
    stop("The 'marmap' package is required for bathymetry. ",
         "Install it with install.packages('marmap').", call. = FALSE)
  }

  required <- c("xmin", "xmax", "ymin", "ymax")
  missing <- setdiff(required, names(bounding_box))
  if (length(missing) > 0) {
    stop("bounding_box is missing: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }

  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  bathy <- marmap::getNOAA.bathy(
    lon1 = bounding_box$xmin, lon2 = bounding_box$xmax,
    lat1 = bounding_box$ymin, lat2 = bounding_box$ymax,
    resolution = resolution, keep = keep, path = path
  )

  bathymetry_layers(bathy)
}

#' Convert a marmap bathy object into terrain layers
#'
#' Split from `fetch_bathymetry()` so the conversion can be tested without a
#' network call.
#'
#' @param bathy a `marmap` `bathy` object
#' @return a `terra::SpatRaster` with `DEPTH`, `SLOPE`, `ASPECT`, and `TPI` layers
#' @keywords internal
bathymetry_layers <- function(bathy) {
  # marmap stores elevation with land positive and depth negative. Depth as a
  # positive magnitude is the more useful convention for a covariate.
  elevation <- terra::rast(marmap::as.raster(bathy))
  terra::crs(elevation) <- "EPSG:4326"

  depth <- -elevation
  # Land becomes negative depth. Mask it rather than leaving values a model
  # would read as very shallow water.
  depth[depth <= 0] <- NA
  names(depth) <- "DEPTH"

  terrain <- terra::terrain(depth, v = c("slope", "aspect"), unit = "degrees")
  names(terrain) <- c("SLOPE", "ASPECT")

  # TPI is computed on depth rather than elevation, so its sign follows the
  # seafloor rather than inverting with it: positive is a local high (bank,
  # ledge), negative a local low (basin, channel).
  tpi <- -terra::terrain(depth, v = "TPI")
  names(tpi) <- "TPI"

  c(depth, terrain, tpi)
}

#' Attach static bathymetry to a table of points
#'
#' Bathymetry does not vary in time, so the same value is attached to every
#' observation at a location regardless of its date.
#'
#' Accepts either a plain data frame with coordinate columns or an `sf` POINT
#' object, so it works on observations and on `accessEnvDat()` output alike.
#'
#' @param dat a data frame with coordinate columns, or an `sf` POINT object
#' @param bathy a `SpatRaster` from `fetch_bathymetry()`
#' @param vars which layers to attach; `NULL` uses all of them
#' @param coords names of the longitude and latitude columns, ignored for `sf`
#'   input
#' @return `dat` with one column per requested bathymetry variable
#' @examples
#' \dontrun{
#' bathy <- fetch_bathymetry(list(xmin = -70, xmax = -66, ymin = 41, ymax = 44))
#' observations <- attach_bathymetry(observations, bathy, c("DEPTH", "SLOPE"))
#' }
#' @export
attach_bathymetry <- function(dat, bathy, vars = NULL, coords = c("lon", "lat")) {
  vars <- vars %||% names(bathy)
  missing <- setdiff(vars, names(bathy))
  if (length(missing) > 0) {
    stop("Bathymetry layers not available: ", paste(missing, collapse = ", "),
         "\nAvailable: ", paste(names(bathy), collapse = ", "), call. = FALSE)
  }

  positions <- if (inherits(dat, "sf")) {
    sf::st_coordinates(dat)
  } else {
    missing_coords <- setdiff(coords, names(dat))
    if (length(missing_coords) > 0) {
      stop("Coordinate column(s) not found: ", paste(missing_coords, collapse = ", "),
           "\nPass `coords` if they are named differently.", call. = FALSE)
    }
    as.matrix(dat[coords])
  }

  extracted <- terra::extract(bathy[[vars]], positions)
  for (v in vars) dat[[v]] <- extracted[[v]]
  dat
}
