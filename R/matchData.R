
#' Match environmental data to species occurrence data
#'
#' Joins each species observation to the nearest environmental grid point within
#' the same time period. The time period is the environmental data's own temporal
#' resolution: daily products match on year/month/day, monthly products (e.g.
#' Copernicus `...P1M-m` means) on year/month, and annual products on year alone.
#'
#' Matching at the environmental data's native resolution matters because a
#' day-exact join against monthly data matches nothing - a monthly product carries
#' one time step per month, while observations fall on arbitrary days.
#'
#' @param speciesDat <sf object> species observation data (e.g., presence, density, count);
#'                               must have spatial and temporal components. Needs
#'                               year and month columns, plus a day column when
#'                               matching at daily resolution.
#' @param envDat <sf object> environmental data accessed using the datamatch::accessEnvDat
#'                           function to be matched to the species observation data
#' @param temporal_resolution <char> one of "auto" (default), "day", "month", or
#'                                   "year". "auto" infers the resolution from
#'                                   `envDat`'s own time steps.
#' @return <sf object> `speciesDat` with the matched environmental variables joined on,
#'                     one row per input observation, plus LON/LAT coordinate columns.
#'                     Observations in a period with no environmental data get NA
#'                     for the environmental variables, and a warning is issued.
#'                     An environmental variable whose name collides with a column
#'                     already in `speciesDat` is suffixed `.env`.
#' @export
matchData <- function(speciesDat, envDat,
                      temporal_resolution = c("auto", "day", "month", "year")) {

  temporal_resolution <- match.arg(temporal_resolution)
  if (temporal_resolution == "auto") {
    temporal_resolution <- detect_temporal_resolution(envDat)
  }
  match_keys <- switch(temporal_resolution,
                       day = c("YEAR", "MONTH", "DAY"),
                       month = c("YEAR", "MONTH"),
                       year = "YEAR")

  speciesDat <- standardize_time_columns(speciesDat, match_keys)

  env_geom <- attr(envDat, "sf_column")
  env_vars <- setdiff(names(envDat), c("YEAR", "MONTH", "DAY", env_geom))
  envDat <- sf::st_transform(envDat, sf::st_crs(speciesDat))

  # Give environmental variables that share a name with a species column an
  # explicit ".env" suffix. Otherwise st_join() disambiguates them as ".x"/".y",
  # which both renames the species column and makes the result's column names
  # depend on whether a given period actually matched anything.
  collisions <- intersect(env_vars, names(speciesDat))
  if (length(collisions) > 0) {
    renamed <- paste0(collisions, ".env")
    names(envDat)[match(collisions, names(envDat))] <- renamed
    env_vars[match(collisions, env_vars)] <- renamed
  }

  periods <- unique(sf::st_drop_geometry(speciesDat)[match_keys])
  matched <- vector("list", nrow(periods))
  unmatched_periods <- character()

  for (i in seq_len(nrow(periods))) {
    in_period <- rep(TRUE, nrow(speciesDat))
    env_in_period <- rep(TRUE, nrow(envDat))
    for (key in match_keys) {
      in_period <- in_period & speciesDat[[key]] == periods[[key]][i]
      env_in_period <- env_in_period & envDat[[key]] == periods[[key]][i]
    }

    obs <- speciesDat[in_period, ]
    env_slice <- envDat[env_in_period, c(env_vars)]

    if (nrow(env_slice) == 0) {
      # st_nearest_feature cannot join against an empty set, so fill the
      # environmental columns with NA rather than dropping the observations.
      # Dropping them would silently change the row count of the result.
      for (v in env_vars) obs[[v]] <- NA
      unmatched_periods <- c(unmatched_periods,
                             paste(unlist(periods[i, , drop = TRUE]), collapse = "-"))
      matched[[i]] <- obs
    } else {
      matched[[i]] <- sf::st_join(obs, env_slice, join = sf::st_nearest_feature)
    }
  }

  if (length(unmatched_periods) > 0) {
    warning("No environmental data for ", length(unmatched_periods),
            " period(s); environmental variables set to NA for: ",
            paste(utils::head(unmatched_periods, 5), collapse = ", "),
            if (length(unmatched_periods) > 5) ", ..." else "", call. = FALSE)
  }

  # Accumulating into a list and binding once, rather than growing a result
  # inside the loop, also removes the previous requirement that the first period
  # iterated be the chronologically first one.
  column_order <- names(matched[[1]])
  matched <- lapply(matched, function(x) x[column_order])
  matched_data <- do.call(rbind, matched)

  matched_data$LON <- sf::st_coordinates(matched_data)[, 1]
  matched_data$LAT <- sf::st_coordinates(matched_data)[, 2]

  matched_data
}

