#' Grid resolution of an environmental data object
#'
#' Read off the coordinates actually present, as the median spacing between
#' neighbouring cell centres in each direction. The median rather than the mean
#' so that a single missing row or column does not shift the answer.
#'
#' Useful on its own for deciding which way to resample: compare two products and
#' the coarser one is the one to bring the other onto, or not, depending on which
#' trade-off you want. See [upscale_grid()] for what that choice costs.
#'
#' @param env_dat an `sf` POINT object from [accessEnvDat()]
#' @return named numeric vector `c(x = , y = )` in the units of the object's CRS,
#'   degrees for [accessEnvDat()] output. `NA` in a direction with only one
#'   distinct coordinate.
#' @examples
#' \dontrun{
#' grid_resolution(env)          # x 0.083  y 0.083
#' }
#' @seealso [upscale_grid()], [downscale_grid()]
#' @export
grid_resolution <- function(env_dat) {
  xy <- sf::st_coordinates(sf::st_geometry(env_dat))
  spacing <- function(v) {
    v <- sort(unique(v))
    if (length(v) < 2) NA_real_ else stats::median(diff(v))
  }
  c(x = spacing(xy[, 1]), y = spacing(xy[, 2]))
}

#' Aggregate environmental data onto a coarser grid
#'
#' Combines the source cells falling inside each target cell into one value, so a
#' 4 km satellite field can be brought onto a 0.25 degree model grid. This is the
#' direction that discards detail, which is the safe direction: every value in the
#' result is a summary of values that were really measured.
#'
#' @section Choosing a method:
#' `mean` is the default and is right for most continuous fields. The others
#' exist because "the value of this coarse cell" is not one question:
#'
#' \itemize{
#'   \item `mean`, `median` — central tendency. `median` resists a single extreme
#'     cell, which matters for satellite chlorophyll, where retrieval artefacts at
#'     cloud edges are high outliers rather than symmetric noise.
#'   \item `min`, `max` — the extreme within the cell. `min` of depth is the
#'     shallowest point a coarse cell contains, which is the relevant number for
#'     whether something can sit on the bottom there; the mean depth of the same
#'     cell is not.
#'   \item `sum` — only for quantities that are per-cell totals rather than
#'     densities. Summing a concentration produces a number with no meaning.
#'   \item `mode` — the commonest value. For categorical fields; applied
#'     automatically to non-numeric columns.
#' }
#'
#' Pass one method for everything, or a named vector to vary it by variable:
#' `method = c(CHL = "median", DEPTH = "min")`, in the style [fill_satellite_gaps()]
#' takes its `vars`.
#'
#' @section Partial cells:
#' Satellite data has holes, and a coarse cell overlapping one is averaged from
#' whatever survived. That average is not wrong so much as differently derived
#' from its neighbours — a cell built from three of sixteen source values is a
#' much noisier estimate, and nothing in the returned number says so.
#'
#' `min_coverage` is the fraction of a target cell's source cells that must carry
#' a value for the result to be reported at all; below it, the cell is `NA`. The
#' default of 0.5 is deliberately visible rather than permissive. Set it to 0 to
#' aggregate whatever is present, and `keep_counts = TRUE` to get the coverage
#' fraction alongside each variable and judge for yourself.
#'
#' @param env_dat an `sf` POINT object from [accessEnvDat()], on a regular grid
#' @param to the target grid: either a resolution in the CRS's units (one number
#'   for square cells, or `c(x, y)`), or another `sf` object whose grid to adopt —
#'   which is the form that puts two products onto one grid.
#' @param vars columns to resample; `NULL` uses all covariate columns, as
#'   [covariate_columns()] reports them
#' @param method one of `"mean"`, `"median"`, `"min"`, `"max"`, `"sum"`, `"mode"`;
#'   length one for all variables, or a named vector per variable
#' @param min_coverage fraction of contributing source cells that must be
#'   non-missing, from 0 to 1
#' @param keep_counts add a `<var>_coverage` column per variable, giving the
#'   fraction of source cells that carried a value
#' @return an `sf` POINT object on the target grid, with the same
#'   `YEAR`/`MONTH`/`DAY` columns as the input
#' @examples
#' \dontrun{
#' chl <- accessEnvDat(vars = "CHL", years = 2010, months = 1:12, bounding_box = bb)
#' sst <- accessEnvDat(vars = "SST", years = 2010, months = 1:12, bounding_box = bb)
#'
#' # Satellite CHL (4 km) onto the physics grid (0.083 degrees)
#' chl_coarse <- upscale_grid(chl, to = sst)
#'
#' # Or onto a stated resolution, with the median to resist retrieval outliers
#' chl_quarter <- upscale_grid(chl, to = 0.25, method = "median")
#' }
#' @seealso [downscale_grid()] for the other direction, [grid_resolution()]
#' @export
upscale_grid <- function(env_dat, to, vars = NULL, method = "mean",
                         min_coverage = 0.5, keep_counts = FALSE) {
  regrid(env_dat, to = to, vars = vars, method = method,
         direction = "up", min_coverage = min_coverage, keep_counts = keep_counts)
}

