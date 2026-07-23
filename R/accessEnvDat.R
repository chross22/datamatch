
#' Access environmental data from Copernicus Marine Service
#'
#' @param product_id <char> product identification string from Copernicus Marine Data Store
#' @param dataset_id <char> dataset identification string from Copernicus Marine Data Store
#' @param vars <char> list of variables to access, can be found under data access tab on Copernicus Marine Data Store,
#'                    accepts variable abbreviations only
#' @param years <numeric> years of data to access
#' @param months <numeric> months of data to access
#' @param bounding_box <list> named list of spatial coordinates of bounding box
#' @param depth <numeric> depth range to access (in meters)
#' @param overwrite <logical> whether or not to overwrite the data if it exists locally
#' @return envDat <sf object> sf object containing requested environmental data from Copernicus Marine Service
accessEnvDat <- function(product_id, dataset_id, vars, years, months,
                         bounding_box, depth = c(0,1),
                         overwrite = FALSE) {

  first_month <- months[1]
  first_year <- years[1]

  for (year in years) {
    for (month in months) {

      # Check if the data are monthly or daily
      if (substr(dataset_id, nchar(dataset_id) - 2, nchar(dataset_id) - 2) == "D") {
        days = 1:lubridate::days_in_month(lubridate::ym(paste(year, month, sep = "-")))
      } else {
        days = 1
      }

      # Access data
      for (day in days) {
        time = lubridate::ymd(paste(year, month, day, sep = "-"))

        ofile = copernicus::copernicus_path("tmp", paste0(product_id, "_", dataset_id, "_", time, ".nc"))

        # Load existing data
        if (fs::file_exists(ofile) & !overwrite) {
          x = terra::rast(ofile)
          # Or download data
        } else {

          ok = copernicus::download_copernicus_cli_subset(dataset_id = dataset_id,
                                              vars = vars,
                                              depth = depth,
                                              bounding_box = bounding_box,
                                              time = time,
                                              ofile = ofile,
                                              extra = "--overwrite")

          # Read in .nc file as terra object (raster)
          x = terra::rast(ofile)
        }

        # Convert to data frame
        if (month == first_month & year == first_year & day == 1) {
          covars <- as.data.frame(x, xy = TRUE) |>
            dplyr::mutate(YEAR = year,
                          MONTH = month,
                          DAY = 1)
        } else {
          covars <- covars |>
            rbind(as.data.frame(x, xy = TRUE) |>
                    dplyr::mutate(YEAR = year,
                                  MONTH = month,
                                  DAY = day))
        }
      }
    }
  }

  # Define column names
  names(covars) <- c("x", "y", vars, "YEAR", "MONTH", "DAY")

  # Convert data to sf and return
  sf::st_as_sf(covars,
               coords = c("x", "y"),
               crs = sf::st_crs(4326))

}

