#' Map an environmental variable
#'
#' A quick look at what came back from [accessEnvDat()] — the first thing worth
#' doing after a download, and the fastest way to catch a bounding box that came
#' out somewhere unintended, a variable that is all `NA`, or a depth range that
#' returned the wrong level.
#'
#' The data are rendered as a raster rather than as points, so gaps read as holes
#' rather than as absent dots, and cell size is visible.
#'
#' @section Time steps:
#' Environmental data carries many time steps and a map shows one. `time` picks
#' it: a number is an index into the steps present, and a list or vector names
#' the step directly (`c(YEAR = 2010, MONTH = 6)`). The default is the first step,
#' and the step being shown is written into the title so a map is never ambiguous
#' about which month it is.
#'
#' @param env_dat an `sf` POINT object from [accessEnvDat()]
#' @param var which variable to map; `NULL` uses the first covariate column
#' @param time which time step, as an index or a named vector of
#'   `YEAR`/`MONTH`/`DAY` values
#' @param palette a [grDevices::hcl.colors()] palette name. The default is
#'   perceptually uniform and readable in greyscale, which matters more for a
#'   field of continuous values than the usual rainbow does.
#' @param main plot title; the default names the variable and the time step
#' @param ... passed to [terra::plot()]
#' @return the `SpatRaster` that was plotted, invisibly
#' @examples
#' \dontrun{
#' env <- accessEnvDat(vars = c("SST", "CHL"), years = 2010, months = 1:12,
#'                     bounding_box = bb)
#'
#' plot_env(env)                                  # first variable, first step
#' plot_env(env, "CHL", time = c(MONTH = 6))      # June chlorophyll
#' }
#' @seealso [plot_coverage()] for where the gaps are, [plot_series()] for how a
#'   variable moves through time
#' @export
plot_env <- function(env_dat, var = NULL, time = 1, palette = "viridis",
                     main = NULL, ...) {
  var <- var %||% covariate_columns(env_dat)[1]
  check_columns(env_dat, var)

  step <- select_time_step(env_dat, time)
  slice <- env_dat[step$rows, ]

  coords <- sf::st_coordinates(sf::st_geometry(slice))
  layer <- terra::rast(
    data.frame(x = coords[, 1], y = coords[, 2], value = numeric_for_plot(slice[[var]])),
    type = "xyz", crs = sf::st_crs(env_dat)$wkt)
  names(layer) <- var

  terra::plot(layer, col = grDevices::hcl.colors(100, palette),
              main = main %||% paste0(var, "  ", step$label), ...)

  invisible(layer)
}

#' Plot how much data each time step actually has
#'
#' Satellite ocean colour is missing wherever cloud, ice, or low sun angle blocked
#' the view, and those gaps are not spread evenly — they cluster in particular
#' seasons and latitudes. A series can look complete in a table and be mostly
#' empty in winter.
#'
#' This plots the fraction of cells carrying a value in each time step, which is
#' the thing to look at before trusting a monthly mean or deciding whether
#' [fill_satellite_gaps()] is worth the seam it introduces.
#'
#' @param env_dat an `sf` POINT object from [accessEnvDat()]
#' @param vars which variables to show; `NULL` uses all covariate columns
#' @param main plot title
#' @param ... passed to [graphics::plot()]
#' @return a data frame of the plotted coverage, invisibly, with one row per time
#'   step per variable
#' @examples
#' \dontrun{
#' chl <- accessEnvDat(vars = "CHL", years = 2010, months = 1:12, bounding_box = bb)
#'
#' plot_coverage(chl)
#' # The winter months are the ones to be careful with.
#' }
#' @seealso [fill_satellite_gaps()], [upscale_time()], whose `min_coverage`
#'   argument acts on the same quantity
#' @export
plot_coverage <- function(env_dat, vars = NULL, main = "Data coverage by time step",
                          ...) {
  vars <- vars %||% covariate_columns(env_dat)
  check_columns(env_dat, vars)

  steps <- time_steps(env_dat)
  coverage <- do.call(rbind, lapply(vars, function(v) {
    fraction <- vapply(steps$rows, function(rows) {
      mean(!is.na(env_dat[[v]][rows]))
    }, numeric(1))
    data.frame(variable = v, step = seq_len(nrow(steps$table)),
               label = steps$labels, coverage = fraction,
               stringsAsFactors = FALSE)
  }))

  colours <- grDevices::hcl.colors(max(length(vars), 2), "Dark 3")

  graphics::plot(range(coverage$step), c(0, 1), type = "n",
                 xlab = "", ylab = "fraction of cells with data",
                 main = main, xaxt = "n", ...)
  # Steps are labelled rather than numbered: "which index was that" is not a
  # question anyone wants to answer while looking at a gap.
  at <- pretty_steps(nrow(steps$table))
  graphics::axis(1, at = at, labels = steps$labels[at], las = 2, cex.axis = 0.8)
  graphics::abline(h = c(0.5, 1), col = "grey85", lty = c(2, 1))

  for (i in seq_along(vars)) {
    this <- coverage[coverage$variable == vars[i], ]
    graphics::lines(this$step, this$coverage, col = colours[i], lwd = 2)
    graphics::points(this$step, this$coverage, col = colours[i], pch = 16, cex = 0.6)
  }
  if (length(vars) > 1) {
    graphics::legend("bottomleft", legend = vars, col = colours[seq_along(vars)],
                     lwd = 2, bty = "n", cex = 0.8)
  }

  invisible(coverage)
}

