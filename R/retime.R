#' Aggregate environmental data onto a coarser time step
#'
#' Combines the time steps falling inside each target period into one value, so an
#' hourly product becomes daily means, a daily one monthly, or a monthly one
#' annual. The grid is untouched — every cell keeps its own series, aggregated in
#' place.
#'
#' @section Hourly to daily:
#' This is the route to a daily wind field. Copernicus publishes its L4 wind
#' hourly and monthly and nothing between, so `frequency = "daily"` is refused
#' for the wind variables; aggregating the hourly field is how a daily mean is
#' produced, and doing it here rather than inside [accessEnvDat()] keeps the
#' choice of summary — mean wind, or the day's maximum gust — with the caller.
#'
#' The `HOUR` column is consumed rather than carried through: it is the axis
#' being aggregated away. The result is stamped `YEAR`/`MONTH`/`DAY` like any
#' daily product, so [matchData()] reads it back as daily.
#'
#' Note that a daily mean of wind *components* is not the same as a daily mean
#' *speed*. Averaging `UWND` and `VWND` over a day and taking the magnitude gives
#' the net displacement of air; averaging the speed gives how hard it blew. On a
#' day the wind reversed, the first is near zero and the second is not.
#'
#' @section Choosing a method:
#' As with [upscale_grid()], the summary that belongs in a period depends on the
#' question:
#'
#' \itemize{
#'   \item `mean`, `median` — the typical condition over the period.
#'   \item `min`, `max` — the extreme reached within it. The coldest month of a
#'     year is often what determines whether something overwinters somewhere; the
#'     annual mean at the same cell can look perfectly hospitable.
#'   \item `sum` — for per-step totals, such as daily primary production summing
#'     to a seasonal total. Meaningless for a concentration.
#'   \item `sd` — variability within the period, which is a covariate in its own
#'     right: a stable month and a volatile one can share a mean.
#'   \item `mode` — the commonest value, for categorical columns. Applied to them
#'     automatically.
#' }
#'
#' Pass one method for everything, or a named vector to vary it by variable.
#'
#' @section Periods that were only partly downloaded:
#' A mean over the four days of January someone happened to fetch is not a January
#' mean, but nothing in the number itself says so. `min_coverage` is the fraction
#' of the period's *expected* steps that must carry a value — 31 for January, 12
#' months for a year — not the fraction of the steps that were downloaded. A
#' partly-fetched period therefore fails the check rather than passing it
#' trivially.
#'
#' The default of 0.5 will return `NA` for periods at the edges of a request. That
#' is the intended behaviour; set `min_coverage = 0` to aggregate whatever is
#' present, and `keep_counts = TRUE` to see how many steps were behind each value.
#'
#' @param env_dat an `sf` POINT object from [accessEnvDat()]
#' @param to the target period: `"day"`, `"month"`, or `"year"`. `"day"` requires
#'   hourly input, which only the wind variables have.
#' @param vars columns to aggregate; `NULL` uses all covariate columns
#' @param method one of `"mean"`, `"median"`, `"min"`, `"max"`, `"sum"`, `"sd"`,
#'   `"mode"`; length one for all variables, or a named vector per variable
#' @param min_coverage fraction of the period's expected steps that must carry a
#'   value, from 0 to 1
#' @param keep_counts add a `<var>_n` column per variable, giving the number of
#'   steps behind each value
#' @return an `sf` POINT object with one row per cell per target period. Daily
#'   output keeps its `YEAR`/`MONTH`/`DAY` and drops `HOUR`; monthly output is
#'   stamped `DAY = 1`; annual output `MONTH = 1, DAY = 1`, matching what
#'   [accessEnvDat()] returns for non-daily products so that
#'   [matchData()] reads the resolution back correctly.
#' @examples
#' \dontrun{
#' daily <- accessEnvDat(vars = "SST", years = 2010, months = 1:12,
#'                       dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1D-m",
#'                       bounding_box = bb)
#'
#' monthly <- upscale_time(daily, to = "month")
#'
#' # The coldest day in each month, which the monthly mean hides
#' coldest <- upscale_time(daily, to = "month", method = "min")
#' }
#' @seealso [downscale_time()] for the other direction, [upscale_grid()] for the
#'   spatial equivalent
#' @export
upscale_time <- function(env_dat, to = c("month", "year", "day"), vars = NULL,
                         method = "mean", min_coverage = 0.5,
                         keep_counts = FALSE) {
  to <- match.arg(to)
  vars <- vars %||% covariate_columns(env_dat)
  check_columns(env_dat, vars)

  from <- detect_temporal_resolution(env_dat)
  check_time_direction(from, to, "up")

  methods <- resolve_time_methods(method, vars, env_dat, "up")

  flat <- sf::st_drop_geometry(env_dat)
  geom <- sf::st_geometry(env_dat)
  keys <- period_keys(flat, to)

  # Cells are identified by their coordinates, since a cell has one series
  # running through every time step.
  coords <- sf::st_coordinates(geom)
  cell <- paste(coords[, 1], coords[, 2], sep = "_")
  group <- paste(cell, keys$label, sep = "@")
  first <- !duplicated(group)

  out <- data.frame(x = coords[first, 1], y = coords[first, 2])
  out$YEAR <- keys$YEAR[first]
  out$MONTH <- keys$MONTH[first]
  out$DAY <- keys$DAY[first]

  per_day <- if (from == "hour") sub_daily_steps(flat) else 24
  expected <- expected_steps(keys, from, to, per_day)[first]

  for (v in vars) {
    values <- flat[[v]]
    is_cat <- !is.null(attr(methods, "levels")[[v]])
    if (is_cat) values <- as.integer(factor(values, levels = attr(methods, "levels")[[v]]))

    fun <- time_method_fun(methods[[v]])
    aggregated <- vapply(split(values, group), fun, numeric(1))
    counted <- vapply(split(values, group), function(z) sum(!is.na(z)), numeric(1))

    # split() orders by the group labels; put them back in the row order.
    order_key <- group[first]
    aggregated <- aggregated[order_key]
    counted <- counted[order_key]

    if (min_coverage > 0) {
      aggregated[counted / expected < min_coverage] <- NA_real_
    }

    out[[v]] <- if (is_cat) {
      factor(attr(methods, "levels")[[v]][round(aggregated)],
             levels = attr(methods, "levels")[[v]])
    } else {
      unname(aggregated)
    }
    if (keep_counts) out[[paste0(v, "_n")]] <- unname(counted)
  }

  out <- sf::st_as_sf(out, coords = c("x", "y"), crs = sf::st_crs(env_dat))
  # Record the step, as accessEnvDat() does. Inferring it back from the result
  # fails on a single period: one day of hourly data aggregated to daily is one
  # day in one month, which is indistinguishable by inspection from monthly, and
  # detect_temporal_resolution() falls back to "month". matchData() would then
  # join by month and quietly ignore the day. Nothing has to be inferred here,
  # because `to` says exactly what was produced.
  attr(out, "datamatch_step") <- to
  out
}

