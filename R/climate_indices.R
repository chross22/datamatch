#' Catalog of basin-scale climate indices
#'
#' Unlike the gridded variables, these have **no spatial dimension** — one value
#' per month describes the whole basin. They enter a model as a shared state
#' every observation in a month experiences, which is a different kind of
#' covariate from local temperature: they carry no information about *where*
#' within a region conditions are better, only about what year and season it was.
#'
#' That makes them useful for interannual questions ("was this a warm-regime
#' year?") and useless for spatial ones. A model given only indices cannot
#' produce a map.
#'
#' @return a named list, one entry per index, each with `label`, `units`,
#'   `source`, `url`, and `description`
#' @examples
#' names(climate_indices())
#' @seealso [fetch_climate_index()], [attach_climate_index()]
#' @export
climate_indices <- function() {
  list(
    NAO = list(
      label = "North Atlantic Oscillation",
      units = "standardized anomaly",
      source = "NOAA CPC",
      url = "https://www.cpc.ncep.noaa.gov/products/precip/CWlink/pna/norm.nao.monthly.b5001.current.ascii.table",
      format = "cpc_table",
      updates = "monthly",
      description = paste("Pressure difference between the Icelandic Low and",
                          "Azores High. Sets the strength and track of westerly",
                          "winds, and with them heat flux and mixing over the",
                          "North Atlantic shelves.")
    ),
    AO = list(
      label = "Arctic Oscillation",
      units = "standardized anomaly",
      source = "NOAA CPC",
      url = "https://www.cpc.ncep.noaa.gov/products/precip/CWlink/daily_ao_index/monthly.ao.index.b50.current.ascii.table",
      format = "cpc_table",
      updates = "monthly",
      description = paste("Strength of the polar vortex. Related to the NAO but",
                          "hemispheric rather than Atlantic-specific.")
    ),
    AMO = list(
      label = "Atlantic Multidecadal Oscillation",
      units = "degrees C",
      source = "NOAA PSL",
      url = "https://psl.noaa.gov/data/correlation/amon.us.long.data",
      format = "psl_table",
      updates = "monthly",
      description = paste("Detrended North Atlantic SST anomaly, varying on a",
                          "multidecadal timescale. A slow background state",
                          "rather than a year-to-year signal.")
    ),
    PDO = list(
      label = "Pacific Decadal Oscillation",
      units = "standardized anomaly",
      source = "NOAA PSL",
      url = "https://psl.noaa.gov/data/correlation/pdo.data",
      format = "psl_table",
      updates = "monthly",
      description = paste("Leading mode of North Pacific SST variability.",
                          "Included for completeness; of limited relevance to",
                          "Atlantic shelf systems.")
    ),
    LCR = list(
      label = "Labrador Current retroflection",
      units = "fraction",
      source = "Jutras et al. 2023, Nature Communications",
      url = paste0("https://static-content.springer.com/esm/",
                   "art%3A10.1038%2Fs41467-023-38321-y/MediaObjects/",
                   "41467_2023_38321_MOESM5_ESM.csv"),
      format = "decimal_year_csv",
      # Published with a paper and finished at 2014. It will not grow.
      updates = "none",
      reference = paste("Jutras M, Dufour CO, Mucci A, Talbot LC (2023)",
                        "Large-scale control of the retroflection of the",
                        "Labrador Current. Nature Communications 14:2623.",
                        "doi:10.1038/s41467-023-38321-y"),
      description = paste("How much of the Labrador Current turns eastward at",
                          "the Grand Banks instead of continuing southwest along",
                          "the shelf. Positive values mean stronger retroflection,",
                          "so less cold, fresh, oxygen-rich Labrador water reaches",
                          "the Scotian Shelf and Gulf of Maine. Unlike the",
                          "atmospheric indices here it describes a current rather",
                          "than a pressure or temperature pattern, which makes it",
                          "the more direct predictor of shelf water properties.",
                          "Covers 1993-2014 only.")
    ),
    AMOC = list(
      label = "Atlantic Meridional Overturning Circulation",
      units = "Sv",
      source = "RAPID-MOCHA-WBTS array at 26.5N",
      url = "https://rapid.ac.uk/sites/default/files/rapid_data/moc_transports.nc",
      format = "rapid_netcdf",
      # RAPID extends the series in versioned releases roughly yearly.
      updates = "annual",
      reference = paste("Moat BI et al. Atlantic meridional overturning",
                        "circulation observed by the RAPID-MOCHA-WBTS array at",
                        "26N. British Oceanographic Data Centre, NERC, UK.",
                        "doi:10.5285/223b34a3-2dc5-c945-e063-6c86abc0f5b3"),
      description = paste("Strength of the overturning circulation, in",
                          "Sverdrups, measured directly by a mooring array at",
                          "26.5N. This is the real thing rather than a proxy,",
                          "which is also its limitation: it starts in April 2004",
                          "and is measured far south of the shelf, so it",
                          "describes the basin-scale circulation the Labrador",
                          "and slope currents sit within rather than local",
                          "conditions. The published series is twelve-hourly and",
                          "is averaged to monthly here. A weaker AMOC is",
                          "associated with a warming Northwest Atlantic shelf,",
                          "so the sign of any relationship is worth checking",
                          "against LCR and AMO rather than assumed.")
    )
  )
}

