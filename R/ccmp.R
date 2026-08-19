#' Catalog of CCMP wind variables
#'
#' CCMP is the Cross-Calibrated Multi-Platform ocean surface wind analysis from
#' Remote Sensing Systems: scatterometer and radiometer retrievals combined with
#' a model background onto a uniform grid. Names match the Copernicus wind
#' catalog where the quantity is the same, so a covariate lands in a column of
#' the same name whichever source supplied it.
#'
#' @section What it does not carry:
#' **There is no wind stress.** CCMP publishes winds only, where the Copernicus
#' L4 product also carries `TAUX`, `TAUY` and `TAU`. Stress is what actually
#' enters the ocean and is roughly quadratic in speed, so it cannot be recovered
#' from these by rescaling — computing it means choosing a drag coefficient,
#' which is a modelling decision this package does not make for you.
#'
#' @section NOBS is diagnostic, not a covariate:
#' `NOBS` counts the satellite retrievals behind each cell and hour. Zero means
#' the value there is the model background alone rather than an observation —
#' which is worth knowing before treating CCMP as observed data in a region or
#' period with poor coverage.
#'
#' @return a named list, one entry per variable, each with `variable`, `label`,
#'   `units`, and `description`
#' @examples
#' names(ccmp_variables())
#' @seealso [accessCCMP()], [ccmp_versions()]
#' @export
ccmp_variables <- function() {
  entry <- function(variable, label, units, description) {
    list(variable = variable, label = label, units = units,
         description = description)
  }

  list(
    WSPD = entry("ws", "Wind speed", "m/s",
                 paste("Scalar wind speed at 10 m. Analysed as a speed in its",
                       "own right rather than derived from the components, so",
                       "it is not exactly the magnitude of UWND and VWND.")),
    UWND = entry("uwnd", "Eastward wind", "m/s",
                 "Eastward component of wind velocity at 10 m."),
    VWND = entry("vwnd", "Northward wind", "m/s",
                 "Northward component of wind velocity at 10 m."),
    NOBS = entry("nobs", "Satellite observations", "count",
                 paste("Number of satellite retrievals contributing to the",
                       "cell. Zero means the value is the model background",
                       "alone, not an observation."))
  )
}

#' CCMP versions this package can read
#'
#' Remote Sensing Systems publishes CCMP as a plain directory tree over HTTPS,
#' one file per day. No account is needed for it: the registration RSS asks for
#' covers their FTP service, and the HTTPS archive is open.
#'
#' @return a named list, one entry per version, each with `root`, `pattern`,
#'   `step_hours`, `start`, `resolution`, and `reference`
#' @examples
#' names(ccmp_versions())
#' ccmp_versions()$v03.1$step_hours
#' @seealso [accessCCMP()]
#' @export
ccmp_versions <- function() {
  list(
    `v03.1` = list(
      root = "https://data.remss.com/ccmp/v03.1",
      # Year, month and the date, in the order sprintf() will be given them.
      pattern = "Y%04d/M%02d/CCMP_Wind_Analysis_%04d%02d%02d_V03.1_L4.nc",
      step_hours = 6L,
      start = as.Date("1993-01-01"),
      resolution = "0.25 degrees",
      label = "CCMP v3.1 six-hourly ocean surface wind analysis",
      reference = paste(
        "Mears C, Lee T, Ricciardulli L, Wang X, Wentz F (2022).",
        "Improving the Accuracy of the Cross-Calibrated Multi-Platform",
        "(CCMP) Ocean Vector Winds. Remote Sensing 14(17):4230.",
        "doi:10.3390/rs14174230"
      )
    )
  )
}