#' Interpolate environmental data onto a finer grid
#'
#' Puts a coarse field onto a finer grid, so a 0.25 degree model variable can join
#' 4 km satellite data without the satellite being coarsened to meet it.
#'
#' @section What this does and does not do:
#' Downscaling adds cells, not information. A 0.25 degree field rendered at 4 km
#' has 4 km *cells*, but it still resolves nothing below 0.25 degrees, and no
#' method here changes that — none of them consult any other data source, so there
#' is nowhere for real fine-scale structure to come from.
#'
#' That distinction is easy to lose downstream, which is why `nearest` is the
#' default. It replicates each coarse value across the fine cells inside it, so
#' the result is visibly blocky at the source resolution: the output looks like
#' what it is. `bilinear` and `cubic` return a smooth field that looks like a
#' finely-resolved measurement and is not one. They are the better choice when
#' the field really is smooth at the source scale and blockiness would be an
#' artefact — sea surface height, say — and the worse choice when someone later
#' computes a gradient from the result, because that gradient is then a property
#' of the interpolator.
#'
#' \itemize{
#'   \item `nearest` — the value of the containing coarse cell. Invents nothing;
#'     blocky. Required for categorical fields, and applied to them automatically.
#'   \item `bilinear` — weighted by the four surrounding cell centres. Smooth, and
#'     `NA` anywhere a contributing neighbour is `NA`, so gaps grow by a cell.
#'   \item `cubic` — smoother again, over sixteen cells. Can overshoot past the
#'     source range near sharp edges, which for a bounded quantity like
#'     chlorophyll can produce negatives.
#'   \item `idw` — inverse distance weighting over the source points within
#'     `idw_radius`. Unlike the others it fills across holes rather than
#'     propagating them, which makes it the one to use on gappy satellite data
#'     where [fill_satellite_gaps()] is not an option.
#' }
#'
#' @inheritParams upscale_grid
#' @param method one of `"nearest"`, `"bilinear"`, `"cubic"`, `"idw"`; length one
#'   for all variables, or a named vector per variable
#' @param idw_radius search radius for `method = "idw"`, in the CRS's units.
#'   Defaults to twice the source cell size, which reaches the immediate
#'   neighbours; larger draws from further away and smooths more.
#' @param idw_power distance exponent for `method = "idw"`. Higher concentrates
#'   weight on the nearest points, approaching `nearest` in the limit.
#' @return an `sf` POINT object on the target grid, with the same
#'   `YEAR`/`MONTH`/`DAY` columns as the input
#' @examples
#' \dontrun{
#' # Model chlorophyll (0.25 deg) onto the satellite grid, blockiness intact
#' fine <- downscale_grid(chl_model, to = chl_satellite)
#'
#' # Smooth, for a field that really is smooth at the source scale
#' ssh <- downscale_grid(ssh_model, to = 0.04, method = "bilinear")
#' }
#' @seealso [upscale_grid()] for the other direction, [fill_satellite_gaps()]
#' @export
downscale_grid <- function(env_dat, to, vars = NULL, method = "nearest",
                           idw_radius = NULL, idw_power = 2) {
  regrid(env_dat, to = to, vars = vars, method = method, direction = "down",
         idw_radius = idw_radius, idw_power = idw_power)
}