#' Printable dictionary of climate indices
#'
#' @return a data frame of class `datamatch_index_dictionary`
#' @examples
#' index_dictionary()
#' @export
index_dictionary <- function() {
  catalog <- climate_indices()
  dictionary <- do.call(rbind, lapply(names(catalog), function(name) {
    entry <- catalog[[name]]
    data.frame(name = name, label = entry$label,
               # Most of these are standardized anomalies, which is a unit in
               # the sense that matters: it says the number is in standard
               # deviations rather than in anything physical, so a coefficient
               # fitted to it is not comparable with one fitted to AMOC.
               units = entry$units %||% NA_character_,
               source = entry$source, url = entry$url,
               # Indices published with a paper carry its citation. The
               # operational ones from NOAA have no single paper to point at,
               # so this is empty for them rather than invented.
               reference = entry$reference %||% NA_character_,
               description = entry$description,
               stringsAsFactors = FALSE)
  }))
  class(dictionary) <- c("datamatch_index_dictionary", "data.frame")
  dictionary
}

#' @param x a `datamatch_index_dictionary`
#' @param ... ignored
#' @rdname index_dictionary
#' @export
print.datamatch_index_dictionary <- function(x, ...) {
  flat <- as.data.frame(x)
  cat("Climate indices available by name\n")
  cat(strrep("-", 62), "\n", sep = "")
  print(flat[c("name", "label", "units", "source")], row.names = FALSE, right = FALSE)
  cat("\nThese have no spatial dimension: one value per month, basin-wide.\n")

  cited <- flat[!is.na(flat$reference), ]
  if (nrow(cited) > 0) {
    cat("\nCite when used:\n")
    for (i in seq_len(nrow(cited))) {
      cat("  ", cited$name[i], ": ", cited$reference[i], "\n", sep = "")
    }
  }

  cat("\nSources: as.data.frame(index_dictionary())$url\n")
  invisible(x)
}

