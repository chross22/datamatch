
#' Match environmental data to species occurrence data
#'
#' @param speciesDat <sf object> species observation data (e.g., presence, density, count);
#'                               must have spatial and temporal components
#' @param envDat <sf object> environmental data accessed using the datamatch::accessEnvDat
#'                           function to be matched to the species observation data
#' @return envDat <sf object> sf object containing requested environmental data from Copernicus Marine Service
matchData <- function(speciesDat, envDat) {

  # Determine names of year, month, and day columns. sf's select() method
  # always keeps the geometry column "sticky" in its result regardless of the
  # select criteria, so without excluding it here, year_name/month_name/day_name
  # would each also include the geometry column name - and the rename() below
  # would then rename the geometry column itself, corrupting the sf object's
  # tracked geometry-column name.
  geom_col <- attr(speciesDat, "sf_column")
  year_name <- setdiff(names(speciesDat |> dplyr::select(dplyr::starts_with("year", ignore.case = TRUE))), geom_col)
  month_name <- setdiff(names(speciesDat |> dplyr::select(dplyr::starts_with("month", ignore.case = TRUE))), geom_col)
  day_name <- setdiff(names(speciesDat |> dplyr::select(dplyr::starts_with("day", ignore.case = TRUE))), geom_col)

  speciesDat <- speciesDat |>
    dplyr::rename(YEAR = dplyr::all_of(year_name),
                  MONTH = dplyr::all_of(month_name),
                  DAY = dplyr::all_of(day_name))

  start_year <- min(speciesDat$YEAR)
  start_month <- min(dplyr::filter(speciesDat, YEAR == start_year)$MONTH)
  start_day <- min(dplyr::filter(speciesDat, YEAR == start_year & MONTH == start_month)$DAY)

  for (year in unique(speciesDat$YEAR)) {
    year_dat <- dplyr::filter(speciesDat, YEAR == year)
    for (month in unique(year_dat$MONTH)) {
      month_dat <- dplyr::filter(year_dat, MONTH == month)
      for (day in sort(unique(month_dat$DAY))) {
        day_dat <- dplyr::filter(month_dat, DAY == day)
        envDat_filtered <- envDat |>
          dplyr::filter(YEAR == year, MONTH == month, DAY == day)

        cols_to_drop <- c("YEAR", "MONTH", "DAY")
        envDat_filtered <- envDat_filtered[, !(names(envDat_filtered) %in% cols_to_drop)] |>
          sf::st_transform(sf::st_crs(envDat))
        temp_data <- sf::st_join(day_dat, envDat_filtered, join = sf::st_nearest_feature) |>
          sf::st_transform(sf::st_crs(envDat))

        if (year == start_year & month == start_month & day == start_day) {
          matched_data <- temp_data
        } else {
          matched_data <- rbind(matched_data, temp_data)
        }
      }
    }
  }

  # reappend lat and lon coordinates
  matched_data$LON <- sf::st_coordinates(matched_data)[,1]
  matched_data$LAT <- sf::st_coordinates(matched_data)[,2]

  # return matched dataset
  return(matched_data)

}
