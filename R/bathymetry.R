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
#' @section Citation:
#' The grid is NOAA NCEI ETOPO 2022, requested at 60 arc-second bedrock
#' resolution through `marmap`. Both want citing when the result is published:
#'
#' \itemize{
#'   \item NOAA National Centers for Environmental Information (2022). ETOPO 2022
#'     15 Arc-Second Global Relief Model. \doi{10.25921/fd45-gt74}
#'   \item Pante E, Simon-Bouhet B, Irisson J (2025). marmap: Import, Plot and
#'     Analyze Bathymetric and Topographic Data.
#'     \doi{10.32614/CRAN.package.marmap}
#' }
#'
#' The bounding box takes the same shape as `accessEnvDat()`'s, so a single
#' definition of the study area serves both.
#'
#' @section Caching:
#' `marmap` caches downloads into the working directory by default, which
#' scatters them wherever R happened to be started. This puts them beside the
#' Copernicus cache instead, under [tools::R_user_dir()], so a study area
#' downloaded once stays downloaded across sessions. `path` overrides that.
#'
#' A grid already on disk is read with `marmap::read.bathy()` rather than
#' re-requested through `marmap::getNOAA.bathy()`. Both return the same object,
#' but the second announces itself — "Querying NOAA database", then "File
#' already exists ; loading ..." — and there is no reason to narrate a local
#' file read. Reading directly also skips the NOAA round trip entirely.
#'
#' @param bounding_box named list with `xmin`, `xmax`, `ymin`, `ymax`
#' @param resolution grid resolution in arc-minutes, as `marmap` defines it;
#'   smaller is finer and slower. 4 is roughly 7 km at mid latitudes.
#' @param path directory for the download cache; created if absent. Defaults to
#'   a `bathymetry` folder under [tools::R_user_dir()], so downloads persist
#'   between sessions.
#' @param keep whether `marmap` should cache the downloaded grid for reuse. With
#'   `FALSE` nothing is written, so nothing can be read back later either.
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
fetch_bathymetry <- function(bounding_box, resolution = 4,
                             path = copernicus_cache("bathymetry"),
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

  cached <- marmap_cache_file(bounding_box, resolution, path)
  bathy <- if (!is.null(cached) && file.exists(cached)) {
    # Same object getNOAA.bathy() would hand back for this file, without the
    # NOAA round trip or the running commentary.
    marmap::read.bathy(cached, header = TRUE)
  } else {
    marmap::getNOAA.bathy(
      lon1 = bounding_box$xmin, lon2 = bounding_box$xmax,
      lat1 = bounding_box$ymin, lat2 = bounding_box$ymax,
      resolution = resolution, keep = keep, path = path
    )
  }

  bathymetry_layers(bathy)
}

#' Where marmap would have cached this grid
#'
#' Rebuilds the filename `marmap::getNOAA.bathy()` writes, so an existing
#' download can be read directly instead of requested again.
#'
#' The convention is marmap's, not this package's: `marmap_coord_` then the
#' bounding box as `x1;y1;x2;y2` with the lower corner first, then `_res_` and
#' the resolution. Requests that cross the antimeridian get an `_anti` suffix,
#' and are not claimed here — returning `NULL` for them means falling back to
#' `getNOAA.bathy()`, which is the correct answer either way.
#'
#' Should marmap ever change the convention, this stops matching and every fetch
#' goes back through `getNOAA.bathy()`. That is slower and chattier, not wrong.
#'
#' @param bounding_box named list with `xmin`, `xmax`, `ymin`, `ymax`
#' @param resolution grid resolution in arc-minutes
#' @param path the cache directory
#' @return the path marmap would use, or `NULL` where the convention does not
#'   apply
#' @keywords internal
marmap_cache_file <- function(bounding_box, resolution, path) {
  x1 <- min(bounding_box$xmin, bounding_box$xmax)
  x2 <- max(bounding_box$xmin, bounding_box$xmax)
  y1 <- min(bounding_box$ymin, bounding_box$ymax)
  y2 <- max(bounding_box$ymin, bounding_box$ymax)

  # marmap writes an "_anti" file for antimeridian-crossing requests, built from
  # a differently ordered box. Not worth reproducing for the sake of a cache hit.
  if (x1 < -180 || x2 > 180) return(NULL)

  file.path(path, paste0("marmap_coord_", x1, ";", y1, ";", x2, ";", y2,
                         "_res_", resolution, ".csv"))
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

  positions <- positions_in_crs(dat, bathy, coords)

  extracted <- terra::extract(bathy[[vars]], positions)
  for (v in vars) dat[[v]] <- extracted[[v]]

  report_unmatched(positions, extracted[[vars[1]]], bathy)
  dat
}