#' Fetch a monthly climate index
#'
#' Downloads an index from its official source and returns it as a tidy monthly
#' series.
#'
#' The published files use fixed-width year-by-month tables with provider-specific
#' missing-value codes, which are parsed here into one row per month.
#'
#' @section Citing an index:
#' `LCR` and `AMOC` come from specific published sources rather than being
#' operational products, and should be cited when used:
#'
#' \itemize{
#'   \item Jutras M, Dufour CO, Mucci A, Talbot LC (2023) Large-scale control of
#'     the retroflection of the Labrador Current. *Nature Communications*
#'     **14**:2623. \doi{10.1038/s41467-023-38321-y}
#'   \item Moat BI et al. Atlantic meridional overturning circulation observed by
#'     the RAPID-MOCHA-WBTS array at 26N. British Oceanographic Data Centre,
#'     NERC, UK. \doi{10.5285/223b34a3-2dc5-c945-e063-6c86abc0f5b3}
#' }
#'
#' The series is the source data published with that paper's Figure 3, fetched
#' from the journal rather than recomputed, so the values are the authors' own.
#' `as.data.frame(index_dictionary())$reference` carries this at runtime.
#'
#' Note that these are the **raw** index values, running roughly -0.09 to 0.18,
#' consistent with a fraction of the seeded particles. Figure 3a of the paper
#' plots a detrended, smoothed series normalized to `[-1, 1]`, spanning about
#' -0.6 to +0.5. Both describe the same quantity, but a value here is not
#' comparable with that figure. Reproducing the plotted variant means applying
#' the paper's chain: detrend, 12-month rolling mean, rescale to `[-1, 1]`,
#' subtract the 1993-2015 mean.
#'
#' @section Staying current:
#' Downloads are cached, and the cache expires on an interval matched to how
#' often each provider actually publishes: weekly for the monthly NOAA indices,
#' monthly for RAPID, never for `LCR`, which is a finished dataset. So a living
#' index re-downloads on its own without being asked, and a finished one is not
#' re-fetched pointlessly.
#'
#' Two things back that up. If the returned series ends further behind the
#' present than its provider's usual lag, that is reported: a fresh download of a
#' stale file is still stale, so the check is on the data rather than on the
#' cache. And if a download fails while a cached copy exists, the cached copy is
#' returned with a warning rather than an error, so a provider's outage does not
#' become yours.
#'
#' [climate_index_status()] reports what is cached and what is due;
#' [refresh_climate_index()] forces the issue.
#'
#' @param index an index name from [climate_indices()]
#' @param years years to keep; `NULL` keeps the whole record
#' @param url override the catalog URL, if a provider has moved the file
#' @param max_age how many days a cached copy may be reused for. `NULL` uses the
#'   provider's publishing cadence.
#' @param refresh re-download even if a fresh cached copy exists
#' @return a data frame with `YEAR`, `MONTH`, and a column named after the index
#' @examples
#' \dontrun{
#' nao <- fetch_climate_index("NAO", years = 2000:2020)
#' head(nao)
#' }
#' @export
fetch_climate_index <- function(index, years = NULL, url = NULL,
                                max_age = NULL, refresh = FALSE) {
  catalog <- climate_indices()
  if (!index %in% names(catalog)) {
    stop("Unknown climate index: ", index,
         "\nAvailable: ", paste(names(catalog), collapse = ", "), call. = FALSE)
  }
  entry <- catalog[[index]]
  source_url <- url %||% entry$url

  file <- cached_index_file(source_url, index, entry, max_age = max_age,
                            refresh = refresh)

  # Most of these are plain text tables. RAPID publishes only NetCDF at a stable
  # URL - the ASCII version is behind a signup form - so that one is read as
  # binary rather than through readLines().
  series <- if (identical(entry$format, "rapid_netcdf")) {
    read_rapid_netcdf(file, index)
  } else {
    parse_index_table(readLines(file, warn = FALSE), format = entry$format,
                      name = index)
  }

  warn_if_stale(series, index, entry)

  if (!is.null(years)) {
    missing <- setdiff(years, series$YEAR)
    series <- series[series$YEAR %in% years, ]
    rownames(series) <- NULL
    if (length(missing) > 0) {
      message("The ", index, " series has no data for ",
              paste(range(missing), collapse = "-"),
              ". It covers ", min(series$YEAR, na.rm = TRUE), "-",
              max(series$YEAR, na.rm = TRUE), ".",
              if (!identical(entry$updates, "none")) {
                "\n  If you expected more recent values, refresh = TRUE re-downloads."
              })
    }
  }
  series
}