#' Plot a variable through time
#'
#' Reduces each time step to one number over the study area and plots the series,
#' which is how a seasonal cycle, a trend, or a step change at a product boundary
#' becomes visible.
#'
#' The spatial spread is drawn behind the line as a shaded band, because a mean
#' alone hides the difference between a uniformly warm month and one that is warm
#' inshore and cold offshore.
#'
#' @param env_dat an `sf` POINT object from [accessEnvDat()]
#' @param vars which variables to plot; `NULL` uses all covariate columns. Each
#'   gets its own panel, since covariates rarely share units.
#' @param fun the summary applied across cells within each time step
#' @param spread draw the interquartile range across cells as a band
#' @param ... passed to [graphics::plot()]
#' @return a data frame of the plotted series, invisibly
#' @examples
#' \dontrun{
#' env <- accessEnvDat(vars = c("SST", "MLD"), years = 2003:2017, months = 1:12,
#'                     bounding_box = bb)
#'
#' plot_series(env)
#' plot_series(env, "SST", fun = max)   # the warmest cell each month
#' }
#' @seealso [plot_env()] for one step in space, [plot_coverage()]
#' @export
plot_series <- function(env_dat, vars = NULL, fun = mean, spread = TRUE, ...) {
  vars <- vars %||% covariate_columns(env_dat)
  check_columns(env_dat, vars)
  vars <- vars[vapply(vars, function(v) is.numeric(env_dat[[v]]), logical(1))]
  if (length(vars) == 0) {
    stop("No numeric variables to plot.", call. = FALSE)
  }

  steps <- time_steps(env_dat)
  series <- do.call(rbind, lapply(vars, function(v) {
    stats <- vapply(steps$rows, function(rows) {
      values <- env_dat[[v]][rows]
      values <- values[!is.na(values)]
      if (length(values) == 0) return(c(NA_real_, NA_real_, NA_real_))
      c(as.numeric(fun(values)), stats::quantile(values, c(0.25, 0.75)))
    }, numeric(3))
    data.frame(variable = v, step = seq_len(nrow(steps$table)),
               label = steps$labels, value = stats[1, ],
               lower = stats[2, ], upper = stats[3, ],
               stringsAsFactors = FALSE)
  }))

  old <- graphics::par(mfrow = c(length(vars), 1),
                       mar = c(if (length(vars) > 1) 2 else 4, 4, 2, 1))
  on.exit(graphics::par(old), add = TRUE)

  at <- pretty_steps(nrow(steps$table))
  for (v in vars) {
    this <- series[series$variable == v, ]
    ylim <- range(c(this$value, if (spread) c(this$lower, this$upper)), na.rm = TRUE)

    graphics::plot(this$step, this$value, type = "n", ylim = ylim,
                   xlab = "", ylab = v, main = v, xaxt = "n", ...)
    graphics::axis(1, at = at, labels = steps$labels[at], las = 2, cex.axis = 0.8)

    if (spread && any(!is.na(this$lower))) {
      ok <- !is.na(this$lower) & !is.na(this$upper)
      graphics::polygon(c(this$step[ok], rev(this$step[ok])),
                        c(this$lower[ok], rev(this$upper[ok])),
                        col = grDevices::adjustcolor("steelblue", alpha.f = 0.2),
                        border = NA)
    }
    graphics::lines(this$step, this$value, col = "steelblue4", lwd = 2)
  }

  invisible(series)
}

