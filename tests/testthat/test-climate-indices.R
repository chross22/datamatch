# Published index files, reproduced in miniature. Parsing is tested against
# these rather than by downloading, so the tests do not depend on a network or
# on a provider keeping its file where it is.

cpc_lines <- c(
  "         Jan    Feb    Mar    Apr    May    Jun    Jul    Aug    Sep    Oct    Nov    Dec",
  "1950    0.92   0.40   -0.36   0.73  -0.59  -0.06  -1.26  -0.05   0.25   0.85  -1.26  -1.02",
  "1951    0.08   0.70   -1.02  -0.22  -0.59  -1.64   1.37  -0.22  -1.36   1.87  -0.39   1.32",
  "2020    1.34   1.62    1.32   0.63  -1.26   0.29  -0.36  -0.44   0.62  -1.02   0.94   0.11"
)

psl_lines <- c(
  "  1948  2020",
  "1948   -0.11   -0.23    0.10    0.05   -0.03   -0.02    0.11    0.21    0.13    0.05    0.02   -0.09",
  "1949    0.05    0.11   -0.14   -0.02    0.09    0.14   -0.05   -0.11    0.02    0.07    0.15    0.03",
  "2020    0.42    0.39    0.35    0.31    0.29    0.33    0.38    0.41    0.44    0.40    0.36    0.33",
  "  -99.99",
  "  AMO unsmoothed from the Kaplan SST V2",
  "  Calculated at NOAA PSL1"
)

# The retroflection index, in the shape Nature publishes it: two caption lines, a
# header, then daily rows dated as decimal years on a fixed 365-day year.
decimal_year_lines <- function(start = 1993, months = 1:12, days_in_last = 31) {
  rows <- unlist(lapply(months, function(m) {
    first <- as.Date(paste(start, m, 1, sep = "-"))
    n <- if (m == max(months)) days_in_last else
      as.integer(lubridate::days_in_month(first))
    doy <- as.integer(format(first, "%j")) + seq_len(n) - 1
    sprintf("%.11f,%.4f", start + (doy - 1) / 365, m / 100)
  }))
  c("Figure 3,", ",", "Date,Retroflection index", rows)
}

test_that("a decimal-year CSV parses to monthly means", {
  series <- parse_index_table(decimal_year_lines(), format = "decimal_year_csv",
                              name = "LCR")

  expect_setequal(names(series), c("YEAR", "MONTH", "LCR"))
  expect_equal(nrow(series), 12)
  # Each month's daily values are all month/100, so the monthly mean is too.
  expect_equal(series$LCR, (1:12) / 100)
})

test_that("a month backed by too few days is dropped, not reported", {
  # December carries a single day here. Averaging it would produce a confident
  # December value resting on one observation, which is the failure mode
  # min_coverage guards against elsewhere in the package.
  series <- parse_index_table(decimal_year_lines(days_in_last = 1),
                              format = "decimal_year_csv", name = "LCR")

  expect_equal(nrow(series), 11)
  expect_false(12 %in% series$MONTH)

  # Half a month is enough to keep.
  half <- parse_index_table(decimal_year_lines(days_in_last = 16),
                            format = "decimal_year_csv", name = "LCR")
  expect_true(12 %in% half$MONTH)
})

test_that("decimal years are read on the 365-day convention the file uses", {
  # The published file steps by exactly 1/365 between days. Reading it as 365.25
  # would walk the derived dates off by several days across the record, moving
  # values into neighbouring months.
  series <- parse_index_table(decimal_year_lines(), format = "decimal_year_csv",
                              name = "LCR")

  expect_setequal(series$MONTH, 1:12)
  expect_true(all(series$YEAR == 1993))
})

test_that("the retroflection index carries its citation", {
  # It is the published output of one study rather than an operational product,
  # so the reference has to travel with it.
  entry <- climate_indices()$LCR

  expect_match(entry$reference, "Jutras")
  expect_match(entry$reference, "10\\.1038/s41467-023-38321-y")

  dictionary <- as.data.frame(index_dictionary())
  expect_match(dictionary$reference[dictionary$name == "LCR"], "Nature Communications")
  # The operational indices have no single paper, and must not have one invented.
  expect_true(all(is.na(dictionary$reference[dictionary$name %in% c("NAO", "AO")])))
})