#' Resample environmental data onto another grid
#'
#' The shared implementation of [upscale_grid()] and [downscale_grid()]. Both
#' directions are the same operation on a different set of methods, so they differ
#' only in what they validate and which terra call they end up in.
#'
#' Time steps are handled one at a time, as [fill_satellite_gaps()] does: each
#' step is a complete grid of its own, and stacking them into one raster would
#' make a variable's layers indistinguishable from its time steps.
#'
#' @param env_dat an `sf` POINT object on a regular grid
#' @param to target resolution or `sf` object
#' @param vars columns to resample, or `NULL` for all covariates
#' @param method method name(s), validated against `direction`
#' @param direction `"up"` or `"down"`
#' @param min_coverage minimum non-missing fraction (upscaling only)
#' @param keep_counts add coverage columns (upscaling only)
#' @param idw_radius,idw_power inverse distance weighting parameters
#' @return an `sf` POINT object on the target grid
#' @keywords internal
regrid <- function(env_dat, to, vars = NULL, method, direction,
                   min_coverage = 0, keep_counts = FALSE,
                   idw_radius = NULL, idw_power = 2) {
  vars <- vars %||% covariate_columns(env_dat)
  missing <- setdiff(vars, names(env_dat))
  if (length(missing) > 0) {
    stop("Column(s) not found: ", paste(missing, collapse = ", "),
         "\nAvailable: ", paste(covariate_columns(env_dat), collapse = ", "),
         call. = FALSE)
  }

  methods <- resolve_methods(method, vars, env_dat, direction)
  source_res <- grid_resolution(env_dat)
  target <- target_template(env_dat, to, source_res, direction)

  crs <- sf::st_crs(env_dat)
  time_cols <- intersect(time_columns(), names(env_dat))
  times <- sf::st_drop_geometry(env_dat)[time_cols]
  steps <- unique(times)

  flat <- sf::st_drop_geometry(env_dat)
  coords <- sf::st_coordinates(sf::st_geometry(env_dat))

  # Levels are taken from the whole column, not per time step. A step that
  # happens to contain only "satellite" would otherwise come back with a
  # one-level factor, and rbind would reconcile the steps by coercing to
  # character or by silently remapping codes.
  cat_levels <- list()
  for (v in vars) {
    if (!is.numeric(flat[[v]])) cat_levels[[v]] <- levels(as.factor(flat[[v]]))
  }

  pieces <- vector("list", nrow(steps))
  for (i in seq_len(nrow(steps))) {
    in_step <- rep(TRUE, nrow(env_dat))
    for (key in time_cols) in_step <- in_step & times[[key]] == steps[[key]][i]

    piece <- regrid_step(coords[in_step, , drop = FALSE], flat[in_step, , drop = FALSE],
                         vars, methods, target, crs, direction,
                         min_coverage, keep_counts, idw_radius, idw_power,
                         source_res, cat_levels)
    for (key in time_cols) piece[[key]] <- steps[[key]][i]
    pieces[[i]] <- piece[c(names(piece)[names(piece) != attr(piece, "sf_column")],
                           attr(piece, "sf_column"))]
  }

  out <- do.call(rbind, pieces)
  # Put the columns back in the input's order, so a resampled object is a
  # drop-in for the one it came from.
  ordered <- c(intersect(names(env_dat), names(out)),
               setdiff(names(out), names(env_dat)))
  out[c(setdiff(ordered, attr(out, "sf_column")), attr(out, "sf_column"))]
}

