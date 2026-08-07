
#' Match one set of points to another in space and time
#'
#' Joins each row of `dat` to the nearest feature of `source` within the same
#' time period, and returns `dat` with `source`'s columns added.
#'
#' Neither side has to be species observations or environmental data. It is a
#' spatiotemporal nearest-feature join between two `sf` point objects that carry
#' `YEAR`/`MONTH`/`DAY` columns, so it works equally for stations against a
#' covariate grid, tag positions against a model field, moorings against
#' satellite retrievals, or one gridded product against another.
#'
#' @section Matching in time:
#' The time period is `source`'s own resolution: daily data matches on
#' year/month/day, monthly data (Copernicus `...P1M-m` means, say) on
#' year/month, and annual data on year alone.
#'
#' That matters because a day-exact join against monthly data matches nothing. A
#' monthly product carries one time step per month, while observations fall on
#' arbitrary days. `temporal_resolution` overrides the inference when the data
#' cannot speak for itself.
#'
#' @section What is preserved:
#' One row out per row of `dat`, in the same order, whatever happens. A period
#' `source` does not cover gives `NA` for its columns and a warning naming the
#' periods, rather than dropping those rows — a silent change in row count is a
#' worse outcome than a visible gap.
#'
#' `dat` keeps its own columns. One of `source`'s that collides with a name
#' already in `dat` is suffixed `.matched`, so nothing of `dat`'s is overwritten
#' or renamed.
#'
#' @param dat <sf object> the points to add columns to: observations, stations,
#'   tag positions, anything with coordinates and time. Needs year and month
#'   columns, plus a day column when matching at daily resolution. Columns whose
#'   names begin with those words are recognised, so `Year` or `obs_month` work.
#' @param source <sf object> the points to take values from, typically a grid
#'   from [accessEnvDat()]. Must carry `YEAR`/`MONTH`/`DAY`.
#' @param temporal_resolution <char> one of `"auto"` (default), `"day"`,
#'   `"month"`, or `"year"`. `"auto"` uses the step `accessEnvDat()` recorded on
#'   `source`, or infers it from `source`'s time steps.
#' @param speciesDat,envDat deprecated names for `dat` and `source`. Still
#'   accepted, with a warning.
#' @return <sf object> `dat` with `source`'s columns joined on, one row per input
#'   row, plus `LON`/`LAT` coordinate columns.
#' @examples
#' \dontrun{
#' env <- accessEnvDat(vars = "SST", years = 2010, months = 1:12, bounding_box = bb)
#'
#' matched <- matchData(observations, env)
#'
#' # Chains, so several sources land on one table
#' matched <- matchData(matched, chlorophyll)
#' }
#' @seealso [accessEnvDat()] for the usual `source`, [attach_bathymetry()] and
#'   [attach_climate_index()] for covariates that are not matched this way
#' @export
matchData <- function(dat, source,
                      temporal_resolution = c("auto", "day", "month", "year"),
                      speciesDat = NULL, envDat = NULL) {

  # The old names were specific to one use of a function that was never specific
  # to it. Accepted for now because taupatch and any script written against the
  # old signature call them by name, and breaking those silently would be worse
  # than carrying two lines.
  if (!is.null(speciesDat)) {
    warning("`speciesDat` is now `dat`. The old name still works but will be ",
            "removed.", call. = FALSE)
    if (missing(dat)) dat <- speciesDat
  }
  if (!is.null(envDat)) {
    warning("`envDat` is now `source`. The old name still works but will be ",
            "removed.", call. = FALSE)
    if (missing(source)) source <- envDat
  }
  if (missing(dat) || missing(source)) {
    if (is.null(speciesDat) || is.null(envDat)) {
      stop("Both `dat` and `source` are required.", call. = FALSE)
    }
  }

  temporal_resolution <- match.arg(temporal_resolution)
  if (temporal_resolution == "auto") {
    temporal_resolution <- detect_temporal_resolution(source)
  }
  match_keys <- switch(temporal_resolution,
                       day = c("YEAR", "MONTH", "DAY"),
                       month = c("YEAR", "MONTH"),
                       year = "YEAR")

  dat <- standardize_time_columns(dat, match_keys)

  source_geom <- attr(source, "sf_column")
  source_vars <- setdiff(names(source), c("YEAR", "MONTH", "DAY", source_geom))

  # Both sides need a CRS before they can be reconciled. Without one,
  # st_transform() fails with "crs not found: is it missing?", which is true but
  # does not say which object or what to do. Silently assuming a CRS would be
  # worse: coordinates would be matched as though they were degrees, and every
  # row would join to whichever feature happened to be nearest in a meaningless
  # space.
  for (side in list(list(x = dat, name = "dat"),
                    list(x = source, name = "source"))) {
    if (is.na(sf::st_crs(side$x))) {
      stop("`", side$name, "` has no coordinate reference system, so it cannot ",
           "be matched.\nSet one with sf::st_crs(", side$name,
           ") <- 4326 for longitude/latitude,\nor the EPSG code the ",
           "coordinates are actually in.", call. = FALSE)
    }
  }

  source <- sf::st_transform(source, sf::st_crs(dat))

  # Give a source column that shares a name with one in `dat` an explicit
  # ".matched" suffix. Otherwise st_join() disambiguates them as ".x"/".y",
  # which both renames the caller's column and makes the result's column names
  # depend on whether a given period actually matched anything.
  collisions <- intersect(source_vars, names(dat))
  if (length(collisions) > 0) {
    renamed <- paste0(collisions, ".matched")
    names(source)[match(collisions, names(source))] <- renamed
    source_vars[match(collisions, source_vars)] <- renamed
  }

  # Rows are processed a period at a time, so they come back grouped by period
  # rather than in the order they arrived. That is a quiet hazard: anyone
  # aligning the result against the input by position - cbind(), or assigning a
  # column straight across - would get silently mismatched rows. The original
  # position is carried through and used to restore the order at the end.
  #
  # The name is deliberately awkward so it cannot collide with a real column.
  order_key <- ".datamatch_row_order"
  dat[[order_key]] <- seq_len(nrow(dat))

  periods <- unique(sf::st_drop_geometry(dat)[match_keys])
  matched <- vector("list", nrow(periods))
  unmatched_periods <- character()

  for (i in seq_len(nrow(periods))) {
    in_period <- rep(TRUE, nrow(dat))
    source_in_period <- rep(TRUE, nrow(source))
    for (key in match_keys) {
      in_period <- in_period & dat[[key]] == periods[[key]][i]
      source_in_period <- source_in_period & source[[key]] == periods[[key]][i]
    }

    rows <- dat[in_period, ]
    source_slice <- source[source_in_period, c(source_vars)]

    if (nrow(source_slice) == 0) {
      # st_nearest_feature cannot join against an empty set, so fill the matched
      # columns with NA rather than dropping the rows. Dropping them would
      # silently change the row count of the result.
      for (v in source_vars) rows[[v]] <- NA
      unmatched_periods <- c(unmatched_periods,
                             paste(unlist(periods[i, , drop = TRUE]), collapse = "-"))
      matched[[i]] <- rows
    } else {
      matched[[i]] <- sf::st_join(rows, source_slice, join = sf::st_nearest_feature)
    }
  }

  if (length(unmatched_periods) > 0) {
    warning("No data in `source` for ", length(unmatched_periods),
            " period(s); matched columns set to NA for: ",
            paste(utils::head(unmatched_periods, 5), collapse = ", "),
            if (length(unmatched_periods) > 5) ", ..." else "", call. = FALSE)
  }

  # Accumulating into a list and binding once, rather than growing a result
  # inside the loop, also removes the previous requirement that the first period
  # iterated be the chronologically first one.
  column_order <- names(matched[[1]])
  matched <- lapply(matched, function(x) x[column_order])
  matched_data <- do.call(rbind, matched)

  # Back into the order the rows arrived in, and drop the bookkeeping column.
  matched_data <- matched_data[order(matched_data[[order_key]]), ]
  matched_data[[order_key]] <- NULL
  rownames(matched_data) <- NULL

  matched_data$LON <- sf::st_coordinates(matched_data)[, 1]
  matched_data$LAT <- sf::st_coordinates(matched_data)[, 2]

  matched_data
}