test_that("a CPC table parses to one row per month", {
  series <- parse_index_table(cpc_lines, format = "cpc_table", name = "NAO")

  expect_setequal(names(series), c("YEAR", "MONTH", "NAO"))
  expect_equal(nrow(series), 3 * 12)
  expect_setequal(unique(series$YEAR), c(1950, 1951, 2020))
  expect_setequal(unique(series$MONTH), 1:12)

  expect_equal(series$NAO[series$YEAR == 1950 & series$MONTH == 1], 0.92)
  expect_equal(series$NAO[series$YEAR == 2020 & series$MONTH == 12], 0.11)
})

test_that("the header row is not mistaken for data", {
  series <- parse_index_table(cpc_lines, format = "cpc_table", name = "NAO")

  # The month-name header has no leading year, so it must be dropped rather
  # than parsed into NAs.
  expect_false(any(is.na(series$YEAR)))
  expect_true(all(series$YEAR > 1900))
})

test_that("a PSL table drops its year-range line and footer", {
  series <- parse_index_table(psl_lines, format = "psl_table", name = "AMO")

  # "1948 2020" is a year range, not a data row: two fields, not thirteen.
  expect_setequal(unique(series$YEAR), c(1948, 1949, 2020))
  expect_equal(nrow(series), 3 * 12)
  expect_equal(series$AMO[series$YEAR == 1948 & series$MONTH == 1], -0.11)
})

test_that("provider missing-value codes become NA, not extreme values", {
  # -99.9 left literal would read as an extraordinary anomaly and would
  # dominate any model that saw it.
  with_missing <- c(
    "         Jan    Feb    Mar    Apr    May    Jun    Jul    Aug    Sep    Oct    Nov    Dec",
    "2024    0.50   0.30  -99.90 -99.90 -99.90 -99.90 -99.90 -99.90 -99.90 -99.90 -99.90 -99.90"
  )

  series <- parse_index_table(with_missing, format = "cpc_table", name = "NAO")

  expect_equal(nrow(series), 2)
  expect_equal(series$MONTH, 1:2)
  expect_false(any(series$NAO < -90))
})

test_that("a PSL file's declared missing code is honoured", {
  lines <- c(
    "  2000  2000",
    "2000    0.42    0.39  -99.99  -99.99  -99.99  -99.99  -99.99  -99.99  -99.99  -99.99  -99.99  -99.99",
    "  -99.99"
  )

  series <- parse_index_table(lines, format = "psl_table", name = "AMO")

  expect_equal(nrow(series), 2)
  expect_false(any(series$AMO < -90))
})

test_that("a partial current year is padded rather than misaligned", {
  # Providers publish the running year with only the months so far. Without
  # padding, the shorter row would recycle and assign wrong months.
  partial <- c(
    "         Jan    Feb    Mar",
    "2026    0.11   0.22   0.33"
  )

  series <- parse_index_table(partial, format = "cpc_table", name = "NAO")

  expect_equal(nrow(series), 3)
  expect_equal(series$MONTH, 1:3)
  expect_equal(series$NAO, c(0.11, 0.22, 0.33))
})

test_that("an unparseable file is reported rather than returning nothing", {
  expect_error(parse_index_table(c("not", "an index file"),
                                  format = "cpc_table", name = "NAO"),
               "No data rows found")
})

test_that("the index dictionary lists what is available", {
  dictionary <- index_dictionary()

  expect_s3_class(dictionary, "datamatch_index_dictionary")
  expect_true(all(c("NAO", "AMO") %in% dictionary$name))
  expect_true(all(nzchar(dictionary$url)))

  output <- capture.output(result <- withVisible(print(dictionary)))
  expect_false(result$visible)
  expect_true(any(grepl("NAO", output)))
  # The defining property of these covariates, stated where it will be read.
  expect_true(any(grepl("no spatial dimension", output)))
})

test_that("an unknown index names the available ones", {
  expect_error(fetch_climate_index("ENSO"), "ENSO")
  expect_error(fetch_climate_index("ENSO"), "Available")
})

test_that("attaching an index broadcasts one value across a month", {
  series <- parse_index_table(cpc_lines, format = "cpc_table", name = "NAO")
  observations <- data.frame(
    YEAR = c(1950, 1950, 1951),
    MONTH = c(1, 1, 2),
    lon = c(-69, -68, -67)
  )

  result <- attach_climate_index(observations, series)

  # Two stations in the same month share the basin-wide value.
  expect_equal(result$NAO, c(0.92, 0.92, 0.70))
})

test_that("months with no published value are NA", {
  series <- parse_index_table(cpc_lines, format = "cpc_table", name = "NAO")
  observations <- data.frame(YEAR = 1999, MONTH = 6)

  result <- attach_climate_index(observations, series)

  expect_true(is.na(result$NAO))
})