#' Resample one time step
#'
#' @param coords matrix of source cell centres for this step
#' @param values data frame of source values for this step
#' @param vars columns to resample
#' @param methods named vector of resolved terra method names
#' @param target a `SpatRaster` template defining the target grid
#' @param crs the CRS to restore on the way out
#' @param direction `"up"` or `"down"`
#' @param min_coverage minimum non-missing fraction
#' @param keep_counts add coverage columns
#' @param idw_radius,idw_power inverse distance weighting parameters
#' @param source_res source grid resolution, for the IDW radius default
#' @param cat_levels named list of factor levels for non-numeric columns
#' @return an `sf` POINT object for this step
#' @keywords internal
regrid_step <- function(coords, values, vars, methods, target, crs, direction,
                        min_coverage, keep_counts, idw_radius, idw_power,
                        source_res, cat_levels = list()) {
  # A raster holds numbers, so categorical columns travel as their integer codes
  # and are decoded on the way out. Only mode and nearest are permitted for them,
  # so a code is never averaged into one that stands for no level.
  encoded <- values[vars]
  for (v in names(cat_levels)) {
    encoded[[v]] <- as.integer(factor(encoded[[v]], levels = cat_levels[[v]]))
  }

  # accessEnvDat() ends in as.data.frame(x, xy = TRUE), whose default drops rows
  # that are NA in every layer. Gappy satellite data therefore arrives with
  # *absent rows* rather than NA ones; terra::rast(type = "xyz") reinstates them
  # as NA cells, which is what the aggregation and the coverage count both need.
  xyz <- data.frame(x = coords[, 1], y = coords[, 2], encoded)
  source <- tryCatch(
    terra::rast(xyz, type = "xyz", crs = sf::st_crs(crs)$wkt),
    error = function(e) {
      stop("Could not read the source as a regular grid: ", conditionMessage(e),
           "\nRegridding needs data on a regular grid, as accessEnvDat() returns.",
           call. = FALSE)
    }
  )

  layers <- list()
  coverage <- list()
  for (v in vars) {
    layers[[v]] <- if (methods[[v]] == "idw") {
      idw_layer(source[[v]], target, idw_radius %||% (2 * max(source_res, na.rm = TRUE)),
                idw_power)
    } else {
      terra::resample(source[[v]], target, method = methods[[v]])
    }

    if (direction == "up" && (min_coverage > 0 || keep_counts)) {
      # The non-missing fraction behind each target cell: averaging an
      # is-not-NA mask over the same cells the values were averaged over.
      frac <- terra::resample(!is.na(source[[v]]), target, method = "average")
      coverage[[v]] <- frac
      if (min_coverage > 0) {
        layers[[v]] <- terra::ifel(frac >= min_coverage, layers[[v]], NA)
      }
    }
  }

  out <- as.data.frame(terra::rast(layers), xy = TRUE, na.rm = FALSE)
  names(out) <- c("x", "y", vars)

  if (keep_counts && length(coverage) > 0) {
    cov_df <- as.data.frame(terra::rast(coverage), xy = TRUE, na.rm = FALSE)
    # cov_df is x, y, then one column per variable in `vars` order.
    for (k in seq_along(vars)) {
      out[[paste0(vars[k], "_coverage")]] <- cov_df[[k + 2]]
    }
  }

  # Trim to the target cells the source grid actually reaches. This has to be
  # decided from the grid's footprint rather than from whether values came back
  # NA: a target cell outside the study area and one over a cloud gap are both
  # NA, and only the first should disappear. Resampling a raster of ones gives
  # the footprint, since terra::init() fills every cell including the empty ones.
  footprint <- terra::resample(terra::init(source[[1]], 1), target, method = "average")
  inside <- !is.na(terra::values(footprint, mat = FALSE))
  out <- out[inside, , drop = FALSE]

  # Decode categorical columns back to the levels they came in with.
  for (v in names(cat_levels)) {
    out[[v]] <- factor(cat_levels[[v]][round(out[[v]])], levels = cat_levels[[v]])
  }

  sf::st_as_sf(out, coords = c("x", "y"), crs = crs)
}