#' Interpolate environmental data onto a finer time step
#'
#' Puts a coarse series onto a finer one, so a monthly product can be matched to
#' observations on their actual dates rather than by month.
#'
#' @section What this does and does not do:
#' As with [downscale_grid()], this adds time steps rather than information. A
#' monthly mean rendered daily still resolves nothing within the month.
#'
#' There is a further trap specific to the time axis, which is why `step` is the
#' default:
#'
#' **`linear` and `spline` do not preserve the period mean.** Interpolate twelve
#' monthly means to daily values and average those days back up, and you will not
#' recover the months you started from. The interpolated series is a plausible
#' smooth curve through the monthly values, not a disaggregation of them, and any
#' budget or total computed from it will be off. `step` does preserve the mean,
#' because every day in the month carries the month's own value.
#'
#' \itemize{
#'   \item `step` — every fine step takes its containing period's value. Preserves
#'     the period mean; discontinuous at period boundaries. Required for
#'     categorical columns, and applied to them automatically.
#'   \item `linear` — straight lines between period midpoints. Continuous, and
#'     the usual choice when a series is going into a model as a smooth covariate.
#'   \item `spline` — a natural cubic spline through the midpoints. Smoother than
#'     linear, and can overshoot past the source range between points, which for a
#'     bounded quantity like chlorophyll can produce negatives.
#' }
#'
#' @section Where a period's value sits:
#' `linear` and `spline` need each source value placed at a point in time, and a
#' monthly mean is placed at the **middle** of its month rather than the first.
#' Placing it at day 1 would shift the whole interpolated series half a month
#' early, which is a systematic bias rather than a rounding difference.
#'
#' @inheritParams upscale_time
#' @param to the target step: `"day"` or `"month"`
#' @param method one of `"step"`, `"linear"`, `"spline"`; length one for all
#'   variables, or a named vector per variable
#' @param extrapolate hold the first and last values constant beyond the outermost
#'   period midpoints. With `FALSE` those half-periods are `NA`, since there is no
#'   second point to interpolate between.
#' @return an `sf` POINT object with one row per cell per target step
#' @examples
#' \dontrun{
#' monthly <- accessEnvDat(vars = "SST", years = 2010, months = 1:12, bounding_box = bb)
#'
#' # Daily steps, each carrying its month's value
#' daily <- downscale_time(monthly, to = "day")
#'
#' # A smooth seasonal cycle instead, for a covariate going into a model
#' smooth <- downscale_time(monthly, to = "day", method = "spline")
#' }
#' @seealso [upscale_time()] for the other direction, [downscale_grid()]
#' @export
downscale_time <- function(env_dat, to = c("day", "month"), vars = NULL,
                           method = "step", extrapolate = TRUE) {
  to <- match.arg(to)
  vars <- vars %||% covariate_columns(env_dat)
  check_columns(env_dat, vars)

  from <- detect_temporal_resolution(env_dat)
  check_time_direction(from, to, "down")

  methods <- resolve_time_methods(method, vars, env_dat, "down")

  flat <- sf::st_drop_geometry(env_dat)
  coords <- sf::st_coordinates(sf::st_geometry(env_dat))
  cell <- paste(coords[, 1], coords[, 2], sep = "_")

  source_time <- period_midpoint(flat, from)
  target_dates <- target_time_steps(flat, from, to)

  # `step` is a lookup, not an interpolation: a target step takes the value of
  # the period containing it. Running it through the midpoint-based
  # interpolation instead would put the first half of each month on the previous
  # month's value, since that is the midpoint it follows.
  source_period <- period_label(flat$YEAR, flat$MONTH, from)
  target_period <- period_label(as.integer(format(target_dates, "%Y")),
                                as.integer(format(target_dates, "%m")), from)

  cells <- !duplicated(cell)
  n_cells <- sum(cells)
  n_steps <- length(target_dates)

  out <- data.frame(
    x = rep(coords[cells, 1], each = n_steps),
    y = rep(coords[cells, 2], each = n_steps),
    YEAR = rep(as.integer(format(target_dates, "%Y")), times = n_cells),
    MONTH = rep(as.integer(format(target_dates, "%m")), times = n_cells),
    DAY = rep(as.integer(format(target_dates, "%d")), times = n_cells)
  )

  cell_ids <- cell[cells]
  target_num <- as.numeric(target_dates)

  for (v in vars) {
    levels_v <- attr(methods, "levels")[[v]]
    values <- flat[[v]]
    if (!is.null(levels_v)) values <- as.integer(factor(values, levels = levels_v))

    interpolated <- numeric(n_cells * n_steps)
    for (k in seq_along(cell_ids)) {
      rows <- which(cell == cell_ids[k])
      series <- if (methods[[v]] == "step") {
        values[rows][match(target_period, source_period[rows])]
      } else {
        interpolate_series(as.numeric(source_time[rows]), values[rows],
                           target_num, methods[[v]], extrapolate)
      }
      interpolated[((k - 1) * n_steps + 1):(k * n_steps)] <- series
    }

    out[[v]] <- if (!is.null(levels_v)) {
      factor(levels_v[round(interpolated)], levels = levels_v)
    } else {
      interpolated
    }
  }

  out <- sf::st_as_sf(out, coords = c("x", "y"), crs = sf::st_crs(env_dat))
  # As in upscale_time(): `to` states the step, so nothing has to be inferred
  # from a result that may cover too few periods to say.
  attr(out, "datamatch_step") <- to
  out
}