test_that("differently named time columns are supported", {
  series <- parse_index_table(cpc_lines, format = "cpc_table", name = "NAO")
  observations <- data.frame(year = 1950, month = 1)

  result <- attach_climate_index(observations, series,
                                  year_col = "year", month_col = "month")

  expect_equal(result$NAO, 0.92)
  expect_error(attach_climate_index(observations, series), "Column 'YEAR' not found")
})

# The RAPID overturning series is NetCDF rather than a text table, so it is
# tested against a file written here rather than a downloaded one. Same reason
# as the fixtures above: no network, no dependence on a provider's file layout.

write_rapid_fixture <- function(path, origin = "2004-01-01") {
  # Twelve-hourly through January and February 2004, with a different constant
  # in each month, so the monthly means are exactly 10 and 20.
  offsets <- seq(0, 59.5, by = 0.5)
  dates <- as.Date(origin) + offsets
  values <- ifelse(as.integer(format(dates, "%m")) == 1, 10, 20)

  time <- ncdf4::ncdim_def("time", paste("days since", origin, "00:00:00"),
                           offsets)
  moc <- ncdf4::ncvar_def("moc_mar_hc10", "Sv", time, -99999)
  nc <- ncdf4::nc_create(path, moc)
  ncdf4::ncvar_put(nc, moc, values)
  ncdf4::nc_close(nc)
  path
}

local_index_cache <- function(env = parent.frame()) {
  cache <- file.path(tempdir(), paste0("datamatch-index-", sample.int(1e6, 1)))
  previous <- options(datamatch.cache = cache)
  withr::defer({ options(previous); unlink(cache, recursive = TRUE) }, envir = env)
  cache
}

test_that("AMOC is in the catalog, with a source and a citation", {
  catalog <- climate_indices()

  expect_true("AMOC" %in% names(catalog))
  expect_equal(catalog$AMOC$format, "rapid_netcdf")
  expect_true(nzchar(catalog$AMOC$reference))
  expect_match(catalog$AMOC$url, "^https://")
  # It is one of the two indices that must be cited, so it has to reach the
  # dictionary's reference column rather than only the description.
  dictionary <- as.data.frame(index_dictionary())
  expect_false(is.na(dictionary$reference[dictionary$name == "AMOC"]))
})

test_that("the twelve-hourly RAPID series is averaged to monthly", {
  skip_if_not_installed("ncdf4")
  local_index_cache()

  path <- write_rapid_fixture(tempfile(fileext = ".nc"))
  series <- read_rapid_netcdf(path, "AMOC")

  expect_equal(names(series), c("YEAR", "MONTH", "AMOC"))
  expect_equal(nrow(series), 2)
  expect_equal(series$MONTH, c(1, 2))
  expect_equal(series$AMOC, c(10, 20))
})

test_that("the time origin is read from the file, not assumed", {
  # RAPID has re-based the time axis between releases, so hard-coding 2004-04-01
  # would silently shift every date.
  skip_if_not_installed("ncdf4")
  local_index_cache()

  path <- write_rapid_fixture(tempfile(fileext = ".nc"), origin = "2010-01-01")
  series <- read_rapid_netcdf(path, "AMOC")

  expect_equal(unique(series$YEAR), 2010)
})

test_that("the cache expires on the provider's publishing cadence", {
  # The hazard in caching a living dataset is that it quietly stops being
  # current. Each index says how often its source publishes, and that sets how
  # long a cached copy may be reused.
  expect_equal(index_max_age("monthly"), 7)
  expect_equal(index_max_age("annual"), 30)
  expect_equal(index_max_age("none"), Inf)

  # LCR finished at 2014, so re-downloading it can never add anything.
  expect_equal(index_max_age(climate_indices()$LCR$updates), Inf)
  expect_true(is.finite(index_max_age(climate_indices()$AMOC$updates)))
})

test_that("a fresh cached file is reused and a stale one is re-downloaded", {
  cache <- local_index_cache()
  entry <- list(format = "cpc_table", updates = "monthly")
  target <- copernicus_cache("indices", "TEST.txt")

  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  writeLines("cached", target)

  # Fresh: no download attempted at all.
  local_mocked_bindings(
    download.file = function(...) stop("should not download a fresh cache"),
    .package = "utils"
  )
  expect_equal(cached_index_file("unused", "TEST", entry), target)

  # Stale: the age limit is what forces the re-fetch, so backdating the file is
  # enough to trigger it without waiting a week.
  Sys.setFileTime(target, Sys.time() - as.difftime(30, units = "days"))
  expect_gt(index_cache_age(target), 7)

  # Now it does try, and since the fake download fails it falls back to the
  # cached copy with a warning rather than erroring. Losing access to data
  # already on disk would be the worse failure.
  expect_warning(cached_index_file("unused", "TEST", entry), "may be out of date")
})