#' Convert a longitude to the 0-360 convention CCMP uses
#'
#' CCMP is the one source in this package on a 0-360 grid; Copernicus, HYCOM and
#' FVCOM all run -180 to 180. A Northwest Atlantic box asked for as -70 to -66
#' would select nothing here, or — worse, if it were clamped rather than
#' rejected — a stretch of the Indian Ocean.
#'
#' So the box is converted on the way in and the coordinates converted back on
#' the way out, and what a caller passes and receives is negative west
#' throughout, as with every other source.
#'
#' @param x <numeric> longitudes in either convention
#' @return <numeric> the same longitudes in 0-360
#' @keywords internal
to_360 <- function(x) (x %% 360)

#' Convert a longitude back to the -180 to 180 convention
#'
#' @param x <numeric> longitudes in 0-360
#' @return <numeric> the same longitudes, negative west
#' @keywords internal
to_180 <- function(x) ((x + 180) %% 360) - 180

#' Download one day's CCMP file into the cache
#'
#' @section Why the whole globe is downloaded:
#' RSS serves CCMP as static files over HTTPS, with no OPeNDAP endpoint and no
#' server-side subsetting. There is no way to ask for a region: a day is one
#' 33 MB global file whether one cell of it is wanted or the whole grid. The
#' subset is extracted locally and cached, and the global file is discarded.
#'
#' That makes CCMP much heavier per day than any other source here, and a long
#' record genuinely expensive — a year is roughly 12 GB of transfer to keep a
#' few megabytes. [accessCCMP()] says so before starting a large request.
#'
#' @param spec one entry of [ccmp_versions()]
#' @param day <Date> the day to fetch
#' @param destination <char> where to write the file
#' @return `NULL` on success, or a one-line description of the failure
#' @keywords internal
download_ccmp_day <- function(spec, day, destination) {
  url <- file.path(spec$root, sprintf(
    spec$pattern,
    as.integer(format(day, "%Y")), as.integer(format(day, "%m")),
    as.integer(format(day, "%Y")), as.integer(format(day, "%m")),
    as.integer(format(day, "%d"))))

  status <- tryCatch(
    utils::download.file(url, destination, mode = "wb", quiet = TRUE),
    error = function(e) conditionMessage(e),
    warning = function(w) conditionMessage(w))

  if (!identical(status, 0L) || !file.exists(destination)) {
    if (file.exists(destination)) unlink(destination)
    return(paste0("  ", format(day), ": ",
                  if (is.character(status)) status else "download failed"))
  }
  NULL
}