#' Put a table's coordinates into a raster's coordinate system
#'
#' @section Why this is not just `st_coordinates()`:
#' `st_coordinates()` returns coordinates in whatever system the object carries.
#' Handing those to [terra::extract()] treats them as the raster's own, so a set
#' of observations in a projected CRS is read as though its metres were degrees.
#' Every point then lands outside the grid and comes back `NA` — observations
#' with no depth, in an area that plainly has depth, with nothing said about it.
#'
#' The CRS is reconciled here instead, so the caller does not have to know that
#' bathymetry arrives in EPSG:4326 while their stations might be in a UTM zone.
#'
#' @param dat a data frame with coordinate columns, or an `sf` object
#' @param target a `SpatRaster` whose CRS the coordinates should end up in
#' @param coords names of the longitude and latitude columns, for data frames
#' @return a two-column matrix in `target`'s coordinate system
#' @keywords internal
positions_in_crs <- function(dat, target, coords) {
  target_crs <- sf::st_crs(terra::crs(target))

  if (inherits(dat, "sf")) {
    dat_crs <- sf::st_crs(dat)

    if (is.na(dat_crs)) {
      warning("The observations carry no CRS, so they are assumed to be in the ",
              "same system as the raster (", format(target_crs$input), "). Set ",
              "one with sf::st_crs() if they are not.", call. = FALSE)
    } else if (!is.na(target_crs) && dat_crs != target_crs) {
      dat <- sf::st_transform(dat, target_crs)
    }
    return(sf::st_coordinates(dat))
  }

  missing_coords <- setdiff(coords, names(dat))
  if (length(missing_coords) > 0) {
    stop("Coordinate column(s) not found: ", paste(missing_coords, collapse = ", "),
         "\nPass `coords` if they are named differently.", call. = FALSE)
  }
  positions <- as.matrix(dat[coords])

  # A plain data frame carries no CRS to check, so the only thing that can be
  # checked is whether the numbers could be degrees at all. Projected
  # coordinates are the common mistake and are obvious by magnitude.
  if (!is.na(target_crs) && isTRUE(sf::st_is_longlat(target_crs))) {
    looks_projected <- any(abs(positions[, 1]) > 180, na.rm = TRUE) ||
      any(abs(positions[, 2]) > 90, na.rm = TRUE)
    if (looks_projected) {
      stop("Coordinates in '", coords[1], "'/'", coords[2], "' are outside the ",
           "range of longitude and latitude,\nso they look projected rather ",
           "than geographic. The raster is in ", format(target_crs$input), ".\n",
           "Convert them first, e.g. with sf::st_as_sf(dat, coords = c(\"",
           coords[1], "\", \"", coords[2], "\"), crs = <their EPSG>),\nand pass ",
           "the sf object, which is reprojected for you.", call. = FALSE)
    }
  }
  positions
}

#' Say how many points got nothing, and why
#'
#' A point can come back `NA` for two quite different reasons, and the remedy
#' differs. Outside the grid means the bounding box was drawn too small. Inside
#' it means the cell holds no depth — ETOPO calls it land, which at 4 arc-minutes
#' happens readily to inshore stations, since a cell roughly 7 km across is land
#' if most of it is.
#'
#' Reported rather than left to be discovered, because a covariate that is `NA`
#' for a subset of observations quietly drops those rows from a model fit.
#'
#' @param positions the coordinate matrix that was extracted at
#' @param values the extracted values of one layer
#' @param bathy the raster they came from
#' @return `NULL`, invisibly; called for the warning
#' @keywords internal
report_unmatched <- function(positions, values, bathy) {
  missing <- is.na(values)
  if (!any(missing)) return(invisible(NULL))

  box <- terra::ext(bathy)
  outside <- positions[, 1] < box$xmin | positions[, 1] > box$xmax |
    positions[, 2] < box$ymin | positions[, 2] > box$ymax
  outside[is.na(outside)] <- TRUE

  n_outside <- sum(missing & outside)
  n_inside <- sum(missing & !outside)

  warning(sum(missing), " of ", length(values), " point(s) got no bathymetry.\n",
          if (n_outside > 0) {
            paste0("  ", n_outside, " fall outside the grid, which spans ",
                   signif(box$xmin, 6), " to ", signif(box$xmax, 6), " lon and ",
                   signif(box$ymin, 6), " to ", signif(box$ymax, 6), " lat.\n",
                   "    Widen `bounding_box` in fetch_bathymetry() to cover them.\n")
          },
          if (n_inside > 0) {
            paste0("  ", n_inside, " fall inside the grid on cells with no ",
                   "depth, which ETOPO treats as land.\n",
                   "    Inshore stations do this: a cell is land if most of it ",
                   "is, so a station in\n    a narrow bay can sit in one. A ",
                   "finer `resolution` in fetch_bathymetry() reduces it.\n")
          },
          call. = FALSE)
  invisible(NULL)
}
