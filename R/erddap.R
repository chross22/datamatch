#' Satellite datasets read through ERDDAP
#'
#' ERDDAP is NOAA's data server, and several satellite products this package
#' wants are on one. It matters here for a practical reason: the same products
#' at PO.DAAC need an Earthdata login, and ERDDAP serves them with **no account
#' at all**, subsetting server-side by longitude, latitude and time.
#'
#' @section What is built in, and what is not:
#' Three datasets ship. They are the ones that are global, current, and relevant
#' to a shelf study:
#'
#' \tabular{lll}{
#'   `MUR`          \tab SST, 0.01 deg daily  \tab 2002-06 onward \cr
#'   `VIIRSCHL`     \tab chlorophyll, daily   \tab 2020-05 onward \cr
#'   `VIIRSCHL2018` \tab chlorophyll, daily   \tab 2012-01 to 2022-07
#' }
#'
#' **There is no global VIIRS SST here.** The VIIRS SST dataset on these servers
#' covers the US West Coast only (-128 to -115 E), which is no use on the
#' Atlantic shelf, and nothing global turned up in its place. MUR is the SST to
#' use instead — it is a blended analysis that takes VIIRS among its inputs, so
#' it carries the same sensor's information at higher resolution and over a much
#' longer record.
#'
#' The two chlorophyll entries are the same instrument processed twice.
#' `VIIRSCHL2018` is the 2018 reprocessing, which stops in July 2022;
#' `VIIRSCHL` is the current gap-filled product, which starts in May 2020. They
#' overlap for two years and are not the same numbers, so a series spanning both
#' has a seam in it.
#'
#' @section MUR is not a model SST:
#' `MUR` is a satellite analysis of the *foundation* temperature — the
#' temperature below the daily warming layer — where a model `SST` is the
#' topmost model level. On a calm sunny afternoon those differ by a degree or
#' more. Both arrive in a column called `SST`, and [source_of()] is what
#' distinguishes them.
#'
#' @return a named list, one entry per dataset, each with `server`,
#'   `dataset_id`, `variables`, `has_altitude`, `start`, `end`, `resolution`,
#'   `label` and `reference`
#' @examples
#' names(erddap_datasets())
#' erddap_datasets()$MUR$dataset_id
#' @seealso [accessERDDAP()], [erddap_dataset()] for any other ERDDAP dataset
#' @export
erddap_datasets <- function() {
  list(
    MUR = list(
      server = "https://coastwatch.pfeg.noaa.gov/erddap",
      dataset_id = "jplMURSST41",
      # Catalog name to ERDDAP variable. SST keeps the shared name so a MUR
      # fetch drops into an existing pipeline unchanged.
      variables = c(SST = "analysed_sst", SST_ERROR = "analysis_error",
                    ICE = "sea_ice_fraction"),
      units = c(SST = "degrees C", SST_ERROR = "degrees C", ICE = "fraction"),
      has_altitude = FALSE,
      start = as.Date("2002-06-01"),
      end = NA,
      frequency = "daily",
      resolution = "0.01 degrees",
      label = "MUR: Multi-scale Ultra-high Resolution SST analysis (GHRSST L4)",
      reference = paste(
        "Chin TM, Vazquez-Cuervo J, Armstrong EM (2017). A multi-scale",
        "high-resolution analysis of global sea surface temperature.",
        "Remote Sensing of Environment 200:154-169.",
        "doi:10.1016/j.rse.2017.07.029")
    ),

    VIIRSCHL = list(
      server = "https://coastwatch.noaa.gov/erddap",
      dataset_id = "noaacwNPPN20VIIRSDINEOFDaily",
      variables = c(CHL = "chlor_a"),
      units = c(CHL = "mg/m3"),
      # This one carries a singleton altitude axis between time and latitude,
      # which the request has to account for or the slice comes back empty.
      has_altitude = TRUE,
      start = as.Date("2020-05-01"),
      end = NA,
      frequency = "daily",
      resolution = "0.0417 degrees",
      label = "VIIRS NPP/N20 chlorophyll, DINEOF gap-filled, daily",
      reference = paste(
        "Liu X, Wang M (2018). Gap filling of missing data for VIIRS global",
        "ocean color products using the DINEOF method.",
        "IEEE Transactions on Geoscience and Remote Sensing 56:4464-4476.",
        "doi:10.1109/TGRS.2018.2820423")
    ),

    VIIRSCHL2018 = list(
      server = "https://coastwatch.pfeg.noaa.gov/erddap",
      dataset_id = "erdVH2018chla1day",
      variables = c(CHL = "chla"),
      units = c(CHL = "mg/m3"),
      has_altitude = FALSE,
      start = as.Date("2012-01-02"),
      end = as.Date("2022-07-25"),
      frequency = "daily",
      resolution = "0.0417 degrees",
      label = "VIIRS SNPP chlorophyll, 2018 reprocessing, daily",
      reference = paste(
        "NOAA CoastWatch (2018). VIIRS SNPP Level-3 chlorophyll-a,",
        "2018 reprocessing. NOAA National Environmental Satellite,",
        "Data, and Information Service.")
    )
  )
}