#' Infer the temporal resolution of a set of time steps
#'
#' Reads the resolution off the time steps actually present: more than one day
#' within any month means daily data, and more than one month within any year
#' means monthly data.
#'
#' A single time step per year is genuinely ambiguous - it looks the same whether
#' the data is annual, or monthly but subset to one month. Annual is inferred only
#' with positive evidence for it: several years present, each stamped on the same
#' single month, as annual products conventionally are. Everything else falls back
#' to monthly, because guessing too coarse is the more damaging error - it silently
#' matches observations to a time step from a different month, whereas guessing too
#' fine leaves them unmatched and warns. Pass `temporal_resolution` explicitly to
#' override.
#'
#' @param x <sf object> an object with YEAR/MONTH/DAY columns, typically the
#'   `source` side of a match
#' @return one of "day", "month", or "year"
#' @keywords internal
detect_temporal_resolution <- function(x) {
  # accessEnvDat() knows which dataset it fetched, so it records the step rather
  # than leaving it to be inferred. Worth trusting over the heuristics below: a
  # `dates` request of one date per month is genuinely indistinguishable from
  # monthly data by inspection, and guessing monthly would drop the day from the
  # match.
  recorded <- attr(x, "datamatch_step")
  if (!is.null(recorded) && recorded %in% c("day", "month", "year")) {
    return(recorded)
  }

  times <- unique(sf::st_drop_geometry(x)[c("YEAR", "MONTH", "DAY")])

  days_per_month <- tapply(times$DAY, paste(times$YEAR, times$MONTH), function(d) length(unique(d)))
  if (any(days_per_month > 1)) return("day")

  months_per_year <- tapply(times$MONTH, times$YEAR, function(m) length(unique(m)))
  if (any(months_per_year > 1)) return("month")

  years <- unique(times$YEAR)
  if (length(years) > 1 && length(unique(times$MONTH)) == 1) return("year")

  "month"
}

