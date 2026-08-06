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
