
#' Put a downloaded raster's layers into the order they were requested
#'
#' Copernicus returns layers in the NetCDF's own order, which is alphabetical by
#' variable code and has nothing to do with the order they were asked for. Column
#' names are assigned from `vars`, so the two have to be reconciled before naming
#' or the names land on the wrong layers.
#'
#' That failure is silent and severe: requesting `c("SST", "SSS")` sends
#' `c("thetao", "so")`, gets back `so` then `thetao`, and would label salinity as
#' temperature and temperature as salinity with nothing to indicate it. Matching
#' by name rather than position is the whole point of this function.
#'
#' @section Layer names:
#' Three-dimensional variables come back as `thetao_depth=0.494025`, so the depth
#' suffix is stripped before matching. Two-dimensional ones such as `mlotst` and
#' `zos` carry no suffix.
#'
#' A code appearing on more than one layer means the depth range spanned several
#' model levels. That is reported as such, rather than left to be caught later by
#' a column count that cannot say which variable caused it.
#'
#' @param x a `SpatRaster` read from a Copernicus download
#' @param vars <char> variable codes, in the order they were requested
#' @return `x`, with one layer per requested code, in that order
#' @keywords internal
order_layers <- function(x, vars) {
  codes <- sub("_depth=.*$", "", names(x))

  missing <- setdiff(vars, codes)
  if (length(missing) > 0) {
    stop("The download did not return: ", paste(missing, collapse = ", "),
         "\nIt contains: ", paste(unique(codes), collapse = ", "),
         "\nThat variable may not exist in this dataset, or may not be served ",
         "at the requested depth or date.", call. = FALSE)
  }

  repeated <- vars[vapply(vars, function(v) sum(codes == v) > 1, logical(1))]
  if (length(repeated) > 0) {
    depths <- unique(sub("^.*_depth=", "", grep("_depth=", names(x), value = TRUE)))
    stop("The depth range returned several model levels for: ",
         paste(repeated, collapse = ", "),
         "\nLevels returned: ", paste(depths, collapse = ", "),
         "\nRequest a single level, e.g. depth = c(0, 1).", call. = FALSE)
  }

  x[[match(vars, codes)]]
}