#' Describe any ERDDAP griddap dataset, so it can be read like a built-in one
#'
#' ERDDAP servers host thousands of gridded datasets, and [erddap_datasets()]
#' ships three. This is how to reach any of the rest: give it a server and a
#' dataset id, and it reads the dataset's own metadata to work out the axes,
#' the variables and the period covered.
#'
#' @section What it checks:
#' The dataset's `.das` is fetched and parsed once, so a wrong id, an
#' unreachable server, or a dataset that is tabular rather than gridded fails
#' here — with the reason — rather than part-way through a fetch. Whether the
#' dataset carries a singleton `altitude` axis is detected rather than assumed,
#' because that changes the shape of every request.
#'
#' @param server <char> the ERDDAP base URL, e.g.
#'   `"https://coastwatch.pfeg.noaa.gov/erddap"`
#' @param dataset_id <char> the griddap dataset id
#' @param variables <char> named vector mapping the names you want to this
#'   dataset's variable names, as `c(SST = "analysed_sst")`. When `NULL`, every
#'   data variable is offered under its own name.
#' @param label <char> a human-readable name; defaults to the dataset id
#' @param reference <char> the citation for this product, if there is one
#' @return a list in the shape [erddap_datasets()] entries take, ready to pass
#'   to [accessERDDAP()] as `dataset`
#' @examples
#' \dontrun{
#' mine <- erddap_dataset("https://coastwatch.pfeg.noaa.gov/erddap",
#'                        "jplMURSST41", variables = c(SST = "analysed_sst"))
#' str(mine)
#' }
#' @seealso [accessERDDAP()], [erddap_datasets()]
#' @export
erddap_dataset <- function(server, dataset_id, variables = NULL, label = NULL,
                           reference = NA_character_) {
  server <- sub("/+$", "", server)
  das <- erddap_metadata(server, dataset_id)

  axes <- c("time", "latitude", "longitude", "altitude")
  found <- names(das)
  for (required in c("time", "latitude", "longitude")) {
    if (!required %in% found) {
      stop("This does not look like a griddap dataset: it has no '", required,
           "' axis.\n  ", server, "/griddap/", dataset_id,
           "\nTabular (tabledap) datasets are not read by this function.",
           call. = FALSE)
    }
  }

  data_variables <- setdiff(found, c(axes, "NC_GLOBAL"))
  if (is.null(variables)) {
    variables <- stats::setNames(data_variables, data_variables)
  } else {
    absent <- setdiff(unname(variables), data_variables)
    if (length(absent) > 0) {
      stop("This dataset does not carry: ", paste(absent, collapse = ", "),
           "\nIt has: ", paste(data_variables, collapse = ", "), call. = FALSE)
    }
  }

  span <- das$time$actual_range
  list(server = server, dataset_id = dataset_id, variables = variables,
       units = stats::setNames(
         vapply(variables, function(v) das[[v]]$units %||% NA_character_,
                character(1)), names(variables)),
       has_altitude = "altitude" %in% found,
       start = if (length(span) == 2) as.Date(as.POSIXct(span[1], origin = "1970-01-01", tz = "UTC")) else NA,
       end = if (length(span) == 2) as.Date(as.POSIXct(span[2], origin = "1970-01-01", tz = "UTC")) else NA,
       frequency = "unknown",
       resolution = NA_character_,
       label = label %||% dataset_id,
       reference = reference)
}

#' Read and parse an ERDDAP dataset's attribute document
#'
#' `.das` is a small text document rather than JSON, so it is parsed here rather
#' than by pulling in a dependency for one format. Only what this package needs
#' is extracted: which variables exist, their units, and the time range.
#'
#' @param server,dataset_id the ERDDAP server and dataset
#' @return a named list, one entry per variable, each with `units` and
#'   `actual_range` where present
#' @keywords internal
erddap_metadata <- function(server, dataset_id) {
  url <- paste0(server, "/griddap/", dataset_id, ".das")
  text <- tryCatch(readLines(url, warn = FALSE), error = function(e) e)
  if (inherits(text, "error")) {
    stop("Could not read the ERDDAP dataset description:\n  ", url, "\n",
         conditionMessage(text),
         "\nCheck the server URL and dataset id; ERDDAP returns 404 for an ",
         "unknown id.", call. = FALSE)
  }
  erddap_parse_das(text)
}