#' Download an index file, reusing a recent copy
#'
#' These files are re-read constantly and change slowly, so they are cached. The
#' hazard in caching a *living* dataset is that it silently stops being current,
#' so the cache expires on an interval matched to how often the provider
#' actually publishes.
#'
#' @param url where to download from
#' @param index the index name, used for the cache path and messages
#' @param entry the catalog entry, for its `updates` cadence
#' @param max_age maximum cache age in days; `NULL` uses the cadence default
#' @param refresh re-download even if a fresh copy exists
#' @return path to a local file
#' @keywords internal
cached_index_file <- function(url, index, entry, max_age = NULL,
                              refresh = FALSE) {
  extension <- if (identical(entry$format, "rapid_netcdf")) ".nc" else ".txt"
  file <- copernicus_cache("indices", paste0(index, extension))
  max_age <- max_age %||% index_max_age(entry$updates)

  usable <- !refresh && file.exists(file) && file.size(file) > 0 &&
    index_cache_age(file) <= max_age

  if (usable) return(file)

  # download.file() defaults to 60s, which is not always enough for RAPID.
  previous <- options(timeout = max(300, getOption("timeout", 60)))
  on.exit(options(previous), add = TRUE)

  partial <- paste0(file, ".part")
  downloaded <- tryCatch({
    utils::download.file(url, destfile = partial, mode = "wb", quiet = TRUE)
    file.exists(partial) && file.size(partial) > 0
  }, error = function(e) {
    unlink(partial)
    FALSE
  })

  if (!isTRUE(downloaded)) {
    unlink(partial)
    # A stale copy beats no copy. The download may have failed because the
    # provider is briefly down, and refusing to return data already on disk
    # would turn their outage into ours - but say so, so it is not mistaken
    # for current.
    if (file.exists(file) && file.size(file) > 0) {
      warning("Could not refresh the ", index, " index from ", url,
              "\n  Using the cached copy from ",
              format(file.mtime(file), "%Y-%m-%d"), " instead, which may be ",
              "out of date.", call. = FALSE)
      return(file)
    }
    stop("Could not download the ", index, " index from ", url,
         "\nProviders move these files; pass `url` to override.", call. = FALSE)
  }

  # Rename only once the download is complete, so an interrupted fetch cannot
  # leave a truncated file in the cache to be trusted later.
  file.rename(partial, file)
  file
}

#' How long a cached index may be reused, in days
#'
#' Matched to how often the provider publishes. Re-downloading a monthly index
#' every day is pointless traffic, and re-downloading a finished one is pointless
#' full stop.
#'
#' @param updates `"monthly"`, `"annual"`, or `"none"`
#' @return a number of days, possibly `Inf`
#' @keywords internal
index_max_age <- function(updates) {
  switch(updates %||% "monthly",
         monthly = 7,
         annual = 30,
         none = Inf,
         7)
}

#' Age of a cached file, in days
#'
#' @param file path to a cached file
#' @return age in days, or `Inf` if it does not exist
#' @keywords internal
index_cache_age <- function(file) {
  if (!file.exists(file)) return(Inf)
  as.numeric(difftime(Sys.time(), file.mtime(file), units = "days"))
}