test_that("a stale cache with no fallback is an error", {
  local_index_cache()
  entry <- list(format = "cpc_table", updates = "monthly")

  local_mocked_bindings(
    download.file = function(...) stop("provider is down"),
    .package = "utils"
  )
  expect_error(cached_index_file("unused", "MISSING", entry),
               "Could not download")
})

test_that("a failed refresh falls back to the cached copy with a warning", {
  # A provider being briefly down should not become our outage. Returning the
  # old file is right; returning it silently is not.
  local_index_cache()
  entry <- list(format = "cpc_table", updates = "monthly")
  target <- copernicus_cache("indices", "TEST.txt")

  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  writeLines("cached", target)
  Sys.setFileTime(target, Sys.time() - as.difftime(30, units = "days"))

  local_mocked_bindings(
    download.file = function(...) stop("provider is down"),
    .package = "utils"
  )

  expect_warning(file <- cached_index_file("unused", "TEST", entry),
                 "may be out of date")
  expect_equal(file, target)
})

test_that("refresh = TRUE ignores a cache that is still fresh", {
  local_index_cache()
  entry <- list(format = "cpc_table", updates = "monthly")
  target <- copernicus_cache("indices", "TEST.txt")

  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  writeLines("cached", target)

  local_mocked_bindings(
    download.file = function(...) stop("asked for"),
    .package = "utils"
  )
  expect_warning(cached_index_file("unused", "TEST", entry, refresh = TRUE),
                 "may be out of date")
})

test_that("a living series that has stopped short is reported", {
  # The check is on the data, not the cache: a fresh download of a stale file is
  # still stale.
  old <- data.frame(YEAR = 2004, MONTH = 1:2, AMOC = c(1, 2))
  current <- data.frame(YEAR = as.integer(format(Sys.Date(), "%Y")),
                        MONTH = as.integer(format(Sys.Date(), "%m")),
                        NAO = 0)

  expect_message(warn_if_stale(old, "AMOC", climate_indices()$AMOC),
                 "ends .* months ago")
  expect_no_message(warn_if_stale(current, "NAO", climate_indices()$NAO))
  # A finished dataset ending years ago is not a problem to report.
  expect_no_message(warn_if_stale(old, "LCR", climate_indices()$LCR))
})

test_that("status reports what is cached without downloading anything", {
  local_index_cache()

  local_mocked_bindings(
    download.file = function(...) stop("status must not download"),
    .package = "utils"
  )

  status <- climate_index_status()
  expect_setequal(status$index, names(climate_indices()))
  expect_true(all(!status$cached))          # nothing cached yet
  expect_equal(status$updates[status$index == "LCR"], "none")
  expect_output(print(status), "Cached climate indices")
})

test_that("refresh skips indices that cannot change", {
  local_index_cache()

  expect_message(refresh_climate_index("LCR"), "finished dataset")
})

test_that("a renamed variable is reported rather than returning nothing", {
  skip_if_not_installed("ncdf4")
  local_index_cache()

  path <- tempfile(fileext = ".nc")
  time <- ncdf4::ncdim_def("time", "days since 2004-01-01 00:00:00", c(0, 1))
  other <- ncdf4::ncvar_def("something_else", "Sv", time, -99999)
  nc <- ncdf4::nc_create(path, other)
  ncdf4::ncvar_put(nc, other, c(1, 2))
  ncdf4::nc_close(nc)

  expect_error(read_rapid_netcdf(path, "AMOC"),
               "no longer contains")
})

# ---- the RAPID overturning series -------------------------------------------

# Twelve-hourly steps, as Dates. seq.Date has no "12 hours", but a Date is a
# number of days, so half-day increments give the same axis.
twelve_hourly <- function(from, to) seq(as.Date(from), as.Date(to), by = 0.5)

# A miniature of the file RAPID publishes: a twelve-hourly `moc_mar_hc10`
# series with its time axis given as "days since <origin>". Written rather than
# downloaded, so these tests need no network and no 1 MB fetch.
write_rapid_nc <- function(path, dates, values, origin = as.Date("2004-04-01"),
                           variable = "moc_mar_hc10") {
  time_dim <- ncdf4::ncdim_def("time", paste("days since", format(origin)),
                               as.numeric(dates - origin), unlim = TRUE)
  var <- ncdf4::ncvar_def(variable, "Sv", list(time_dim), -9999)
  nc <- ncdf4::nc_create(path, list(var))
  ncdf4::ncvar_put(nc, var, values)
  ncdf4::nc_close(nc)
  path
}