#' Access environmental data from Copernicus Marine Service
#'
#' Downloads a Copernicus dataset over a bounding box and time range, and returns
#' it as an `sf` point object with one row per grid cell and time step.
#'
#' @section Requesting variables by name:
#' `vars` accepts the short names in [variable_dictionary()] — `"SST"`, `"CHL"`,
#' `"MLD"` — as well as raw Copernicus codes. Copernicus codes are terse and easy
#' to misremember (`thetao` for temperature, `mlotst` for mixed layer depth,
#' `zos` for sea surface height), and getting one wrong produces a failed
#' download rather than an obvious mistake.
#'
#' Names carry through to the result, so a request for `"SST"` returns a column
#' called `SST` rather than `thetao`.
#'
#' Because the catalog knows which product and dataset holds each variable,
#' **`product_id` and `dataset_id` can be omitted** when every requested variable
#' is in it:
#'
#' ```
#' accessEnvDat(
#'   vars = c("SST", "SSS", "MLD"),
#'   years = 2003:2017, months = 1:12,
#'   bounding_box = list(xmin = -76, xmax = -65, ymin = 35, ymax = 45)
#' )
#' ```
#'
#' Variables from different datasets cannot be fetched in one request, and mixing
#' them is refused before anything is downloaded rather than failing obscurely at
#' the API. Anything outside the catalog is passed through as a code, with a
#' warning — Copernicus serves far more than the catalog covers, but a typo looks
#' identical to a real code.
#'
#' @param product_id <char> product identification string from the Copernicus
#'   Marine Data Store. Optional when `vars` are catalog names.
#' @param dataset_id <char> dataset identification string from the Copernicus
#'   Marine Data Store. Optional when `vars` are catalog names.
#' @param vars <char> variables to access: names from [variable_dictionary()],
#'   raw Copernicus variable codes, or a mixture
#' @param years <numeric> years of data to access
#' @param months <numeric> months of data to access
#' @param bounding_box <list> named list of spatial coordinates of bounding box
#' @param depth <numeric> depth range to access (in meters)
#' @param overwrite <logical> whether or not to overwrite the data if it exists locally
#' @param mode <char> `"reanalysis"` (the default) for the multi-year hindcast,
#'   or `"forecast"` for the analysis-and-forecast products, which run to about
#'   ten days ahead. See [forecast_variables()] for which variables have a
#'   forecast equivalent and how the identifiers differ.
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
accessEnvDat <- function(product_id = NULL, dataset_id = NULL, vars, years, months,
                         bounding_box, depth = c(0,1),
                         overwrite = FALSE, n_workers = 1,
                         mode = c("reanalysis", "forecast")) {
  mode <- match.arg(mode)

  # `vars` may be catalog names ("SST") or raw Copernicus codes ("thetao").
  # Codes go to the API; names come back as the column names, so a caller who
  # asked for SST gets a column called SST rather than thetao.
  resolved <- resolve_variables(vars, mode = mode)
  var_codes <- resolved$codes
  var_names <- resolved$names

  # With every variable in the catalog, the product and dataset are implied and
  # need not be repeated at the call site.
  if (is.null(product_id) || is.null(dataset_id)) {
    inferred <- infer_dataset(vars, mode = mode)
    product_id <- product_id %||% inferred$product_id
    dataset_id <- dataset_id %||% inferred$dataset_id
  }

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

    ofile = copernicus_cache("tmp", paste0(product_id, "_", dataset_id, "_", time, ".nc"))

    # Load existing data
    if (fs::file_exists(ofile) & !overwrite) {
      x = terra::rast(ofile)
      # Or download data
    } else {

      download_copernicus_subset(dataset_id = dataset_id,
                                 vars = vars,
                                 depth = depth,
                                 bb = bounding_box,
                                 time = time,
                                 ofile = ofile)

      # Read in .nc file as terra object (raster)
      x = terra::rast(ofile)
    }

    # Put the layers in the order they were requested before anything is named.
    x <- order_layers(x, vars)

    # Convert to data frame
    as.data.frame(x, xy = TRUE) |>
      dplyr::mutate(YEAR = item$year, MONTH = item$month, DAY = item$day)
  }

  if (n_workers > 1) {
    cl <- parallel::makeCluster(n_workers)
    on.exit(parallel::stopCluster(cl), add = TRUE)
    # datamatch itself has to be loaded in the workers: fetch_one_day is a closure
    # whose enclosing environment is this package's namespace, and it resolves
    # copernicus_cache() and download_copernicus_subset() through it.
    parallel::clusterEvalQ(cl, {
      library(terra); library(datamatch); library(fs); library(dplyr); library(lubridate)
    })
    results <- tryCatch(
      parallel::parLapply(cl, work_items, fetch_one_day,
                           product_id = product_id, dataset_id = dataset_id, vars = var_codes,
                           bounding_box = bounding_box, depth = depth, overwrite = overwrite),
      error = function(e) stop("accessEnvDat: parallel fetch failed - ", conditionMessage(e), call. = FALSE)
    )
  } else {
    results <- lapply(work_items, fetch_one_day,
                       product_id = product_id, dataset_id = dataset_id, vars = var_codes,
                       bounding_box = bounding_box, depth = depth, overwrite = overwrite)
  }

  covars <- dplyr::bind_rows(results)

  # Names are assigned positionally, so the raster must have exactly one layer
  # per requested variable. A depth range spanning several model levels returns
  # more, and silently mislabelling those columns would be worse than stopping.
  expected <- length(var_names) + 5  # x, y, vars..., YEAR, MONTH, DAY
  if (ncol(covars) != expected) {
    stop("Expected ", length(var_names), " variable column(s) but the download ",
         "returned ", ncol(covars) - 5, ". This usually means the depth range ",
         "spans several model levels; request a single level, or one variable ",
         "at a time.", call. = FALSE)
  }

  # Columns take the names the caller asked for, so requesting "SST" yields a
  # column called SST rather than thetao.
  names(covars) <- c("x", "y", var_names, "YEAR", "MONTH", "DAY")

  # Convert data to sf and return
  sf::st_as_sf(covars,
               coords = c("x", "y"),
               crs = sf::st_crs(4326))

}