#' Warn when a living index has stopped being current
#'
#' A fresh download of a stale file is still stale. This checks the data rather
#' than the cache: if a series that is supposed to keep growing ends well before
#' now, that is worth knowing whether the cause is a cache, a provider pause, or
#' a publication lag.
#'
#' @param series the parsed monthly series
#' @param index the index name
#' @param entry the catalog entry
#' @return invisibly `NULL`
#' @keywords internal
warn_if_stale <- function(series, index, entry) {
  updates <- entry$updates %||% "monthly"
  if (identical(updates, "none") || nrow(series) == 0) return(invisible(NULL))

  last <- max(series$YEAR * 12 + series$MONTH, na.rm = TRUE)
  now <- as.integer(format(Sys.Date(), "%Y")) * 12 +
    as.integer(format(Sys.Date(), "%m"))
  behind <- now - last

  # Publication lag is normal and differs by provider: the NOAA indices appear
  # within a month or two, RAPID within a year or more. Only flag a gap wider
  # than the provider's own habit.
  tolerated <- switch(updates, monthly = 3, annual = 24, 3)
  if (behind <= tolerated) return(invisible(NULL))

  message("The ", index, " series ends ", behind, " months ago (",
          max(series$YEAR, na.rm = TRUE), "-",
          sprintf("%02d", series$MONTH[which.max(series$YEAR * 12 + series$MONTH)]),
          "), which is longer than this source's usual lag.",
          "\n  refresh_climate_index(\"", index, "\") re-downloads it. If that ",
          "changes nothing, the provider has not published either.")
  invisible(NULL)
}

#' Re-download cached climate indices
#'
#' Forces a fresh copy, ignoring the cache. Use after a provider publishes, or
#' when a series looks like it has stopped short.
#'
#' Indices that will never change are skipped rather than re-fetched. `LCR` was
#' published with a paper and ends at 2014, so downloading it again cannot
#' produce anything new.
#'
#' @param index one or more index names, or `NULL` for every living index
#' @return invisibly, a data frame of what was refreshed and where it now ends
#' @examples
#' \dontrun{
#' refresh_climate_index()          # every index that is still growing
#' refresh_climate_index("AMOC")
#' }
#' @seealso [climate_index_status()], [fetch_climate_index()]
#' @export
refresh_climate_index <- function(index = NULL) {
  catalog <- climate_indices()
  living <- names(catalog)[vapply(catalog, function(e) {
    !identical(e$updates %||% "monthly", "none")
  }, logical(1))]

  index <- index %||% living
  unknown <- setdiff(index, names(catalog))
  if (length(unknown) > 0) {
    stop("Unknown climate index: ", paste(unknown, collapse = ", "),
         "\nAvailable: ", paste(names(catalog), collapse = ", "), call. = FALSE)
  }

  skipped <- setdiff(index, living)
  if (length(skipped) > 0) {
    message("Skipping ", paste(skipped, collapse = ", "),
            ": finished dataset, refreshing cannot add anything.")
  }

  result <- do.call(rbind, lapply(intersect(index, living), function(name) {
    series <- fetch_climate_index(name, refresh = TRUE)
    data.frame(index = name,
               ends = paste0(max(series$YEAR, na.rm = TRUE), "-",
                             sprintf("%02d", series$MONTH[which.max(
                               series$YEAR * 12 + series$MONTH)])),
               months = nrow(series), stringsAsFactors = FALSE)
  }))

  if (!is.null(result)) print(result, row.names = FALSE)
  invisible(result)
}

#' What is cached, how old it is, and whether it is due a refresh
#'
#' Reports without downloading anything, so it is safe to call offline.
#'
#' @return a data frame, one row per index, of class
#'   `datamatch_index_status`
#' @examples
#' climate_index_status()
#' @seealso [refresh_climate_index()]
#' @export
climate_index_status <- function() {
  catalog <- climate_indices()

  status <- do.call(rbind, lapply(names(catalog), function(name) {
    entry <- catalog[[name]]
    updates <- entry$updates %||% "monthly"
    extension <- if (identical(entry$format, "rapid_netcdf")) ".nc" else ".txt"
    file <- copernicus_cache("indices", paste0(name, extension))
    age <- index_cache_age(file)
    limit <- index_max_age(updates)

    data.frame(
      index = name,
      updates = updates,
      cached = is.finite(age),
      age_days = if (is.finite(age)) round(age, 1) else NA_real_,
      refresh_due = is.finite(age) && age > limit,
      stringsAsFactors = FALSE
    )
  }))

  class(status) <- c("datamatch_index_status", "data.frame")
  status
}