#' Inverse distance weighting onto a target grid
#'
#' Split out because it takes source *points* rather than a source raster, and so
#' does not go through `terra::resample()` like every other method.
#'
#' @param layer a single-layer `SpatRaster` of source values
#' @param target the target `SpatRaster` template
#' @param radius search radius in the CRS's units
#' @param power distance exponent
#' @return a `SpatRaster` on the target grid
#' @keywords internal
idw_layer <- function(layer, target, radius, power) {
  pts <- as.data.frame(layer, xy = TRUE, na.rm = TRUE)
  if (nrow(pts) == 0) {
    out <- target
    terra::values(out) <- NA_real_
    return(out)
  }
  # interpIDW wants a three-column x/y/value matrix, not a raster.
  terra::interpIDW(target, as.matrix(pts[, 1:3]), radius = radius, power = power)
}

#' Work out the target grid
#'
#' @section Why a stated resolution is anchored:
#' When `to` is a number, the cell centres are placed on a grid anchored at the
#' origin rather than at the data's own corner. Two products upscaled to 0.25
#' degrees therefore land on the *same* cells and can be joined; anchored to their
#' own extents they would sit half a cell apart and silently fail to line up.
#'
#' @param env_dat the source object
#' @param to target resolution or `sf` object
#' @param source_res the source resolution from [grid_resolution()]
#' @param direction `"up"` or `"down"`, for the direction check
#' @return a `SpatRaster` template with no values
#' @keywords internal
target_template <- function(env_dat, to, source_res, direction) {
  crs_wkt <- sf::st_crs(env_dat)$wkt

  if (inherits(to, c("sf", "sfc"))) {
    target_res <- grid_resolution(to)
    xy <- sf::st_coordinates(sf::st_geometry(to))
    # Half a cell out from the outermost centres gives the cell edges.
    ext <- terra::ext(min(xy[, 1]) - target_res[["x"]] / 2,
                      max(xy[, 1]) + target_res[["x"]] / 2,
                      min(xy[, 2]) - target_res[["y"]] / 2,
                      max(xy[, 2]) + target_res[["y"]] / 2)
    template <- terra::rast(ext, resolution = as.numeric(target_res), crs = crs_wkt)
  } else {
    if (!is.numeric(to) || length(to) > 2 || any(!is.finite(to)) || any(to <= 0)) {
      stop("`to` must be a positive resolution (one number, or c(x, y)), ",
           "or an sf object whose grid to adopt.", call. = FALSE)
    }
    target_res <- if (length(to) == 1) c(x = to, y = to) else c(x = to[1], y = to[2])

    bb <- sf::st_bbox(env_dat)
    edge <- function(v, res, up) (if (up) ceiling(v / res) else floor(v / res)) * res
    ext <- terra::ext(edge(bb[["xmin"]], target_res[["x"]], FALSE),
                      edge(bb[["xmax"]], target_res[["x"]], TRUE),
                      edge(bb[["ymin"]], target_res[["y"]], FALSE),
                      edge(bb[["ymax"]], target_res[["y"]], TRUE))
    template <- terra::rast(ext, resolution = as.numeric(target_res), crs = crs_wkt)
  }

  check_direction(source_res, target_res, direction)
  template
}

