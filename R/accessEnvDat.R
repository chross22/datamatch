
#' Parse the `dates` argument into a sorted, unique vector of dates
#'
#' `YYYYMMDD` is what a survey database usually holds, and `YYYY-MM-DD` is what
#' R prints, so both are accepted, along with `Date` objects and a mixture of
#' the three. Numbers are taken as `YYYYMMDD` too, since an unquoted `20150402`
#' is an easy thing to type.
#'
#' @section Why invalid dates are an error:
#' `"20150230"` parses to `NA` rather than to a date. Dropping it would fetch
#' fewer days than were asked for and say nothing, leaving the gap to be found
#' much later as a missing row. The offending values are named instead.
#'
#' @param dates the `dates` argument as the caller wrote it
#' @return a sorted, deduplicated `Date` vector
#' @keywords internal
parse_dates <- function(dates) {
  if (length(dates) == 0) {
    stop("`dates` is empty, so the request names no dates to fetch.",
         call. = FALSE)
  }

  parsed <- if (inherits(dates, "Date")) {
    dates
  } else if (inherits(dates, "POSIXt")) {
    as.Date(dates)
  } else {
    text <- trimws(as.character(dates))
    # Eight digits is YYYYMMDD; anything else is tried as ISO, which is what
    # as.Date() reads by default.
    compact <- grepl("^[0-9]{8}$", text)
    out <- rep(as.Date(NA), length(text))
    out[compact] <- as.Date(text[compact], format = "%Y%m%d")
    out[!compact] <- as.Date(text[!compact], format = "%Y-%m-%d")
    out
  }

  bad <- is.na(parsed)
  if (any(bad)) {
    offending <- as.character(dates)[bad]

    # c() on a mixture of strings and Dates turns the Dates into their numeric
    # form - days since 1970 - before this function ever sees them. The values
    # that arrive are small integers, which is a confusing thing to be told is
    # not a date unless the cause is named.
    coerced <- suppressWarnings(as.numeric(offending))
    looks_coerced <- !anyNA(coerced) && all(coerced > 0 & coerced < 1e5)

    stop("`dates` could not be read as dates: ",
         paste(utils::head(offending, 10), collapse = ", "),
         if (sum(bad) > 10) paste0(" (and ", sum(bad) - 10, " more)"), "\n",
         if (looks_coerced) {
           paste0("Those look like Date objects that were turned into numbers. ",
                  "c() does that\nwhen Dates and strings are combined. Keep ",
                  "`dates` to one type.\n")
         },
         "Use YYYYMMDD, YYYY-MM-DD, or Date objects. A date the calendar does ",
         "not have,\nsuch as 20150230, cannot be read.",
         call. = FALSE)
  }

  # Sorted and deduplicated so the result comes back in date order however the
  # argument was written, and a date named twice is fetched once.
  sort(unique(parsed))
}

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

#' Download one day's subset, returning any failure rather than raising it
#'
#' Defined at the top level rather than as a closure inside [accessEnvDat()] so
#' that its enclosing environment is this package's namespace. A closure would
#' carry `accessEnvDat()`'s whole evaluation frame — including the cluster
#' object itself — to every worker when it is serialised.
#'
#' Errors are caught and returned as text. Under [parallel::parLapplyLB()] an
#' error thrown in a worker aborts the entire batch, so a single bad day would
#' discard the days still in flight. Collecting failures instead lets every day
#' be attempted, and lets the caller be told about all of them at once rather
#' than about whichever one happened to fail first.
#'
#' @param item <list> one work item: `ofile`, `time`, and the calendar fields
#' @inheritParams build_copernicus_args
#' @param bounding_box passed to `bb`
#' @return `NULL` on success, or a one-line description of the failure
#' @keywords internal
download_day <- function(item, dataset_id, vars, bounding_box, depth) {
  tryCatch({
    download_copernicus_subset(dataset_id = dataset_id,
                               vars = vars,
                               depth = depth,
                               bb = bounding_box,
                               time = item$time,
                               ofile = item$ofile)
    NULL
  }, error = function(e) paste0("  ", format(item$time), ": ", conditionMessage(e)))
}