#' Interpolate one cell's series onto the target time steps
#'
#' @param x source times, as numeric days
#' @param y source values
#' @param xout target times, as numeric days
#' @param method `"step"`, `"linear"`, or `"spline"`
#' @param extrapolate hold end values constant beyond the source range
#' @return numeric vector of length `length(xout)`
#' @keywords internal
interpolate_series <- function(x, y, xout, method, extrapolate) {
  ok <- !is.na(y)
  # One point defines no slope and no curve, so every method degenerates to
  # holding it - which is what "step" would have done anyway.
  if (sum(ok) == 0) return(rep(NA_real_, length(xout)))
  if (sum(ok) == 1) {
    return(if (extrapolate) rep(y[ok], length(xout))
           else ifelse(xout == x[ok], y[ok], NA_real_))
  }

  rule <- if (extrapolate) 2 else 1

  switch(method,
    step = stats::approx(x[ok], y[ok], xout = xout, method = "constant",
                         f = 0, rule = rule)$y,
    linear = stats::approx(x[ok], y[ok], xout = xout, rule = rule)$y,
    spline = {
      fitted <- stats::spline(x[ok], y[ok], xout = xout, method = "natural")$y
      if (!extrapolate) fitted[xout < min(x[ok]) | xout > max(x[ok])] <- NA_real_
      fitted
    }
  )
}