#' @param x a `datamatch_index_status`
#' @param ... ignored
#' @rdname climate_index_status
#' @export
print.datamatch_index_status <- function(x, ...) {
  flat <- as.data.frame(x)
  cat("Cached climate indices\n")
  cat(strrep("-", 52), "\n", sep = "")
  print(flat, row.names = FALSE, right = FALSE)

  due <- flat$index[flat$refresh_due]
  if (length(due) > 0) {
    cat("\nDue a refresh: ", paste(due, collapse = ", "),
        "\n  refresh_climate_index()\n", sep = "")
  } else {
    cat("\nNothing is overdue. Living indices re-download on their own once the",
        "\ncached copy passes its age limit.\n")
  }
  cat("\nCache location: ", copernicus_cache("indices"), "\n", sep = "")
  invisible(x)
}

#' Read the RAPID overturning series and average it to monthly
#'
#' The RAPID array publishes a twelve-hourly NetCDF series at a stable URL,
#' while the ASCII equivalent sits behind a signup form. So this reads the
#' overturning variable from the downloaded binary and aggregates it to the
#' monthly step the rest of the indices use. Downloading and caching happen in
#' [cached_index_file()], which every index shares.
#'
#' Averaging is the honest direction here. The twelve-hourly series is dominated
#' by Ekman variability that a monthly covariate cannot represent anyway, and a
#' monthly mean of it is a well-defined quantity. Months are not filtered on
#' completeness: the array reports continuously within its deployment periods, so
#' a short month is a gap in the record rather than a partial average, and it is
#' more useful to see it than to drop it.
#'
#' @param file a local NetCDF file, already downloaded
#' @param name the index name, for error messages
#' @return a data frame with `YEAR`, `MONTH`, and a column named for the index
#' @keywords internal
read_rapid_netcdf <- function(file, name) {
  if (!requireNamespace("ncdf4", quietly = TRUE)) {
    stop("The '", name, "' index is published as NetCDF, which needs the ",
         "'ncdf4' package.\n  install.packages(\"ncdf4\")", call. = FALSE)
  }

  nc <- ncdf4::nc_open(file)
  on.exit(ncdf4::nc_close(nc), add = TRUE)

  variable <- "moc_mar_hc10"
  if (!variable %in% names(nc$var)) {
    stop("The ", name, " file no longer contains '", variable, "'.",
         "\nVariables present: ", paste(names(nc$var), collapse = ", "),
         call. = FALSE)
  }

  values <- as.numeric(ncdf4::ncvar_get(nc, variable))
  offset <- as.numeric(ncdf4::ncvar_get(nc, "time"))

  # "days since <date>", so the origin is read from the file rather than
  # hard-coded: RAPID has re-based it across releases.
  units <- ncdf4::ncatt_get(nc, "time", "units")$value
  origin <- as.Date(trimws(sub("^days since", "", units)), format = "%Y-%m-%d")
  if (is.na(origin)) {
    stop("Could not read the time origin from the ", name, " file. ",
         "Units were: ", units, call. = FALSE)
  }

  dates <- origin + offset
  monthly <- stats::aggregate(
    values,
    by = list(YEAR = as.integer(format(dates, "%Y")),
              MONTH = as.integer(format(dates, "%m"))),
    FUN = function(z) mean(z, na.rm = TRUE)
  )

  names(monthly)[3] <- name
  monthly <- monthly[order(monthly$YEAR, monthly$MONTH), ]
  rownames(monthly) <- NULL
  monthly
}