#' Access CCMP ocean surface winds
#'
#' Downloads the CCMP wind analysis from Remote Sensing Systems and returns it
#' as an `sf` point object with one row per grid cell and time step — the same
#' shape [accessCopernicus()], [accessFVCOM()], [accessHYCOM()] and [accessERDDAP()]
#' return, so
#' [matchData()] joins it unchanged.
#'
#' @section Why reach for it, and why not:
#' CCMP is the longest consistent surface wind record available here. It runs
#' from **January 1993 to within days of the present**, six-hourly throughout,
#' which is both longer and finer in time than the Copernicus L4 wind — that is
#' monthly from mid-1994, or hourly only from 2007, with nothing daily in
#' between.
#'
#' Against that: **CCMP carries no wind stress.** The Copernicus product does,
#' and stress rather than speed is what drives mixing and Ekman pumping. Stress
#' cannot be recovered from these winds without choosing a drag coefficient,
#' which is a modelling decision rather than a unit conversion. Where stress is
#' the covariate you want, use the Copernicus wind.
#'
#' The two are different analyses of the same quantity, so a wind from CCMP is
#' **not interchangeable** with one from Copernicus even though both arrive in a
#' `UWND` column. Say which you used.
#'
#' @section It downloads the whole globe:
#' RSS publishes CCMP as static files with no OPeNDAP endpoint, so there is no
#' way to ask for a region. **A day is one 33 MB global file** however small the
#' bounding box, and the subset is taken locally. A year is therefore about
#' 12 GB of transfer to keep a few megabytes of it.
#'
#' The extracted subset is cached, so this is paid once per day of data. A
#' request for more than 30 days says what it is about to download before
#' starting.
#'
#' @section Six-hourly, and no mean to fetch:
#' CCMP is an analysis at 00, 06, 12 and 18 UTC. There is no daily or monthly
#' mean in the archive, so none is invented:
#'
#' \itemize{
#'   \item `frequency = "daily"` (the default) takes one **snapshot**, at `hour`.
#'   \item `frequency = "6hourly"` returns all four steps, with an `HOUR` column.
#' }
#'
#' A real mean is [upscale_time()]'s job, which keeps it visible:
#'
#' ```
#' steps <- accessCCMP(vars = c("UWND", "VWND"), frequency = "6hourly",
#'                     dates = "2010-06-15", bounding_box = bb)
#' daily <- upscale_time(steps, to = "day")
#' ```
#'
#' Note that a mean of `UWND` and `VWND` is not a mean `WSPD`. Averaging the
#' components and taking the magnitude gives the net displacement of air;
#' averaging the speed gives how hard it blew. On a day the wind reversed, the
#' first is near zero and the second is not.
#'
#' @section Longitude convention:
#' CCMP is stored on a 0-360 grid, alone among the sources here. `bounding_box`
#' is given negative west as everywhere else in this package, converted on the
#' way in, and the returned coordinates are negative west too — so the result
#' overlays the other sources without adjustment.
#'
#' @param vars <char> variables to read, from [ccmp_variables()]
#' @param years <numeric> years to read. Required unless `dates` is given.
#' @param months <numeric> months to read. Required unless `dates` is given.
#' @param bounding_box <list> named list with `xmin`, `xmax`, `ymin`, `ymax`, or
#'   an `sf`/`sfc` object. Longitudes negative west.
#' @param dates the exact dates to read, as `YYYYMMDD` strings, `YYYY-MM-DD`
#'   strings, or `Date` objects
#' @param frequency <char> `"daily"` (the default) for one snapshot per day, or
#'   `"6hourly"` for all four steps. Neither is a mean.
#' @param hour <integer> which UTC hour to take when `frequency = "daily"`.
#'   Must be 0, 6, 12 or 18.
#' @param version <char> which CCMP version to read, from [ccmp_versions()]
#' @param overwrite <logical> re-read days already cached
#' @return <sf object> one row per grid cell per time step, with `YEAR`,
#'   `MONTH`, `DAY`, an `HOUR` column when `frequency = "6hourly"`, and a column
#'   per requested variable
#' @examples
#' \dontrun{
#' bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
#'
#' wind <- accessCCMP(vars = c("UWND", "VWND", "WSPD"),
#'                    dates = unique(observations$date), bounding_box = bb)
#'
#' matched <- matchData(observations, wind)
#' }
#' @seealso [ccmp_variables()], [accessCopernicus()] for the Copernicus wind, which
#'   carries stress
#' @export
accessCCMP <- function(vars, years = NULL, months = NULL, bounding_box,
                       dates = NULL, frequency = c("daily", "6hourly"),
                       hour = 12L, version = "v03.1", overwrite = FALSE) {
  frequency <- match.arg(frequency)

  versions <- ccmp_versions()
  if (!version %in% names(versions)) {
    stop("Unknown CCMP version '", version, "'. Available: ",
         paste(names(versions), collapse = ", "), call. = FALSE)
  }
  spec <- versions[[version]]

  if (!requireNamespace("ncdf4", quietly = TRUE)) {
    stop("Reading CCMP needs the ncdf4 package, which datamatch suggests ",
         "rather than requires.\nInstall it with:  install.packages(\"ncdf4\")",
         call. = FALSE)
  }

  catalog <- ccmp_variables()
  unknown <- setdiff(vars, names(catalog))
  if (length(unknown) > 0) {
    stop("Not CCMP variables: ", paste(unknown, collapse = ", "),
         "\nAvailable: ", paste(names(catalog), collapse = ", "),
         if (any(unknown %in% c("TAUX", "TAUY", "TAU"))) {
           paste0("\nCCMP carries no wind stress. It cannot be derived from ",
                  "these winds without\nchoosing a drag coefficient. Use the ",
                  "Copernicus wind for stress: see accessCopernicus().")
         }, call. = FALSE)
  }
  entries <- catalog[vars]

  if (frequency == "daily" && !hour %in% seq(0, 23, by = spec$step_hours)) {
    stop("`hour` must be one of ",
         paste(seq(0, 23, by = spec$step_hours), collapse = ", "),
         ", since CCMP is analysed at those hours.\nGiven: ", hour,
         call. = FALSE)
  }

  if (!is.null(dates)) {
    if (!is.null(years) || !is.null(months)) {
      stop("`dates` already names which days to read, so `years` and `months` ",
           "are not used with it.", call. = FALSE)
    }
    days <- parse_dates(dates)
  } else {
    if (is.null(years) || is.null(months)) {
      stop("`years` and `months` are required, unless `dates` names the days ",
           "to read.", call. = FALSE)
    }
    days <- do.call(c, lapply(years, function(y) {
      do.call(c, lapply(months, function(m) {
        start <- lubridate::ymd(paste(y, m, 1, sep = "-"))
        seq(start, by = "day", length.out = lubridate::days_in_month(start))
      }))
    }))
    days <- sort(unique(days))
  }

  before_record <- days < spec$start
  if (all(before_record)) {
    stop("CCMP ", version, " begins ", format(spec$start),
         ", and every requested day is before it.", call. = FALSE)
  }
  if (any(before_record)) {
    warning(sum(before_record), " day(s) before the start of CCMP ", version,
            " (", format(spec$start), ") are skipped.", call. = FALSE)
    days <- days[!before_record]
  }

  if (inherits(bounding_box, c("sf", "sfc"))) {
    bounding_box <- sf::st_bbox(bounding_box)
  }
  missing_edges <- setdiff(c("xmin", "xmax", "ymin", "ymax"),
                           names(bounding_box))
  if (length(missing_edges) > 0) {
    stop("bounding_box is missing: ", paste(missing_edges, collapse = ", "),
         call. = FALSE)
  }

  key <- short_hash(paste(
    paste(sort(vars), collapse = ","),
    paste(round(unlist(bounding_box[c("xmin", "xmax", "ymin", "ymax")]), 6),
          collapse = ","),
    frequency, if (frequency == "daily") hour else "all", sep = "|"))

  paths <- vapply(days, function(day) {
    copernicus_cache("ccmp", paste0(version, "_", format(day, "%Y%m%d"), "_",
                                    key, ".rds"))
  }, character(1))

  needed <- if (overwrite) rep(TRUE, length(days)) else !file.exists(paths)

  # Every day is a whole global file, so a long request is a lot of transfer for
  # a small box. Said before it starts rather than discovered from the network
  # light, since nothing in the call hints at the cost.
  if (sum(needed) > 30) {
    message("CCMP has no server-side subsetting, so each day is a 33 MB global ",
            "file.\nThis request needs ", sum(needed), " of them, about ",
            round(sum(needed) * 33 / 1024, 1), " GB of transfer, to keep the ",
            "bounding box from each.\nThe subsets are cached, so this is paid ",
            "once.")
  }

  failures <- character()
  for (i in which(needed)) {
    raw <- copernicus_cache("ccmp", paste0("raw_", format(days[i], "%Y%m%d"),
                                           ".nc"))
    failure <- download_ccmp_day(spec, days[i], raw)
    if (!is.null(failure)) {
      failures <- c(failures, failure)
      next
    }
    # The global file is a working file, not a cache entry: it is 33 MB against
    # a subset of a few hundred kilobytes, and keeping every one would fill a
    # disk to save a download nobody repeats.
    on.exit(unlink(raw), add = TRUE)

    handle <- ncdf4::nc_open(raw)
    lon <- as.numeric(ncdf4::ncvar_get(handle, "longitude"))
    lat <- as.numeric(ncdf4::ncvar_get(handle, "latitude"))

    # CCMP is 0-360 and the caller is negative west, so the box is converted
    # rather than compared across conventions.
    wanted_lon <- to_360(c(bounding_box[["xmin"]], bounding_box[["xmax"]]))
    keep_lon <- if (wanted_lon[1] <= wanted_lon[2]) {
      which(lon >= wanted_lon[1] & lon <= wanted_lon[2])
    } else {
      # A box straddling the prime meridian wraps in this convention.
      which(lon >= wanted_lon[1] | lon <= wanted_lon[2])
    }
    keep_lat <- which(lat >= bounding_box[["ymin"]] &
                      lat <= bounding_box[["ymax"]])

    if (length(keep_lon) == 0 || length(keep_lat) == 0) {
      ncdf4::nc_close(handle)
      stop("The bounding box selects no CCMP cells. Longitudes are given ",
           "negative west here and\nconverted internally, so check the box ",
           "rather than its convention.", call. = FALSE)
    }

    times <- ncdf4::ncvar_get(handle, "time")
    epoch <- as.POSIXct(substr(trimws(sub(
      "^.*since\\s+", "", ncdf4::ncatt_get(handle, "time", "units")$value)),
      1, 19), tz = "UTC")
    stamps <- as.integer(format(epoch + times * 3600, "%H", tz = "UTC"))

    steps <- if (frequency == "daily") which(stamps == hour) else seq_along(stamps)

    frames <- lapply(steps, function(step) {
      frame <- expand.grid(x = to_180(lon[keep_lon]), y = lat[keep_lat])
      for (name in vars) {
        values <- ncdf4::ncvar_get(
          handle, entries[[name]]$variable,
          start = c(min(keep_lon), min(keep_lat), step),
          count = c(length(keep_lon), length(keep_lat), 1),
          collapse_degen = TRUE)
        frame[[name]] <- as.numeric(values)
      }
      frame$YEAR <- as.integer(format(days[i], "%Y"))
      frame$MONTH <- as.integer(format(days[i], "%m"))
      frame$DAY <- as.integer(format(days[i], "%d"))
      if (frequency == "6hourly") frame$HOUR <- stamps[step]
      frame
    })

    ncdf4::nc_close(handle)
    unlink(raw)

    if (length(frames) == 0) next
    frame <- dplyr::bind_rows(frames)
    # Land, where CCMP has no wind at all.
    frame <- frame[rowSums(!is.na(frame[vars])) > 0, , drop = FALSE]
    rownames(frame) <- NULL
    saveRDS(frame, paths[i])
  }

  if (length(failures) > 0) {
    warning(length(failures), " day(s) could not be downloaded:\n",
            paste(utils::head(failures, 5), collapse = "\n"),
            if (length(failures) > 5) "\n  ..." else "",
            "\nThe days that did succeed are cached, so re-running retries ",
            "only the failures.", call. = FALSE)
  }

  usable <- file.exists(paths)
  if (!any(usable)) {
    stop("No CCMP data could be read for the requested days.", call. = FALSE)
  }

  out <- sf::st_as_sf(dplyr::bind_rows(lapply(paths[usable], readRDS)),
                      coords = c("x", "y"), crs = sf::st_crs(4326))
  attr(out, "datamatch_step") <- if (frequency == "6hourly") "hour" else "day"
  stamp_source(out, "ccmp", version)
}

#' Printable dictionary of CCMP variables
#'
#' @return a data frame of class `datamatch_dictionary`
#' @examples
#' ccmp_dictionary()
#' @seealso [ccmp_variables()]
#' @export
ccmp_dictionary <- function() {
  catalog <- ccmp_variables()

  dictionary <- do.call(rbind, lapply(names(catalog), function(name) {
    entry <- catalog[[name]]
    data.frame(name = name, variable = entry$variable, label = entry$label,
               units = entry$units, source = "CCMP", layer = NA_character_,
               description = entry$description, stringsAsFactors = FALSE)
  }))

  class(dictionary) <- c("datamatch_dictionary", "data.frame")
  dictionary
}