#' Rename a table's time columns to YEAR/MONTH/DAY
#'
#' Only the columns needed for the requested match keys are required, so monthly
#' matching works on data that has no day column at all.
#'
#' @param dat <sf object> the table being matched
#' @param match_keys <char> the standardized time columns needed, e.g. c("YEAR", "MONTH")
#' @return `dat` with its time columns renamed to YEAR/MONTH/DAY
#' @keywords internal
standardize_time_columns <- function(dat, match_keys) {
  # sf's select() method keeps the geometry column "sticky" regardless of the
  # select criteria, so it must be excluded here - otherwise the rename() below
  # would rename the geometry column itself and corrupt the sf object's tracked
  # geometry-column name.
  geom_col <- attr(dat, "sf_column")

  for (key in match_keys) {
    if (key %in% names(dat)) next

    prefix <- tolower(key)
    candidates <- setdiff(
      names(dat |> dplyr::select(dplyr::starts_with(prefix, ignore.case = TRUE))),
      geom_col
    )
    # An exact match wins over a mere prefix match, so a dataset carrying both
    # "day" and "jday" resolves to "day" rather than failing as ambiguous.
    exact <- candidates[tolower(candidates) == prefix]
    if (length(exact) == 1) {
      candidates <- exact
    }

    if (length(candidates) == 0) {
      stop("`dat` has no column for '", key, "' (looked for names starting with '",
           prefix, "'). It is required to match at this temporal resolution.",
           call. = FALSE)
    }
    if (length(candidates) > 1) {
      stop("`dat` has multiple candidate '", key, "' columns: ",
           paste(candidates, collapse = ", "),
           ". Rename the intended one to '", key, "'.", call. = FALSE)
    }
    names(dat)[names(dat) == candidates] <- key
  }

  dat
}