#' Refuse a resampling that runs the wrong way
#'
#' Calling the wrong one of the pair is easy — the target is often another
#' dataset, whose resolution is not on screen at the call site — and the result
#' is quietly poor rather than obviously broken: aggregation methods applied to a
#' finer target reduce to picking one source cell, and interpolation applied to a
#' coarser one throws away most of the data without saying so.
#'
#' @param source_res,target_res resolutions to compare
#' @param direction `"up"` or `"down"`
#' @return `NULL`, invisibly; called for the error
#' @keywords internal
check_direction <- function(source_res, target_res, direction) {
  source_cell <- prod(source_res, na.rm = TRUE)
  target_cell <- prod(target_res, na.rm = TRUE)

  wrong_way <- if (direction == "up") target_cell < source_cell else target_cell > source_cell
  if (!wrong_way) return(invisible(NULL))

  fmt <- function(r) paste(signif(r, 4), collapse = " x ")
  stop(if (direction == "up") "upscale_grid()" else "downscale_grid()",
       " was called with a target grid that is ",
       if (direction == "up") "finer" else "coarser", " than the source.\n",
       "  source: ", fmt(source_res), "\n",
       "  target: ", fmt(target_res), "\n",
       "Use ", if (direction == "up") "downscale_grid()" else "upscale_grid()",
       " for that direction.", call. = FALSE)
}

#' Resolve method names to terra's, per variable
#'
#' Accepts one method for everything or a named vector per variable, validates it
#' against the direction, and forces non-numeric columns onto the only methods
#' that mean anything for them.
#'
#' @param method the user's `method` argument
#' @param vars the variables being resampled
#' @param env_dat the source object, for column types
#' @param direction `"up"` or `"down"`
#' @return named character vector of terra method names, one per variable
#' @keywords internal
resolve_methods <- function(method, vars, env_dat, direction) {
  valid <- if (direction == "up") {
    c(mean = "average", median = "median", min = "min", max = "max",
      sum = "sum", mode = "mode")
  } else {
    c(nearest = "near", bilinear = "bilinear", cubic = "cubic", idw = "idw")
  }

  explicit <- if (is.null(names(method))) character(0) else names(method)

  if (is.null(names(method))) {
    if (length(method) != 1) {
      stop("`method` must be one name for all variables, or a named vector ",
           "giving one per variable.", call. = FALSE)
    }
    method <- stats::setNames(rep(method, length(vars)), vars)
  } else {
    unknown <- setdiff(names(method), vars)
    if (length(unknown) > 0) {
      stop("`method` names variable(s) not being resampled: ",
           paste(unknown, collapse = ", "), call. = FALSE)
    }
    default <- if (direction == "up") "mean" else "nearest"
    method <- c(method, stats::setNames(rep(default, length(setdiff(vars, names(method)))),
                                        setdiff(vars, names(method))))
  }

  bad <- setdiff(unique(method), names(valid))
  if (length(bad) > 0) {
    stop("Unknown method(s): ", paste(bad, collapse = ", "),
         "\nAvailable for ", if (direction == "up") "upscaling" else "downscaling",
         ": ", paste(names(valid), collapse = ", "), call. = FALSE)
  }

  # A factor's levels are integers underneath, and averaging them yields a level
  # that may not exist. The <var>_source columns fill_satellite_gaps() adds are
  # exactly this case, and they travel with the variables they describe.
  #
  # idw is excluded for categoricals as well as the smooth methods: a distance
  # weighted average of level codes lands between them, which decodes to
  # whichever level happens to sit at that number.
  categorical <- vars[!vapply(vars, function(v) is.numeric(env_dat[[v]]), logical(1))]
  keeps_levels <- if (direction == "up") "mode" else "nearest"

  # A method given for everything is about the numeric variables; a source column
  # riding along should not force the caller to enumerate every column. One named
  # for a categorical explicitly is a different matter, and is an error.
  method[setdiff(categorical, explicit)] <- keeps_levels
  offending <- intersect(categorical, explicit)
  offending <- offending[!method[offending] %in% keeps_levels]
  if (length(offending) > 0) {
    stop("Column(s) ", paste(offending, collapse = ", "), " are not numeric, so ",
         paste(unique(method[offending]), collapse = "/"), " has no meaning for them.\n",
         "Use \"", keeps_levels, "\" for categorical columns, e.g. method = c(",
         offending[1], " = \"", keeps_levels, "\"), or drop them with `vars`.",
         call. = FALSE)
  }

  stats::setNames(valid[method[vars]], vars)
}