#' Plot observations coloured by a matched covariate
#'
#' What [matchData()] produced, seen rather than summarised. Points that came back
#' `NA` are drawn as open circles rather than dropped, since a cluster of them is
#' usually the real finding — observations outside the environmental data's extent
#' or in a period it does not cover.
#'
#' @section Subset to one period first:
#' The colour scale spans every observation passed in, so plotting several months
#' of a seasonal variable at once mixes the seasons together and the map reads as
#' noise: a warm February inshore point and a cool August offshore one can take
#' the same colour. Subset to a period before plotting, and the spatial pattern
#' reappears:
#'
#' ```
#' plot_matched(matched[matched$MONTH == 7, ], "SST")
#' ```
#'
#' @param matched an `sf` object from [matchData()]
#' @param var which matched variable to colour by; `NULL` uses the first covariate
#' @param palette a [grDevices::hcl.colors()] palette name
#' @param main plot title
#' @param ... passed to [graphics::plot()]
#' @return the plotted values, invisibly
#' @examples
#' \dontrun{
#' matched <- matchData(observations, env)
#'
#' plot_matched(matched, "SST")
#' # Open circles are observations that matched nothing.
#' }
#' @seealso [matchData()], [plot_env()]
#' @export
plot_matched <- function(matched, var = NULL, palette = "viridis", main = NULL,
                         ...) {
  var <- var %||% covariate_columns(matched)[1]
  check_columns(matched, var)

  values <- numeric_for_plot(matched[[var]])
  coords <- sf::st_coordinates(sf::st_geometry(matched))
  missing <- is.na(values)

  colours <- grDevices::hcl.colors(100, palette)
  index <- if (all(missing)) integer(0) else {
    finite <- values[!missing]
    as.integer(cut(finite, breaks = seq(min(finite), max(finite), length.out = 101),
                   include.lowest = TRUE))
  }

  graphics::plot(coords[, 1], coords[, 2], type = "n", asp = 1,
                 xlab = "longitude", ylab = "latitude",
                 main = main %||% paste0(var, "  (", sum(!missing), " matched, ",
                                         sum(missing), " unmatched)"), ...)
  if (any(!missing)) {
    graphics::points(coords[!missing, 1], coords[!missing, 2],
                     pch = 16, cex = 0.7, col = colours[index])
  }
  if (any(missing)) {
    graphics::points(coords[missing, 1], coords[missing, 2],
                     pch = 1, cex = 0.7, col = "grey40")
  }

  invisible(values)
}

#' Distinct time steps, their rows, and their labels
#'
#' Shared by the plotting functions so they all agree on what a time step is and
#' order them the same way.
#'
#' @param env_dat an `sf` POINT object
#' @return a list with `table` (unique steps), `rows` (row indices per step), and
#'   `labels`
#' @keywords internal
time_steps <- function(env_dat) {
  time_cols <- intersect(time_columns(), names(env_dat))
  times <- sf::st_drop_geometry(env_dat)[time_cols]
  steps <- unique(times)
  steps <- steps[do.call(order, steps), , drop = FALSE]

  rows <- lapply(seq_len(nrow(steps)), function(i) {
    keep <- rep(TRUE, nrow(times))
    for (key in time_cols) keep <- keep & times[[key]] == steps[[key]][i]
    which(keep)
  })

  list(table = steps, rows = rows, labels = step_labels(steps, time_cols))
}

#' Human-readable labels for time steps
#'
#' Drops components that never vary, so a single year's monthly data is labelled
#' by month rather than by a repeated year.
#'
#' @param steps a data frame of unique time steps
#' @param time_cols which time columns are present
#' @return character vector
#' @keywords internal
step_labels <- function(steps, time_cols) {
  varying <- time_cols[vapply(time_cols, function(k) length(unique(steps[[k]])) > 1,
                              logical(1))]
  if (length(varying) == 0) varying <- time_cols[1]

  parts <- lapply(varying, function(k) {
    if (k == "YEAR") as.character(steps[[k]]) else sprintf("%02d", steps[[k]])
  })
  do.call(paste, c(parts, sep = "-"))
}

#' Resolve a `time` argument to a set of rows
#'
#' @param env_dat an `sf` POINT object
#' @param time an index, or a named vector of YEAR/MONTH/DAY values
#' @return a list with `rows` and a `label`
#' @keywords internal
select_time_step <- function(env_dat, time) {
  steps <- time_steps(env_dat)

  if (is.null(names(time))) {
    index <- as.integer(time[1])
    if (is.na(index) || index < 1 || index > nrow(steps$table)) {
      stop("`time` index ", time[1], " is outside the ", nrow(steps$table),
           " time step(s) present.", call. = FALSE)
    }
    return(list(rows = steps$rows[[index]], label = steps$labels[index]))
  }

  keep <- rep(TRUE, nrow(steps$table))
  for (key in names(time)) {
    if (!key %in% names(steps$table)) {
      stop("`time` names '", key, "', which is not a time column. Use ",
           paste(names(steps$table), collapse = ", "), ".", call. = FALSE)
    }
    keep <- keep & steps$table[[key]] == time[[key]]
  }
  if (!any(keep)) {
    stop("No time step matches ",
         paste(names(time), unlist(time), sep = " = ", collapse = ", "), ".",
         call. = FALSE)
  }

  index <- which(keep)[1]
  list(rows = steps$rows[[index]], label = steps$labels[index])
}

#' Axis positions that do not overprint
#'
#' @param n number of steps
#' @return integer positions to label
#' @keywords internal
pretty_steps <- function(n) {
  if (n <= 12) return(seq_len(n))
  unique(round(seq(1, n, length.out = 12)))
}

#' Values a raster or colour scale can take
#'
#' Factors are plotted by their level codes, so a categorical column such as the
#' `<var>_source` that [fill_satellite_gaps()] adds can be mapped rather than
#' erroring.
#'
#' @param x a column
#' @return numeric
#' @keywords internal
numeric_for_plot <- function(x) {
  if (is.numeric(x)) x else as.integer(as.factor(x))
}