#' Parse the text of an ERDDAP `.das` document
#'
#' Kept separate from fetching it so the parsing can be tested without a server,
#' which is the half that breaks silently: a format change here would produce an
#' empty catalog rather than an error.
#'
#' @param text <char> the lines of a `.das` document
#' @return a named list, one entry per variable, each with `units` and
#'   `actual_range` where present
#' @keywords internal
erddap_parse_das <- function(text) {
  out <- list()
  current <- NULL
  for (line in text) {
    trimmed <- trimws(line)
    opened <- regmatches(trimmed, regexec("^([A-Za-z0-9_]+) \\{$", trimmed))[[1]]
    if (length(opened) == 2) {
      current <- opened[2]
      out[[current]] <- list()
      next
    }
    if (identical(trimmed, "}")) {
      current <- NULL
      next
    }
    if (is.null(current)) next

    units <- regmatches(trimmed, regexec('^String units "(.*)";$', trimmed))[[1]]
    if (length(units) == 2) out[[current]]$units <- units[2]

    span <- regmatches(
      trimmed, regexec("^Float(?:32|64) actual_range ([-0-9.e+]+), ([-0-9.e+]+);$",
                       trimmed))[[1]]
    if (length(span) == 3) {
      out[[current]]$actual_range <- as.numeric(span[2:3])
    }
  }
  out
}

