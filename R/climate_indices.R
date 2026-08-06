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
#' @return a named list, one entry per index, each with `label`, `source`,
#'   `url`, and `description`
#' @examples
#' names(climate_indices())
#' @seealso [fetch_climate_index()], [attach_climate_index()]
#' @export
climate_indices <- function() {
  list(
    NAO = list(
      label = "North Atlantic Oscillation",
      source = "NOAA CPC",
      url = "https://www.cpc.ncep.noaa.gov/products/precip/CWlink/pna/norm.nao.monthly.b5001.current.ascii.table",
      format = "cpc_table",
      description = paste("Pressure difference between the Icelandic Low and",
                          "Azores High. Sets the strength and track of westerly",
                          "winds, and with them heat flux and mixing over the",
                          "North Atlantic shelves.")
    ),
    AO = list(
      label = "Arctic Oscillation",
      source = "NOAA CPC",
      url = "https://www.cpc.ncep.noaa.gov/products/precip/CWlink/daily_ao_index/monthly.ao.index.b50.current.ascii.table",
      format = "cpc_table",
      description = paste("Strength of the polar vortex. Related to the NAO but",
                          "hemispheric rather than Atlantic-specific.")
    ),
    AMO = list(
      label = "Atlantic Multidecadal Oscillation",
      source = "NOAA PSL",
      url = "https://psl.noaa.gov/data/correlation/amon.us.long.data",
      format = "psl_table",
      description = paste("Detrended North Atlantic SST anomaly, varying on a",
                          "multidecadal timescale. A slow background state",
                          "rather than a year-to-year signal.")
    ),
    PDO = list(
      label = "Pacific Decadal Oscillation",
      source = "NOAA PSL",
      url = "https://psl.noaa.gov/data/correlation/pdo.data",
      format = "psl_table",
      description = paste("Leading mode of North Pacific SST variability.",
                          "Included for completeness; of limited relevance to",
                          "Atlantic shelf systems.")
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
    data.frame(name = name, label = entry$label, source = entry$source,
               url = entry$url, description = entry$description,
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
  print(flat[c("name", "label", "source")], row.names = FALSE, right = FALSE)
  cat("\nThese have no spatial dimension: one value per month, basin-wide.\n")
  cat("Sources: as.data.frame(index_dictionary())$url\n")
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
#' @param index an index name from [climate_indices()]
#' @param years years to keep; `NULL` keeps the whole record
#' @param url override the catalog URL, if a provider has moved the file
#' @return a data frame with `YEAR`, `MONTH`, and a column named after the index
#' @examples
#' \dontrun{
#' nao <- fetch_climate_index("NAO", years = 2000:2020)
#' head(nao)
#' }
#' @export
fetch_climate_index <- function(index, years = NULL, url = NULL) {
  catalog <- climate_indices()
  if (!index %in% names(catalog)) {
    stop("Unknown climate index: ", index,
         "\nAvailable: ", paste(names(catalog), collapse = ", "), call. = FALSE)
  }
  entry <- catalog[[index]]

  lines <- tryCatch(
    readLines(url %||% entry$url, warn = FALSE),
    error = function(e) {
      stop("Could not download the ", index, " index from ", url %||% entry$url,
           "\n", conditionMessage(e),
           "\nProviders move these files; pass `url` to override.", call. = FALSE)
    }
  )

  series <- parse_index_table(lines, format = entry$format, name = index)
  if (!is.null(years)) {
    series <- series[series$YEAR %in% years, ]
    rownames(series) <- NULL
  }
  series
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