test_that("the twelve-hourly RAPID series averages to monthly", {
  skip_if_not_installed("ncdf4")

  # Two months at twelve-hourly steps. Each month's values are its own month
  # number, so the monthly mean is known without recomputing it here.
  dates <- twelve_hourly("2004-04-01", "2004-05-31")
  values <- as.numeric(format(dates, "%m"))
  path <- write_rapid_nc(tempfile(fileext = ".nc"), dates, values)

  series <- read_rapid_netcdf(path, "AMOC")

  expect_setequal(names(series), c("YEAR", "MONTH", "AMOC"))
  expect_equal(series$MONTH, c(4, 5))
  expect_equal(series$AMOC, c(4, 5))
})

test_that("the time origin is read from the file, not assumed", {
  skip_if_not_installed("ncdf4")

  # RAPID has re-based its time axis across releases, so a hard-coded origin
  # would silently shift every value into the wrong month.
  dates <- twelve_hourly("2010-07-01", "2010-07-31")
  path <- write_rapid_nc(tempfile(fileext = ".nc"), dates,
                         rep(17, length(dates)),
                         origin = as.Date("1950-01-01"))

  series <- read_rapid_netcdf(path, "AMOC")

  expect_equal(series$YEAR, 2010)
  expect_equal(series$MONTH, 7)
  expect_equal(series$AMOC, 17)
})

test_that("a renamed variable is reported with what the file does hold", {
  skip_if_not_installed("ncdf4")

  # The transport variable is named in the code. If RAPID renames it, saying so
  # beats returning nothing or failing inside ncvar_get().
  dates <- twelve_hourly("2004-04-01", "2004-04-30")
  path <- write_rapid_nc(tempfile(fileext = ".nc"), dates,
                         rep(17, length(dates)), variable = "moc_renamed")

  expect_error(read_rapid_netcdf(path, "AMOC"), "moc_mar_hc10")
  expect_error(read_rapid_netcdf(path, "AMOC"), "moc_renamed")
})

test_that("a cached file is not downloaded again", {
  skip_if_not_installed("ncdf4")

  dates <- twelve_hourly("2004-04-01", "2004-04-30")
  path <- write_rapid_nc(tempfile(fileext = ".nc"), dates,
                         rep(17, length(dates)))

  # The file is over a megabyte and RAPID times out on repeated requests, so a
  # re-fetch is a real cost rather than a tidiness point. Caching now lives in
  # cached_index_file(), so that is what is exercised here.
  local_mocked_bindings(copernicus_cache = function(...) path)
  local_mocked_bindings(
    download.file = function(...) stop("should not be downloaded again"),
    .package = "utils"
  )

  entry <- climate_indices()$AMOC
  expect_equal(cached_index_file("unused", "AMOC", entry), path)
  expect_equal(nrow(read_rapid_netcdf(path, "AMOC")), 1)
})

test_that("fetch_climate_index routes AMOC to the NetCDF reader", {
  skip_if_not_installed("ncdf4")

  dates <- twelve_hourly("2004-04-01", "2004-05-31")
  path <- write_rapid_nc(tempfile(fileext = ".nc"), dates,
                         as.numeric(format(dates, "%m")))

  # cached_index_file() looks here, finds a fresh file, and skips downloading.
  local_mocked_bindings(copernicus_cache = function(...) path)

  # readLines() is what every other index uses; AMOC must not reach it.
  local_mocked_bindings(
    readLines = function(...) stop("AMOC is NetCDF, not a text table"),
    .package = "base"
  )

  series <- suppressMessages(fetch_climate_index("AMOC"))

  expect_setequal(names(series), c("YEAR", "MONTH", "AMOC"))
  expect_equal(series$AMOC, c(4, 5))
  expect_equal(nrow(suppressMessages(fetch_climate_index("AMOC", years = 2004))), 2)
})

test_that("the overturning index carries its citation", {
  entry <- climate_indices()$AMOC

  expect_match(entry$reference, "RAPID|Moat")
  expect_match(entry$source, "RAPID")

  dictionary <- as.data.frame(index_dictionary())
  expect_false(is.na(dictionary$reference[dictionary$name == "AMOC"]))
  # Both cited indices show up where someone will read them.
  output <- capture.output(print(index_dictionary()))
  expect_true(any(grepl("Cite when used", output)))
  expect_true(any(grepl("AMOC", output)))
})