#' Access satellite data through ERDDAP
#'
#' Downloads a subset of an ERDDAP gridded dataset and returns it as an `sf`
#' point object with one row per grid cell and time step — the same shape the
#' other access functions return, so [matchData()] joins it unchanged.
#'
#' @section Why this one needs no account:
#' MUR and the VIIRS products are also at PO.DAAC, where they need an Earthdata
#' login. ERDDAP serves them openly and subsets server-side, so a bounding box
#' costs a small download rather than a global file. That is the whole reason
#' this route was chosen: no credentials for this package to handle, and none
#' for you to configure.
#'
#' @section Satellite SST is not model SST:
#' `MUR` measures the **foundation** temperature — below the daily warming layer
#' — where a model's `SST` is its topmost level, and satellite chlorophyll is an
#' optical retrieval where a model's is a state variable. Both land in columns
#' called `SST` and `CHL`, which is what makes them drop into an existing
#' pipeline, and is exactly why [matchData()] records `<var>_source`.
#'
#' Two further cautions specific to satellites. **MUR is gap-free by
#' construction** — it is an analysis, so cloud is interpolated over rather than
#' left as `NA`, and `SST_ERROR` is where the uncertainty of that shows up; fetch
#' it alongside if the interpolation matters. And **`VIIRSCHL` is DINEOF
#' gap-filled**, so its holes are filled too; `VIIRSCHL2018` is the raw
#' retrieval and is gappy under cloud, which [fill_satellite_gaps()] is for.
#'
#' @param vars <char> variables to read, from the dataset's own catalog. `MUR`
#'   offers `SST`, `SST_ERROR` and `ICE`; the VIIRS entries offer `CHL`.
#' @param years <numeric> years to read. Required unless `dates` is given.
#' @param months <numeric> months to read. Required unless `dates` is given.
#' @param bounding_box <list> named list with `xmin`, `xmax`, `ymin`, `ymax`, or
#'   an `sf`/`sfc` object. Longitudes negative west, as elsewhere.
#' @param dates the exact dates to read, as `YYYYMMDD` strings, `YYYY-MM-DD`
#'   strings, or `Date` objects
#' @param dataset which dataset to read: a name from [erddap_datasets()], or a
#'   spec from [erddap_dataset()] describing any other
#' @param overwrite <logical> re-read days already cached
#' @return <sf object> one row per grid cell per day, with `YEAR`, `MONTH`,
#'   `DAY` and a column per requested variable
#' @examples
#' \dontrun{
#' bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
#'
#' # MUR SST at 0.01 degrees - far finer than any model here
#' sst <- accessERDDAP(vars = c("SST", "SST_ERROR"),
#'                     dates = unique(observations$date), bounding_box = bb)
#'
#' matched <- matchData(observations, sst)
#'
#' # VIIRS chlorophyll
#' chl <- accessERDDAP(vars = "CHL", years = 2022, months = 6,
#'                     bounding_box = bb, dataset = "VIIRSCHL")
#' }
#' @seealso [erddap_datasets()] for what ships, [erddap_dataset()] for anything
#'   else on an ERDDAP server
#' @export
accessERDDAP <- function(vars, years = NULL, months = NULL, bounding_box,
                         dates = NULL, dataset = "MUR", overwrite = FALSE) {
  if (is.list(dataset)) {
    spec <- dataset
    if (is.null(spec$server) || is.null(spec$dataset_id)) {
      stop("A dataset given as a list must carry `server` and `dataset_id`. ",
           "Build one with erddap_dataset().", call. = FALSE)
    }
    dataset_key <- spec$dataset_id
  } else {
    catalog <- erddap_datasets()
    if (!dataset %in% names(catalog)) {
      stop("Unknown ERDDAP dataset '", dataset, "'. Built in: ",
           paste(names(catalog), collapse = ", "),
           "\nERDDAP hosts thousands more; describe one with ",
           "erddap_dataset(server, dataset_id) and pass it here.",
           call. = FALSE)
    }
    spec <- catalog[[dataset]]
    dataset_key <- dataset
  }

  unknown <- setdiff(vars, names(spec$variables))
  if (length(unknown) > 0) {
    stop("Not variables of ", dataset_key, ": ", paste(unknown, collapse = ", "),
         "\nIt offers: ", paste(names(spec$variables), collapse = ", "),
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

  stop_if_future(days, paste("The ERDDAP dataset", spec$label %||% dataset))

  outside <- days < spec$start | (!is.na(spec$end) & days > spec$end)
  if (any(outside)) {
    span <- paste0(format(spec$start), " to ",
                   if (is.na(spec$end)) "the present" else format(spec$end))
    if (all(outside)) {
      stop(dataset_key, " covers ", span,
           ", and every requested day is outside it.", call. = FALSE)
    }
    warning(sum(outside), " day(s) outside ", dataset_key, " (", span,
            ") are skipped.", call. = FALSE)
    days <- days[!outside]
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
          collapse = ","), sep = "|"))
  paths <- vapply(days, function(day) {
    copernicus_cache("erddap", paste0(dataset_key, "_", format(day, "%Y%m%d"),
                                      "_", key, ".rds"))
  }, character(1))

  needed <- if (overwrite) rep(TRUE, length(days)) else !file.exists(paths)
  failures <- character()

  for (i in which(needed)) {
    frame <- tryCatch(
      erddap_read_day(spec, vars, days[i], bounding_box),
      error = function(e) e)
    if (inherits(frame, "error")) {
      failures <- c(failures, paste0("  ", format(days[i]), ": ",
                                     conditionMessage(frame)))
      next
    }
    if (is.null(frame) || nrow(frame) == 0) next
    saveRDS(frame, paths[i])
  }

  if (length(failures) > 0) {
    warning(length(failures), " day(s) could not be read:\n",
            paste(utils::head(failures, 5), collapse = "\n"),
            if (length(failures) > 5) "\n  ..." else "",
            "\nThe days that did succeed are cached, so re-running retries ",
            "only the failures.", call. = FALSE)
  }

  usable <- file.exists(paths)
  if (!any(usable)) {
    stop("No ", dataset_key, " data could be read for the requested days.",
         call. = FALSE)
  }

  out <- sf::st_as_sf(dplyr::bind_rows(lapply(paths[usable], readRDS)),
                      coords = c("x", "y"), crs = sf::st_crs(4326))
  attr(out, "datamatch_step") <- "day"
  stamp_source(out, "erddap", dataset_key)
}