#' Infer the temporal resolution of environmental data
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
#' @param envDat <sf object> environmental data with YEAR/MONTH/DAY columns
#' @return one of "day", "month", or "year"
#' @keywords internal
detect_temporal_resolution <- function(envDat) {
  # accessEnvDat() knows which dataset it fetched, so it records the step rather
  # than leaving it to be inferred. Worth trusting over the heuristics below: a
  # `dates` request of one date per month is genuinely indistinguishable from
  # monthly data by inspection, and guessing monthly would drop the day from the
  # match.
  recorded <- attr(envDat, "datamatch_step")
  if (!is.null(recorded) && recorded %in% c("day", "month", "year")) {
    return(recorded)
  }

  times <- unique(sf::st_drop_geometry(envDat)[c("YEAR", "MONTH", "DAY")])

  days_per_month <- tapply(times$DAY, paste(times$YEAR, times$MONTH), function(d) length(unique(d)))
  if (any(days_per_month > 1)) return("day")

  months_per_year <- tapply(times$MONTH, times$YEAR, function(m) length(unique(m)))
  if (any(months_per_year > 1)) return("month")

  years <- unique(times$YEAR)
  if (length(years) > 1 && length(unique(times$MONTH)) == 1) return("year")

  "month"
}

#' Rename a species dataset's time columns to YEAR/MONTH/DAY
#'
#' Only the columns needed for the requested match keys are required, so monthly
#' matching works on data that has no day column at all.
#'
#' @param speciesDat <sf object> species observation data
#' @param match_keys <char> the standardized time columns needed, e.g. c("YEAR", "MONTH")
#' @return `speciesDat` with its time columns renamed to YEAR/MONTH/DAY
#' @keywords internal
standardize_time_columns <- function(speciesDat, match_keys) {
  # sf's select() method keeps the geometry column "sticky" regardless of the
  # select criteria, so it must be excluded here - otherwise the rename() below
  # would rename the geometry column itself and corrupt the sf object's tracked
  # geometry-column name.
  geom_col <- attr(speciesDat, "sf_column")

  for (key in match_keys) {
    if (key %in% names(speciesDat)) next

    prefix <- tolower(key)
    candidates <- setdiff(
      names(speciesDat |> dplyr::select(dplyr::starts_with(prefix, ignore.case = TRUE))),
      geom_col
    )
    # An exact match wins over a mere prefix match, so a dataset carrying both
    # "day" and "jday" resolves to "day" rather than failing as ambiguous.
    exact <- candidates[tolower(candidates) == prefix]
    if (length(exact) == 1) {
      candidates <- exact
    }

    if (length(candidates) == 0) {
      stop("speciesDat has no column for '", key, "' (looked for names starting with '",
           prefix, "'). It is required to match at this temporal resolution.",
           call. = FALSE)
    }
    if (length(candidates) > 1) {
      stop("speciesDat has multiple candidate '", key, "' columns: ",
           paste(candidates, collapse = ", "),
           ". Rename the intended one to '", key, "'.", call. = FALSE)
    }
    names(speciesDat)[names(speciesDat) == candidates] <- key
  }

  speciesDat
}