#' Parse a published climate index table
#'
#' Both supported layouts are a year label followed by twelve monthly values.
#' They differ in what surrounds that: CPC tables carry a header row of month
#' names, PSL tables carry a leading year-range line, a trailing missing-value
#' code, and provenance footer lines.
#'
#' @param lines the downloaded file's lines
#' @param format `"cpc_table"` or `"psl_table"`
#' @param name what to call the value column
#' @return a data frame with `YEAR`, `MONTH`, and the named value column
#' @keywords internal
parse_index_table <- function(lines, format, name) {
  # Not every published index is a year-by-month table. The retroflection index
  # is a daily series in decimal years, so it is parsed separately rather than
  # bent into the shape of the CPC and PSL files.
  if (format == "decimal_year_csv") {
    return(parse_decimal_year_csv(lines, name))
  }

  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]

  # A data row is a 4-digit year followed by numbers. Anything else - month-name
  # headers, footers, provenance - fails this and is dropped, which is more
  # robust than counting how many lines to skip.
  is_data <- grepl("^\\d{4}([ \t]+-?[0-9.]+)+$", lines)

  # PSL files open with a year range ("1948 2020"), which matches the pattern
  # above and would otherwise parse as a year with one monthly value of 2020.
  # A real row's values are anomalies, never four-digit years, so a lone
  # year-like value identifies the header.
  is_data <- is_data & !vapply(lines, function(line) {
    fields <- suppressWarnings(as.numeric(strsplit(line, "[ \t]+")[[1]]))
    length(fields) == 2 && !anyNA(fields) &&
      fields[2] >= 1800 && fields[2] <= 2100 && fields[2] == round(fields[2])
  }, logical(1), USE.NAMES = FALSE)

  missing_code <- if (format == "psl_table") psl_missing_code(lines) else NULL
  rows <- lines[is_data]

  if (length(rows) == 0) {
    stop("No data rows found in the index file; its format may have changed.",
         call. = FALSE)
  }

  parsed <- lapply(rows, function(row) {
    fields <- as.numeric(strsplit(row, "[ \t]+")[[1]])
    year <- fields[1]
    values <- fields[-1]
    # Some providers publish the current year with trailing months absent.
    length(values) <- 12
    data.frame(YEAR = year, MONTH = 1:12, value = values)
  })

  series <- do.call(rbind, parsed)

  if (!is.null(missing_code)) {
    series$value[!is.na(series$value) &
                   abs(series$value - missing_code) < 1e-6] <- NA_real_
  }
  # CPC uses -99.9 for missing; left as a literal value it would read as an
  # extraordinary anomaly rather than absent data.
  series$value[!is.na(series$value) & series$value <= -99] <- NA_real_

  series <- series[!is.na(series$value), ]
  names(series)[names(series) == "value"] <- name
  rownames(series) <- NULL
  series
}

