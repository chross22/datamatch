
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
#' @section Which geometries can be matched:
#' `dat` may hold **points, lines or polygons** — survey stations, tow tracks,
#' transects, statistical areas. The join is nearest-feature against the whole
#' geometry, so a tow matches the nearest grid cell to the track rather than to
#' any one end of it, and an area matches the nearest cell to the area.
#'
#' `LON`/`LAT` are then a *representative point* rather than the geometry: for a
#' line or polygon they come from [sf::st_point_on_surface()], which is
#' guaranteed to lie on the feature where a centroid need not. The geometry
#' column itself is untouched, so nothing is lost — but do not read `LON`/`LAT`
#' as the position of an area.
#'
#' A caution about extended geometries: a long tow or a large area may lie
#' nearer one cell while spanning several, and nearest-feature returns exactly
#' one. Where a track crosses a front, consider splitting it, or matching its
#' vertices as points and summarising afterwards.
#'
#' `source` should be points, as every access function returns.
#'
#' @section Matching in time:
#' The time period is `source`'s own resolution: hourly data matches on
#' year/month/day/hour, daily data on year/month/day, monthly data (Copernicus
#' `...P1M-m` means, say) on year/month, and annual data on year alone.
#'
#' Matching hourly needs `dat` to say which hour each row belongs to, in a column
#' recognised the same way as the others — `HOUR`, `hour`, `hour_utc`, but not
#' `obs_hour`, which does not begin with the word. On UTC, as the environmental
#' data is: an observation timestamped in local time will match the wrong hour,
#' and nothing in the join can detect that.
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
#' @section Which source a column came from:
#' The access functions share variable names on purpose, so `SST` from
#' Copernicus, FVCOM, HYCOM and MUR all arrives in a column called `SST` and
#' everything downstream works unchanged. The cost is that a table with several sources chained onto it
#' has no record of which produced what.
#'
#' So each joined column gets a companion `<var>_source` naming the source and
#' archive — `"hycom:GLBv53X"`, `"fvcom:GOM3"` — in the same spirit as the
#' `<var>_source` column [fill_satellite_gaps()] writes. Pass
#' `record_source = FALSE` to omit them.
#'
#' These are provenance rather than data: [covariate_columns()] excludes them, so
#' they are not aggregated, regridded or plotted as though they were measurements.
#'
#' @param dat <sf object> the points to add columns to: observations, stations,
#'   tag positions, anything with coordinates and time. Needs year and month
#'   columns, plus a day column when matching at daily resolution and an hour
#'   column at hourly. Columns whose names *begin* with those words are
#'   recognised, whatever their case, so `Year` and `month_utc` work but
#'   `obs_month` does not — rename it, or pass it as `MONTH`. Day-of-year names
#'   (`yearday`, `dayofyear`, `jday`, `doy` and the like) are never used, even
#'   though some of them do begin with `year` or `day`: they hold an ordinal day
#'   rather than a year or a day of the month. An unrecognised name is named in
#'   the error, so nothing has to be guessed at.
#' @param source <sf object> the points to take values from: a grid from any
#'   access function — [accessCopernicus()], [accessFVCOM()], [accessHYCOM()],
#'   [accessCCMP()] or [accessERDDAP()]. Must carry `YEAR`/`MONTH`/`DAY`, and
#'   `HOUR` as well when matching hourly.
#' @param temporal_resolution <char> one of `"auto"` (default), `"hour"`,
#'   `"day"`, `"month"`, or `"year"`. `"auto"` uses the step the access function
#'   recorded on `source`, or infers it from `source`'s time steps.
#' @param record_source <logical> add a `<var>_source` column for each column
#'   joined, naming which source and archive produced it. On by default, and only
#'   has an effect when `source` carries the stamp an access function leaves —
#'   see [source_of()]. Set `FALSE` for the narrower table.
#' @param speciesDat,envDat deprecated names for `dat` and `source`. Still
#'   accepted, with a warning.
#' @return <sf object> `dat` with `source`'s columns joined on, one row per input
#'   row, plus `LON`/`LAT` coordinate columns.
#' @examples
#' \dontrun{
#' env <- accessCopernicus(vars = "SST", years = 2010, months = 1:12, bounding_box = bb)
#'
#' matched <- matchData(observations, env)
#'
#' # Chains, so several sources land on one table
#' matched <- matchData(matched, chlorophyll)
#' }
#' @seealso [accessCopernicus()], [accessFVCOM()], [accessHYCOM()], [accessCCMP()]
#'   and [accessERDDAP()] for the usual `source`; [attach_bathymetry()] and
#'   [attach_climate_index()] for covariates that are not matched this way
#' @export
matchData <- function(dat, source,
                      temporal_resolution = c("auto", "hour", "day", "month",
                                              "year"),
                      record_source = TRUE,
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
                       hour = c("YEAR", "MONTH", "DAY", "HOUR"),
                       day = c("YEAR", "MONTH", "DAY"),
                       month = c("YEAR", "MONTH"),
                       year = "YEAR")

  # Matching on the hour needs `source` to be stamped with one. Asking for it
  # against data that has none would otherwise fail inside the period loop, on a
  # column that is missing rather than empty.
  if (temporal_resolution == "hour" && !"HOUR" %in% names(source)) {
    stop("temporal_resolution = \"hour\" was given, but `source` has no HOUR ",
         "column.\nOnly an hourly fetch - accessCopernicus(frequency = \"hourly\") ",
         "- carries one. Match at\n\"day\" or coarser instead.", call. = FALSE)
  }

  dat <- standardize_time_columns(dat, match_keys)

  source_geom <- attr(source, "sf_column")
  source_vars <- setdiff(names(source), c(time_columns(), source_geom))

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
  # A fetch spanning several archives records its source per row rather than
  # once for the object, so that column has to ride through the join with the
  # variables. Empty for the usual single-archive fetch.
  row_source_col <- if (!is.null(row_sources(source))) ".datamatch_source" else character(0)

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
    source_slice <- source[source_in_period, c(source_vars, row_source_col)]

    if (nrow(source_slice) == 0) {
      # st_nearest_feature cannot join against an empty set, so fill the matched
      # columns with NA rather than dropping the rows. Dropping them would
      # silently change the row count of the result.
      for (v in c(source_vars, row_source_col)) rows[[v]] <- NA
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

  # st_coordinates() returns one row per *vertex*, which equals one row per
  # feature only for points. On a tow track or a statistical area it returns far
  # more, and assigning that to a column failed with an opaque
  # `[[<-.data.frame` error - so anything but points could not be matched at
  # all, despite the join itself handling them.
  #
  # A representative point stands in for the geometry instead. st_point_on_surface
  # is used rather than the centroid because it is guaranteed to lie *on* the
  # feature, which a centroid is not for a crescent-shaped area or a curved track.
  geometry_types <- unique(as.character(sf::st_geometry_type(matched_data)))
  representative <- if (identical(geometry_types, "POINT")) {
    sf::st_coordinates(matched_data)
  } else {
    sf::st_coordinates(
      suppressWarnings(sf::st_point_on_surface(sf::st_geometry(matched_data))))
  }
  matched_data$LON <- representative[, 1]
  matched_data$LAT <- representative[, 2]

  # Record which source each joined column came from. The five access functions
  # deliberately share variable names, so an SST column cannot say on its own
  # whether it holds a global reanalysis, a regional coastal model or an
  # independent global model - and once several are chained onto one table, the
  # only other record of it is the caller's memory of which calls they made.
  # Per row where the fetch spanned archives, one value for the whole object
  # otherwise. The per-row form matters because a continuous HYCOM fetch crosses
  # from a reanalysis into the model as it was running at the time, and which
  # side of that seam a value came from is a property of the row, not the fetch.
  per_row <- if (length(row_source_col)) matched_data[[".datamatch_source"]] else NULL
  provenance <- if (!is.null(per_row)) per_row else source_of(source)

  if (record_source && !all(is.na(provenance))) {
    for (v in source_vars) {
      matched_data[[paste0(v, "_source")]] <- provenance
    }
  }
  if (length(row_source_col)) matched_data[[".datamatch_source"]] <- NULL

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
#' @param x <sf object> an object with YEAR/MONTH/DAY columns, and HOUR when the
#'   data is hourly; typically the `source` side of a match
#' @return one of "hour", "day", "month", or "year"
#' @keywords internal
detect_temporal_resolution <- function(x) {
  # accessCopernicus() knows which dataset it fetched, so it records the step rather
  # than leaving it to be inferred. Worth trusting over the heuristics below: a
  # `dates` request of one date per month is genuinely indistinguishable from
  # monthly data by inspection, and guessing monthly would drop the day from the
  # match.
  recorded <- attr(x, "datamatch_step")
  if (!is.null(recorded) && recorded %in% c("hour", "day", "month", "year")) {
    return(recorded)
  }

  # An HOUR column exists only on an hourly fetch, and nothing else in the
  # package produces one, so its presence is evidence rather than a guess.
  # Checked before the day heuristic, which hourly data would otherwise satisfy
  # on its way past.
  if ("HOUR" %in% names(x)) {
    hours <- sf::st_drop_geometry(x)[c("YEAR", "MONTH", "DAY", "HOUR")]
    hours_per_day <- tapply(hours$HOUR, paste(hours$YEAR, hours$MONTH, hours$DAY),
                            function(h) length(unique(h)))
    if (any(hours_per_day > 1)) return("hour")
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
    # Day-of-year columns are never a candidate for anything. "yearday" begins
    # with "year" and would otherwise be taken as the year itself; "dayofyear"
    # begins with "day". Either way the value is an ordinal day, so every row
    # would land in a period no source covers, and the join would come back all
    # NA behind a warning about uncovered periods rather than an error. Refusing
    # them costs a rename in the rare case one really is meant; accepting them
    # costs a wrong answer that looks like a data gap.
    candidates <- candidates[!tolower(candidates) %in% day_of_year_names]

    # An exact match wins over a mere prefix match, so a dataset carrying both
    # "day" and "day_night" resolves to "day" rather than failing as ambiguous.
    exact <- candidates[tolower(candidates) == prefix]
    if (length(exact) == 1) {
      candidates <- exact
    }

    if (length(candidates) == 0) {
      # The rule is a prefix match, not a contains match, so "obs_month" is not
      # recognised either. Widening it would pick that up at the cost of "jday",
      # which as the only candidate would be renamed without complaint - the
      # same silent failure the exclusion above exists to prevent, and one the
      # exact-match tiebreak cannot catch, since it only fires when a real "day"
      # column is present to beat the near miss.
      #
      # So near misses are named here instead of being used. The user makes the
      # call, and the rename is visible in their own code.
      near <- setdiff(names(dat)[grepl(prefix, tolower(names(dat)), fixed = TRUE)],
                      geom_col)
      hint <- if (length(near) > 0) {
        paste0("\nThese have a similar name but were not used: ",
               paste(near, collapse = ", "),
               ".\nRename the intended one to '", key,
               "', if one of them is what you mean.")
      } else {
        ""
      }
      stop("`dat` has no column for '", key, "' (looked for names starting with '",
           prefix, "'). It is required to match at this temporal resolution.",
           hint, call. = FALSE)
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
