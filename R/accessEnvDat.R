
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
#' @param n_workers <integer> number of days to download/read in parallel, using a PSOCK
#'                            cluster (parallel::makeCluster()). Defaults to 1 (serial, same
#'                            behavior as before this argument existed). Deliberately NOT
#'                            fork-based (parallel::mclapply()): GDAL, which terra/sf use
#'                            internally, is not fork-safe, and forking after GDAL has
#'                            initialized can corrupt state in the child processes. PSOCK
#'                            workers are fresh R sessions instead, which avoids that.
#'                            Downloads hit the Copernicus Marine API, so keep this modest
#'                            (4-8) rather than maxing out cores - the bottleneck is the
#'                            network/API, not CPU.
#' @return envDat <sf object> sf object containing requested environmental data from Copernicus Marine Service
#' @export
accessEnvDat <- function(product_id, dataset_id, vars, years, months,
                         bounding_box, depth = c(0,1),
                         overwrite = FALSE, n_workers = 1) {

  # Build the full list of (year, month, day) combinations to fetch up front,
  # so they can be dispatched in parallel instead of three nested serial loops.
  is_daily <- substr(dataset_id, nchar(dataset_id) - 2, nchar(dataset_id) - 2) == "D"
  work_items <- list()
  for (year in years) {
    for (month in months) {
      days <- if (is_daily) 1:lubridate::days_in_month(lubridate::ym(paste(year, month, sep = "-"))) else 1
      for (day in days) {
        work_items[[length(work_items) + 1]] <- list(year = year, month = month, day = day)
      }
    }
  }

  fetch_one_day <- function(item, product_id, dataset_id, vars, bounding_box, depth, overwrite) {
    time = lubridate::ymd(paste(item$year, item$month, item$day, sep = "-"))

    ofile = copernicus::copernicus_path("tmp", paste0(product_id, "_", dataset_id, "_", time, ".nc"))

    # Load existing data
    if (fs::file_exists(ofile) & !overwrite) {
      x = terra::rast(ofile)
      # Or download data
    } else {

      ok = copernicus::download_copernicus_cli_subset(dataset_id = dataset_id,
                                          vars = vars,
                                          depth = depth,
                                          bb = bounding_box,
                                          time = time,
                                          ofile = ofile,
                                          extra = "--overwrite")

      # Read in .nc file as terra object (raster)
      x = terra::rast(ofile)
    }

    # Convert to data frame
    as.data.frame(x, xy = TRUE) |>
      dplyr::mutate(YEAR = item$year, MONTH = item$month, DAY = item$day)
  }

  if (n_workers > 1) {
    cl <- parallel::makeCluster(n_workers)
    on.exit(parallel::stopCluster(cl), add = TRUE)
    parallel::clusterEvalQ(cl, {
      library(terra); library(copernicus); library(fs); library(dplyr); library(lubridate)
    })
    results <- tryCatch(
      parallel::parLapply(cl, work_items, fetch_one_day,
                           product_id = product_id, dataset_id = dataset_id, vars = vars,
                           bounding_box = bounding_box, depth = depth, overwrite = overwrite),
      error = function(e) stop("accessEnvDat: parallel fetch failed - ", conditionMessage(e), call. = FALSE)
    )
  } else {
    results <- lapply(work_items, fetch_one_day,
                       product_id = product_id, dataset_id = dataset_id, vars = vars,
                       bounding_box = bounding_box, depth = depth, overwrite = overwrite)
  }

  covars <- dplyr::bind_rows(results)

  # Define column names
  names(covars) <- c("x", "y", vars, "YEAR", "MONTH", "DAY")

  # Convert data to sf and return
  sf::st_as_sf(covars,
               coords = c("x", "y"),
               crs = sf::st_crs(4326))

}