#' Period a row belongs to, and how it is stamped in the result
#'
#' Monthly output carries `DAY = 1` and annual output `MONTH = 1, DAY = 1`. That
#' is not cosmetic: [detect_temporal_resolution()] infers annual data from several
#' years all stamped on one month, so aggregating to years and then passing the
#' result to [matchData()] only works if the two agree on the convention.
#'
#' @param flat a data frame with YEAR/MONTH/DAY columns
#' @param to `"day"`, `"month"`, or `"year"`
#' @return a list with `YEAR`, `MONTH`, `DAY`, and a `label` identifying the period
#' @keywords internal
period_keys <- function(flat, to) {
  if (to == "day") {
    # The day the hours belong to, which the rows already carry. HOUR itself is
    # not part of the result: it is the axis being aggregated away, and keeping
    # it would leave every row stamped with whichever hour happened to be first.
    list(YEAR = flat$YEAR, MONTH = flat$MONTH, DAY = flat$DAY,
         label = paste(flat$YEAR, flat$MONTH, flat$DAY, sep = "-"))
  } else if (to == "month") {
    list(YEAR = flat$YEAR, MONTH = flat$MONTH, DAY = rep(1L, nrow(flat)),
         label = paste(flat$YEAR, flat$MONTH, sep = "-"))
  } else {
    list(YEAR = flat$YEAR, MONTH = rep(1L, nrow(flat)), DAY = rep(1L, nrow(flat)),
         label = as.character(flat$YEAR))
  }
}

#' How many sub-daily steps a whole day of this series holds
#'
#' The denominator for `min_coverage` when aggregating sub-daily data. Not every
#' sub-daily product is hourly: the Copernicus wind is, at 24 steps a day, but
#' HYCOM is three-hourly, at 8. Assuming 24 would score a complete HYCOM day at
#' a third of its coverage and return `NA` for every one of them.
#'
#' Read from the spacing of the hours actually present rather than from a
#' recorded step, so it is right for any regular sub-daily series without each
#' source having to declare itself. The smallest gap between distinct hours is
#' the step; a series carrying one hour only cannot say, and falls back to
#' hourly, which is the conservative reading — it under-counts coverage rather
#' than over-counting it.
#'
#' @param flat a data frame with an `HOUR` column
#' @return <integer> steps per day
#' @keywords internal
sub_daily_steps <- function(flat) {
  hours <- sort(unique(flat$HOUR))
  if (length(hours) < 2) return(24L)

  spacing <- min(diff(hours))
  if (is.na(spacing) || spacing <= 0) return(24L)
  max(1L, as.integer(round(24 / spacing)))
}