#' Read one day's cached file into a data frame
#'
#' Reads stay in the calling session. They are local file reads, and running
#' them in workers would mean serialising every day's data frame back over a
#' socket — for a large bounding box that costs more than the read itself.
#'
#' @param item <list> one work item, as built by [accessEnvDat()]
#' @param vars <char> variable codes, in the order they were requested
#' @return a data frame of one grid, with `YEAR`, `MONTH` and `DAY`
#' @keywords internal
read_day <- function(item, vars) {
  x <- terra::rast(item$ofile)

  # Put the layers in the order they were requested before anything is named.
  x <- order_layers(x, vars)

  as.data.frame(x, xy = TRUE) |>
    dplyr::mutate(YEAR = item$year, MONTH = item$month, DAY = item$day)
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
#' @section Monthly and daily data:
#' `frequency = "monthly"` (the default) fetches monthly means: one field per
#' month, and one row per grid cell per month. `frequency = "daily"` fetches the
#' daily datasets instead, expanding each requested month into its days.
#'
#' ```
#' accessEnvDat(vars = c("SST", "MLD"), frequency = "daily",
#'              years = 2015, months = 4:6,
#'              bounding_box = list(xmin = -70, xmax = -65, ymin = 42, ymax = 45))
#' ```
#'
#' Note what that costs: three months of daily data is 91 downloads rather than
#' 3, and 91 grids rather than 3 in memory. A decade of daily data over a large
#' box will not fit in a laptop's RAM as an `sf` object, and is better fetched a
#' season at a time.
#'
#' @section Fetching specific dates:
#' `dates` is the other way to keep that in hand. It names the exact dates to
#' fetch, so only the days that matter are downloaded:
#'
#' ```
#' accessEnvDat(vars = "SST", dates = c("20150402", "20150517", "20150623"),
#'              bounding_box = bb)
#' ```
#'
#' This is the argument to use when matching daily data to observations. Survey
#' dates differ from month to month, and a rule such as "the 1st and 15th" does
#' not describe them. Take the dates from the observations themselves:
#'
#' ```
#' accessEnvDat(vars = "SST", dates = unique(observations$date), bounding_box = bb)
#' ```
#'
#' `YYYYMMDD` strings, `YYYY-MM-DD` strings, and `Date` objects are all accepted,
#' and may be mixed. Dates are sorted and deduplicated, so the result comes back
#' in date order however the argument was written, and a date named twice is
#' fetched once.
#'
#' `dates` says which time steps to fetch, so `years` and `months` are neither
#' needed nor accepted alongside it. Passing it implies `frequency = "daily"`,
#' since naming a date means nothing to a monthly mean, and passing it with an
#' explicit `frequency = "monthly"` is a contradiction rather than something to
#' resolve by guessing.
#'
#' A date that does not exist — `"20150230"` — is an error naming it, rather than
#' a silently dropped request.
#'
#' Fetching dates is not the same as averaging a month. Three dates are a sample
#' of the month, with whatever weather fell on them; a monthly mean is the month.
#' Which you want depends on whether the observations being matched are themselves
#' instants or aggregates.
#'

#' Not every variable has a daily equivalent. `PH`, `PP`, `DIATO` and `DINO` are
#' published as monthly composites only, and asking for them daily is refused
#' before anything is downloaded. Daily `CHL` comes from the gap-free
#' interpolated ocean colour dataset rather than the monthly composite, which
#' [accessEnvDat()] reports when it happens — see [copernicus_variables()].
#'
#' Passing `dataset_id` explicitly overrides all of this: that dataset's own
#' frequency decides, since a Copernicus dataset is published at one step.
#'
#' @section Downloading in parallel:
#' Days already in the cache are read directly. Only the missing ones are
#' downloaded, and those go out `n_workers` at a time through a PSOCK cluster,
#' since a Copernicus subset request spends nearly all its time waiting on the
#' API rather than on this machine.
#'
#' The default of 4 is deliberately modest. The limit is the service and the
#' network, not local cores, and a large `n_workers` mostly earns rate limiting.
#' Raise it toward 8 for many small requests; use `n_workers = 1` to download
#' serially.
#'
#' The cluster is PSOCK rather than fork-based ([parallel::mclapply()]): GDAL,
#' which `terra` and `sf` use internally, is not fork-safe, and forking after it
#' has initialised can corrupt state in the children. PSOCK workers are fresh R
#' sessions, which avoids that.
#'
#' Reading and converting the downloaded files stays in this session. Those are
#' local file reads, and returning each day's data frame from a worker would
#' cost more in serialisation than the read saves.
#'
#' A day that fails does not abort the others. Every day is attempted, the
#' successful ones stay in the cache, and the error names each day that failed —
#' so re-running the same call retries only those.
#'
#' @param product_id <char> product identification string from the Copernicus
#'   Marine Data Store. Optional when `vars` are catalog names.
#' @param dataset_id <char> dataset identification string from the Copernicus
#'   Marine Data Store. Optional when `vars` are catalog names.
#' @param vars <char> variables to access: names from [variable_dictionary()],
#'   raw Copernicus variable codes, or a mixture
#' @param years <numeric> years of data to access. Required unless `dates` is
#'   given, which names the time steps itself.
#' @param months <numeric> months of data to access. Required unless `dates` is
#'   given.
#' @param bounding_box <list> named list of spatial coordinates of bounding box
#' @param depth <numeric> depth range to access (in meters)
#' @param overwrite <logical> whether or not to overwrite the data if it exists locally
#' @param mode <char> `"reanalysis"` (the default) for the multi-year hindcast,
#'   or `"forecast"` for the analysis-and-forecast products, which run to about
#'   ten days ahead. See [forecast_variables()] for which variables have a
#'   forecast equivalent and how the identifiers differ.
#' @param frequency <char> `"monthly"` (the default) for monthly means, or
#'   `"daily"` for daily ones. See the Monthly and daily data section. Ignored
#'   when `dataset_id` is given, since the dataset itself fixes the step.
#' @param dates the exact dates to fetch, as `YYYYMMDD` strings,
#'   `YYYY-MM-DD` strings, or `Date` objects. `NULL`, the default, fetches every
#'   day of the requested months instead. Passing `dates` implies
#'   `frequency = "daily"` and replaces `years` and `months`, which must then not
#'   be given. See the Fetching specific dates section.
#' @param n_workers <integer> how many days to download at once. See the
#'   Downloading in parallel section. Use `n_workers = 1` to download one day at
#'   a time.
#' @return envDat <sf object> sf object containing requested environmental data from Copernicus Marine Service
#' @export
accessEnvDat <- function(product_id = NULL, dataset_id = NULL, vars,
                         years = NULL, months = NULL,
                         bounding_box, depth = c(0,1),
                         overwrite = FALSE, n_workers = 4,
                         frequency = c("monthly", "daily"), dates = NULL,
                         mode = c("reanalysis", "forecast")) {
  mode <- match.arg(mode)
  # Recorded before match.arg(), which assigns to `frequency` and so makes
  # missing(frequency) FALSE from that point on.
  frequency_given <- !missing(frequency)
  frequency <- match.arg(frequency)

  # Parsed here rather than where the calendar is built, so a malformed date
  # costs an error at the call instead of a request for a day that never was.
  if (!is.null(dates)) {
    dates <- parse_dates(dates)

    # `dates` says which time steps to fetch. Taking years and months as well
    # would leave two answers to one question, and no obvious rule for which
    # wins when they disagree.
    if (!is.null(years) || !is.null(months)) {
      stop("`dates` already names which time steps to fetch, so `years` and ",
           "`months` are not used with it.\nDrop them, or drop `dates` and ",
           "select whole months instead.", call. = FALSE)
    }

    # Naming a date only means anything in daily data, so asking for dates is
    # asking for daily. Requiring frequency = "daily" alongside would let
    # `dates` be passed to a monthly fetch and do nothing.
    if (frequency_given && frequency == "monthly") {
      stop("`dates` names days to fetch, but frequency = \"monthly\" was given.\n",
           "A monthly mean has one field per month, so a date within it selects ",
           "nothing.\nDrop `dates` for monthly means, or drop ",
           "frequency = \"monthly\" to fetch those dates.", call. = FALSE)
    }
    frequency <- "daily"
  } else if (is.null(years) || is.null(months)) {
    stop("`years` and `months` are required, unless `dates` names the exact ",
         "dates to fetch.", call. = FALSE)
  }

  # `vars` may be catalog names ("SST") or raw Copernicus codes ("thetao").
  # Codes go to the API; names come back as the column names, so a caller who
  # asked for SST gets a column called SST rather than thetao.
  resolved <- resolve_variables(vars, mode = mode)
  var_codes <- resolved$codes
  var_names <- resolved$names

  # With every variable in the catalog, the product and dataset are implied and
  # need not be repeated at the call site.
  if (is.null(product_id) || is.null(dataset_id)) {
    inferred <- infer_dataset(vars, mode = mode, frequency = frequency)
    product_id <- product_id %||% inferred$product_id
    dataset_id <- dataset_id %||% inferred$dataset_id
  }

  # The dataset decides the time step, not the argument: an explicit dataset_id
  # is a specific Copernicus dataset published at one frequency, and honouring
  # `frequency` over it would either request the same monthly field 31 times or
  # take one day as a whole month. Where the two disagree, say so.
  is_daily <- grepl("_P1D(-|$)", dataset_id)
  if (frequency_given && is_daily != (frequency == "daily")) {
    warning("dataset_id '", dataset_id, "' is ",
            if (is_daily) "daily" else "monthly", ", but frequency = \"",
            frequency, "\" was given. Following the dataset. Omit dataset_id to ",
            "let frequency choose it.", call. = FALSE)
  }

  # A monthly dataset has one field per month, so a date within it selects
  # nothing. Fetching the months those dates fall in is the closest honest
  # reading of the request, and beats returning a month's mean labelled as a day.
  if (!is.null(dates) && !is_daily) {
    warning("`dates` names days, and dataset_id '", dataset_id, "' is monthly. ",
            "Fetching the month containing each date instead, one field per ",
            "month. Use a daily dataset_id to fetch the dates themselves.",
            call. = FALSE)
    months_wanted <- unique(format(dates, "%Y-%m"))
    dates <- as.Date(paste0(months_wanted, "-01"))
  }

  # Build the full list of (year, month, day) combinations to fetch up front,
  # so they can be dispatched in parallel instead of nested serial loops.
  work_items <- if (!is.null(dates)) {
    lapply(dates, function(d) {
      list(year = as.integer(format(d, "%Y")),
           month = as.integer(format(d, "%m")),
           day = as.integer(format(d, "%d")))
    })
  } else {
    items <- list()
    for (year in years) {
      for (month in months) {
        in_month <- if (is_daily) {
          seq_len(lubridate::days_in_month(lubridate::ym(paste(year, month, sep = "-"))))
        } else {
          1L
        }
        for (day in in_month) {
          items[[length(items) + 1]] <- list(year = year, month = month, day = day)
        }
      }
    }
    items
  }

  if (length(work_items) == 0) {
    stop("The request names no time steps to fetch.", call. = FALSE)
  }

  # Each day's date and cache path, resolved once, so the download and read
  # phases below agree on where the file is without recomputing it.
  work_items <- lapply(work_items, function(item) {
    item$time <- lubridate::ymd(paste(item$year, item$month, item$day, sep = "-"))
    item$ofile <- copernicus_cache(
      "tmp", cache_filename(product_id, dataset_id, item$time, var_codes,
                            bounding_box, depth))
    item
  })

  # Only the days not already on disk cost anything. Everything else is a local
  # read, which is why the cache exists.
  needed <- if (overwrite) {
    work_items
  } else {
    Filter(function(item) !fs::file_exists(item$ofile), work_items)
  }

  if (length(needed) > 0) {
    # A cluster is only worth its startup cost when there is more than one day
    # to fetch. One missing day - the common case on a re-run that filled in a
    # gap - downloads in this session.
    failures <- if (n_workers > 1 && length(needed) > 1) {
      cl <- parallel::makeCluster(min(n_workers, length(needed)))
      on.exit(parallel::stopCluster(cl), add = TRUE)
      # The workers need this package: download_day() resolves the downloader
      # and the client wrapper through its namespace.
      parallel::clusterEvalQ(cl, library(datamatch))

      # And they need to be told where the client is. A worker starts a fresh R
      # with none of this session's options, so datamatch.copernicusmarine does
      # not cross over and the worker falls back to looking for the client on
      # its own PATH. That PATH is not the one the user sees: an app launched
      # from RStudio, or any GUI, inherits a minimal environment, so a client
      # installed under conda is invisible there. The result was a parallel
      # fetch failing with "Could not find the Copernicus Marine client" on a
      # machine where the serial fetch works and the option is set.
      client <- getOption("datamatch.copernicusmarine")
      if (!is.null(client)) {
        parallel::clusterCall(cl, function(path) {
          options(datamatch.copernicusmarine = path)
        }, client)
      }
      # Load-balanced rather than pre-chunked: days differ in size and in how
      # hard the API is working, so a fixed split leaves workers idle.
      parallel::parLapplyLB(cl, needed, download_day,
                            dataset_id = dataset_id, vars = var_codes,
                            bounding_box = bounding_box, depth = depth)
    } else {
      lapply(needed, download_day,
             dataset_id = dataset_id, vars = var_codes,
             bounding_box = bounding_box, depth = depth)
    }

    failures <- unlist(failures)
    if (length(failures) > 0) {
      stop(length(failures), " of ", length(needed), " day(s) could not be ",
           "downloaded:\n", paste(failures, collapse = "\n"),
           "\nThe days that did succeed are cached, so re-running this call ",
           "retries only the failures.", call. = FALSE)
    }
  }

  covars <- dplyr::bind_rows(lapply(work_items, read_day, vars = var_codes))

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
  out <- sf::st_as_sf(covars,
                      coords = c("x", "y"),
                      crs = sf::st_crs(4326))

  # Record the step this was fetched at, because it cannot always be recovered
  # from the result. detect_temporal_resolution() reads daily data from more
  # than one day within a month, and a `dates` request of one date per month -
  # survey dates, typically - looks identical to monthly data. Guessing monthly
  # there would make matchData() join by month and quietly ignore the day.
  attr(out, "datamatch_step") <- if (is_daily) "day" else "month"
  out
}