#' Parse a daily index published as decimal years
#'
#' The format the Jutras et al. retroflection index is published in: a couple of
#' figure-caption lines, a `Date,<label>` header, then one row per day with the
#' date as a decimal year.
#'
#' @section Two conversions worth stating:
#' **Decimal years use a fixed 365-day year here.** The step between consecutive
#' rows is 1/365 to eleven significant figures, so leap days are not represented
#' and a date is recovered as day `round(fraction * 365)` of its year. Assuming
#' 365.25 instead would walk the derived dates off by up to several days over the
#' record.
#'
#' **Daily values are averaged to monthly.** Every other index in this package is
#' monthly, and [attach_climate_index()] joins on year and month, so a daily
#' series has nothing to join to. The underlying index is already smoothed with a
#' 12-month rolling mean, so monthly averaging discards very little.
#'
#' Months backed by fewer than half their days are dropped rather than reported.
#' The record's first and last months are partial by construction, and the fixed
#' 365-day year rolls the final record into a January of its own — which would
#' otherwise surface as a confident-looking monthly value resting on a single day.
#'
#' @param lines the downloaded file's lines
#' @param name what to call the value column
#' @return a data frame with `YEAR`, `MONTH`, and the named value column
#' @keywords internal
parse_decimal_year_csv <- function(lines, name) {
  lines <- trimws(lines)
  # A data row is two comma-separated numbers. The figure-caption and header
  # lines fail that, which is steadier than skipping a fixed number of lines.
  is_data <- grepl("^-?[0-9.]+,-?[0-9.eE+-]+$", lines)
  rows <- lines[is_data]

  if (length(rows) == 0) {
    stop("No data rows found in the index file; its format may have changed.",
         call. = FALSE)
  }

  fields <- do.call(rbind, strsplit(rows, ","))
  decimal_year <- as.numeric(fields[, 1])
  value <- as.numeric(fields[, 2])
  keep <- !is.na(decimal_year) & !is.na(value)
  decimal_year <- decimal_year[keep]
  value <- value[keep]

  year <- floor(decimal_year)
  date <- as.Date(paste0(year, "-01-01")) + round((decimal_year - year) * 365)

  daily <- data.frame(YEAR = as.integer(format(date, "%Y")),
                      MONTH = as.integer(format(date, "%m")),
                      value = value)

  monthly <- stats::aggregate(value ~ YEAR + MONTH, data = daily,
                              FUN = function(z) c(mean(z), length(z)))
  monthly <- data.frame(YEAR = monthly$YEAR, MONTH = monthly$MONTH,
                        value = monthly$value[, 1], days = monthly$value[, 2])

  # A month backed by a handful of days is not that month's value. The record's
  # first and last months are partial by construction, and the fixed 365-day
  # year rolls the final record into a January of its own - which would
  # otherwise appear as a confident-looking value resting on one day. Half a
  # month is the same bar min_coverage sets by default elsewhere here.
  full <- as.numeric(lubridate::days_in_month(
    lubridate::ymd(paste(monthly$YEAR, monthly$MONTH, 1, sep = "-"))))
  monthly <- monthly[monthly$days >= full / 2, ]

  monthly <- monthly[order(monthly$YEAR, monthly$MONTH), c("YEAR", "MONTH", "value")]
  names(monthly)[names(monthly) == "value"] <- name
  rownames(monthly) <- NULL
  monthly
}

#' Missing-value code declared in a PSL index file
#'
#' PSL files state their own missing-value code on a line after the data, rather
#' than using a fixed convention.
#'
#' @param lines the file's lines
#' @return the code, or `NULL` if not declared
#' @keywords internal
psl_missing_code <- function(lines) {
  candidates <- suppressWarnings(as.numeric(lines))
  declared <- candidates[!is.na(candidates) & candidates < -90]
  if (length(declared) == 0) NULL else declared[1]
}

#' Attach climate indices to observations
#'
#' Joins one or more monthly indices by year and month. Because an index has no
#' spatial dimension, every observation in a month receives the same value.
#'
#' @param dat a data frame or `sf` object with year and month columns
#' @param indices index names to attach, or a data frame from
#'   [fetch_climate_index()]
#' @param years years to fetch; defaults to those present in `dat`
#' @param year_col,month_col names of the year and month columns
#' @return `dat` with one column per index. Months with no published value are
#'   `NA`.
#' @examples
#' \dontrun{
#' observations <- attach_climate_index(observations, c("NAO", "AMO"))
#' }
#' @export
attach_climate_index <- function(dat, indices, years = NULL,
                                 year_col = "YEAR", month_col = "MONTH") {
  for (column in c(year_col, month_col)) {
    if (!column %in% names(dat)) {
      stop("Column '", column, "' not found. Pass year_col/month_col if they ",
           "are named differently.", call. = FALSE)
    }
  }

  years <- years %||% sort(unique(dat[[year_col]]))
  series_list <- if (is.data.frame(indices)) {
    list(indices)
  } else {
    lapply(indices, fetch_climate_index, years = years)
  }

  for (series in series_list) {
    value_col <- setdiff(names(series), c("YEAR", "MONTH"))
    key <- paste(dat[[year_col]], dat[[month_col]], sep = "-")
    series_key <- paste(series$YEAR, series$MONTH, sep = "-")
    dat[[value_col]] <- series[[value_col]][match(key, series_key)]
  }
  dat
}