#' How many source steps a target period should contain
#'
#' The denominator for `min_coverage`. Deliberately the number of steps the period
#' *has* rather than the number downloaded, so that a partly-fetched month is
#' caught instead of scoring full coverage on its own handful of days.
#'
#' @param keys output of [period_keys()]
#' @param from source resolution
#' @param to target period
#' @param per_day how many sub-daily steps a whole day holds, from
#'   [sub_daily_steps()]. 24 for an hourly series, 8 for a three-hourly one.
#' @return numeric vector, one per row
#' @keywords internal
expected_steps <- function(keys, from, to, per_day = 24) {
  if (from == "hour" && to == "day") {
    rep(per_day, length(keys$YEAR))
  } else if (from == "hour" && to == "month") {
    per_day * as.numeric(lubridate::days_in_month(
      lubridate::ymd(paste(keys$YEAR, keys$MONTH, 1, sep = "-"))))
  } else if (from == "hour" && to == "year") {
    per_day * ifelse(lubridate::leap_year(keys$YEAR), 366, 365)
  } else if (from == "day" && to == "month") {
    as.numeric(lubridate::days_in_month(
      lubridate::ymd(paste(keys$YEAR, keys$MONTH, 1, sep = "-"))))
  } else if (from == "day" && to == "year") {
    ifelse(lubridate::leap_year(keys$YEAR), 366, 365)
  } else if (from == "month" && to == "year") {
    rep(12, length(keys$YEAR))
  } else {
    rep(1, length(keys$YEAR))
  }
}

#' Label identifying which period a time belongs to
#'
#' Used to match target steps back to the source period containing them.
#'
#' @param year,month integer vectors
#' @param from the source resolution the label should distinguish
#' @return character vector
#' @keywords internal
period_label <- function(year, month, from) {
  if (from == "year") as.character(year) else paste(year, month, sep = "-")
}

#' The point in time a period's value represents
#'
#' The middle of the period, not its start. A monthly mean placed at day 1 would
#' shift an interpolated series half a month early.
#'
#' @param flat a data frame with YEAR/MONTH/DAY columns
#' @param from source resolution
#' @return a Date vector
#' @keywords internal
period_midpoint <- function(flat, from) {
  if (from == "day") {
    lubridate::ymd(paste(flat$YEAR, flat$MONTH, flat$DAY, sep = "-"))
  } else if (from == "month") {
    start <- lubridate::ymd(paste(flat$YEAR, flat$MONTH, 1, sep = "-"))
    start + (lubridate::days_in_month(start) - 1) / 2
  } else {
    start <- lubridate::ymd(paste(flat$YEAR, 1, 1, sep = "-"))
    start + ifelse(lubridate::leap_year(flat$YEAR), 366, 365) / 2
  }
}

#' Every target time step spanned by the source
#'
#' @param flat a data frame with YEAR/MONTH/DAY columns
#' @param from source resolution
#' @param to target resolution
#' @return a Date vector of the steps to produce
#' @keywords internal
target_time_steps <- function(flat, from, to) {
  years <- sort(unique(flat$YEAR))

  if (to == "month") {
    months <- if (from == "year") 1:12 else sort(unique(flat$MONTH))
    dates <- expand.grid(YEAR = years, MONTH = months)
    dates <- dates[order(dates$YEAR, dates$MONTH), ]
    return(lubridate::ymd(paste(dates$YEAR, dates$MONTH, 1, sep = "-")))
  }

  # Daily: every day of every month the source covers.
  months <- if (from == "year") 1:12 else sort(unique(flat$MONTH))
  out <- do.call(c, lapply(years, function(y) {
    do.call(c, lapply(months, function(m) {
      start <- lubridate::ymd(paste(y, m, 1, sep = "-"))
      seq(start, by = "day", length.out = lubridate::days_in_month(start))
    }))
  }))
  sort(out)
}