#' Read one day of an ERDDAP dataset over a bounding box
#'
#' @section Why the returned times are filtered:
#' griddap wants a time that exists on the axis, and these products are stamped
#' at a nominal hour that differs between them — MUR at 09:00 UTC, others at
#' midnight. So a range covering the day is requested rather than an instant,
#' which avoids having to know the hour in advance.
#'
#' But **griddap snaps a range's endpoints to the nearest step rather than the
#' enclosing ones**, so asking for 00:00:00 to 23:59:59 on a MUR day returns
#' that day's 09:00 field *and the next day's*: 23:59:59 is nearer to tomorrow
#' at 09:00 than to today's. Taking what came back would have silently mixed two
#' days into one.
#'
#' The time axis of the returned file is therefore read and only the steps
#' actually falling on the requested day are kept. A day with no step of its own
#' yields nothing rather than borrowing its neighbour's.
#'
#' @param spec one entry of [erddap_datasets()]
#' @param vars <char> catalog names to read
#' @param day <Date> the day to read
#' @param bounding_box the box, negative west
#' @return a data frame of `x`, `y`, the variables, and `YEAR`/`MONTH`/`DAY`
#' @keywords internal
erddap_read_day <- function(spec, vars, day, bounding_box) {
  if (!requireNamespace("ncdf4", quietly = TRUE)) {
    stop("Reading ERDDAP needs the ncdf4 package, which datamatch suggests ",
         "rather than requires.\nInstall it with:  install.packages(\"ncdf4\")",
         call. = FALSE)
  }

  window <- sprintf("[(%sT00:00:00Z):(%sT23:59:59Z)]", format(day), format(day))
  # A singleton altitude axis sits between time and latitude where present, and
  # omitting it makes griddap reject the request.
  altitude <- if (isTRUE(spec$has_altitude)) "[(0.0):(0.0)]" else ""
  box <- sprintf("[(%f):(%f)][(%f):(%f)]",
                 bounding_box[["ymin"]], bounding_box[["ymax"]],
                 bounding_box[["xmin"]], bounding_box[["xmax"]])

  query <- paste(vapply(vars, function(v) {
    paste0(spec$variables[[v]], window, altitude, box)
  }, character(1)), collapse = ",")

  url <- paste0(spec$server, "/griddap/", spec$dataset_id, ".nc?", query)
  destination <- tempfile(fileext = ".nc")
  on.exit(unlink(destination), add = TRUE)

  status <- tryCatch(
    utils::download.file(url, destination, mode = "wb", quiet = TRUE),
    error = function(e) conditionMessage(e),
    warning = function(w) conditionMessage(w))
  if (!identical(status, 0L) || !file.exists(destination)) {
    stop("griddap request failed", call. = FALSE)
  }

  handle <- ncdf4::nc_open(destination)
  on.exit(ncdf4::nc_close(handle), add = TRUE)

  lon <- as.numeric(ncdf4::ncvar_get(handle, "longitude"))
  lat <- as.numeric(ncdf4::ncvar_get(handle, "latitude"))

  # See the section above: the request can come back with a neighbouring day's
  # step attached, so which steps belong to this day is decided here.
  stamps <- as.POSIXct(as.numeric(ncdf4::ncvar_get(handle, "time")),
                       origin = "1970-01-01", tz = "UTC")
  on_day <- which(as.Date(stamps, tz = "UTC") == day)
  if (length(on_day) == 0) return(NULL)
  # Daily products carry one step per day. If a dataset ever carried more, the
  # first is taken rather than several rows landing on one cell and day.
  step <- on_day[1]

  frame <- expand.grid(x = lon, y = lat)

  for (v in vars) {
    values <- ncdf4::ncvar_get(handle, spec$variables[[v]],
                               collapse_degen = TRUE)
    # [lon, lat] already when only one step came back; [lon, lat, time] when
    # more did.
    slice <- if (length(dim(values)) == 3) values[, , step] else values
    frame[[v]] <- as.numeric(slice)
  }

  # Cloud, land, and cells outside the retrieval.
  frame <- frame[rowSums(!is.na(frame[vars])) > 0, , drop = FALSE]
  if (nrow(frame) == 0) return(NULL)

  frame$YEAR <- as.integer(format(day, "%Y"))
  frame$MONTH <- as.integer(format(day, "%m"))
  frame$DAY <- as.integer(format(day, "%d"))
  rownames(frame) <- NULL
  frame
}

#' Printable dictionary of the ERDDAP datasets and their variables
#'
#' @return a data frame of class `datamatch_dictionary`
#' @examples
#' erddap_dictionary()
#' @seealso [erddap_datasets()]
#' @export
erddap_dictionary <- function() {
  catalog <- erddap_datasets()

  dictionary <- do.call(rbind, lapply(names(catalog), function(name) {
    spec <- catalog[[name]]
    data.frame(
      name = names(spec$variables),
      variable = unname(spec$variables),
      label = spec$label,
      units = unname(spec$units[names(spec$variables)]),
      source = name,
      layer = NA_character_,
      description = paste0(spec$label, ". ", spec$resolution, ", ",
                           spec$frequency, "."),
      stringsAsFactors = FALSE)
  }))

  class(dictionary) <- c("datamatch_dictionary", "data.frame")
  dictionary
}