#' Refuse a temporal resampling that runs the wrong way
#'
#' @param from source resolution
#' @param to target resolution
#' @param direction `"up"` or `"down"`
#' @return `NULL`, invisibly; called for the error
#' @keywords internal
check_time_direction <- function(from, to, direction) {
  rank <- c(hour = 1, day = 2, month = 3, year = 4)
  wrong_way <- if (direction == "up") rank[[to]] <= rank[[from]] else rank[[to]] >= rank[[from]]
  if (!wrong_way) return(invisible(NULL))

  stop(if (direction == "up") "upscale_time()" else "downscale_time()",
       " was called with a target step that is ",
       if (rank[[to]] == rank[[from]]) "the same as" else {
         if (direction == "up") "finer than" else "coarser than"
       },
       " the source.\n",
       "  source: ", from, "\n",
       "  target: ", to, "\n",
       if (rank[[to]] == rank[[from]]) {
         "There is nothing to do at the same resolution."
       } else {
         paste0("Use ", if (direction == "up") "downscale_time()" else "upscale_time()",
                " for that direction.")
       }, call. = FALSE)
}

#' Check that requested columns exist
#'
#' @param env_dat the source object
#' @param vars requested columns
#' @return `NULL`, invisibly; called for the error
#' @keywords internal
check_columns <- function(env_dat, vars) {
  missing <- setdiff(vars, names(env_dat))
  if (length(missing) > 0) {
    stop("Column(s) not found: ", paste(missing, collapse = ", "),
         "\nAvailable: ", paste(covariate_columns(env_dat), collapse = ", "),
         call. = FALSE)
  }
  invisible(NULL)
}

#' Resolve temporal method names, per variable
#'
#' Mirrors [resolve_methods()] for the time axis. Factor levels for categorical
#' columns are attached to the result, since the aggregation needs them and
#' recomputing them per variable would risk two different level orders.
#'
#' @param method the user's `method` argument
#' @param vars the variables being resampled
#' @param env_dat the source object, for column types
#' @param direction `"up"` or `"down"`
#' @return named character vector of methods, with a `levels` attribute
#' @keywords internal
resolve_time_methods <- function(method, vars, env_dat, direction) {
  valid <- if (direction == "up") {
    c("mean", "median", "min", "max", "sum", "sd", "mode")
  } else {
    c("step", "linear", "spline")
  }
  default <- if (direction == "up") "mean" else "step"

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
    fill <- setdiff(vars, names(method))
    method <- c(method, stats::setNames(rep(default, length(fill)), fill))
  }

  bad <- setdiff(unique(method), valid)
  if (length(bad) > 0) {
    stop("Unknown method(s): ", paste(bad, collapse = ", "),
         "\nAvailable for ", if (direction == "up") "upscaling" else "downscaling",
         ": ", paste(valid, collapse = ", "), call. = FALSE)
  }

  categorical <- vars[!vapply(vars, function(v) is.numeric(env_dat[[v]]), logical(1))]
  keeps_levels <- if (direction == "up") "mode" else "step"

  # As in resolve_methods(): a blanket method is about the numeric variables, so
  # categoricals fall back to the only method that means anything for them. Naming
  # one explicitly with an invalid method is still an error.
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

  method <- method[vars]
  attr(method, "levels") <- stats::setNames(
    lapply(categorical, function(v) levels(as.factor(env_dat[[v]]))), categorical)
  method
}

#' The aggregation function behind a temporal method name
#'
#' All of them drop missing values, and all return `NA` rather than the `Inf` or
#' `NaN` that `min`, `max`, and `mean` produce on an empty vector — an `Inf` would
#' otherwise travel silently into a model.
#'
#' @param name a method name
#' @return a function taking a numeric vector and returning one number
#' @keywords internal
time_method_fun <- function(name) {
  safe <- function(f) function(z) {
    z <- z[!is.na(z)]
    if (length(z) == 0) return(NA_real_)
    as.numeric(f(z))
  }
  switch(name,
    mean = safe(mean),
    median = safe(stats::median),
    min = safe(min),
    max = safe(max),
    sum = safe(sum),
    # sd of a single value is NA, which is correct rather than a failure: one
    # observation carries no information about spread.
    sd = function(z) {
      z <- z[!is.na(z)]
      if (length(z) < 2) return(NA_real_)
      stats::sd(z)
    },
    mode = safe(function(z) {
      counts <- table(z)
      as.numeric(names(counts)[which.max(counts)])
    })
  )
}
