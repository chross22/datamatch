# A date that has not happened cannot have been observed, and outside a forecast
# horizon cannot have been modelled either. Before this guard, asking for one
# cost a download attempt per day and then an error from the server about
# exceeding the dataset coordinates - which named neither the date nor the
# mistake. The usual causes are a typo in a year and a projection window that
# ran past the end of the record.

bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
future_year <- as.integer(format(Sys.Date(), "%Y")) + 5
future_date <- paste0(future_year, "-06-15")

test_that("the horizon is today for anything observational", {
  expect_error(stop_if_future(Sys.Date() + 1, "Test"), "have not happened yet")
  expect_null(stop_if_future(Sys.Date(), "Test"))
  expect_null(stop_if_future(Sys.Date() - 1, "Test"))
})

test_that("a forecast horizon reaches past today, and no further", {
  expect_null(stop_if_future(Sys.Date() + 10, "Test", ahead = 10L))
  expect_error(stop_if_future(Sys.Date() + 11, "Test", ahead = 10L),
               "have not happened yet")
})

test_that("the message names the furthest date and the horizon", {
  msg <- tryCatch(stop_if_future(as.Date("2099-01-01"), "Copernicus"),
                  error = conditionMessage)
  expect_match(msg, "2099-01-01", fixed = TRUE)
  expect_match(msg, "Copernicus", fixed = TRUE)
  expect_match(msg, format(Sys.Date()), fixed = TRUE)
  # The projection case is the one a caller is least likely to spot themselves.
  expect_match(msg, "projection window", fixed = TRUE)
})

test_that("NA days are left to the date parser rather than counted as future", {
  expect_null(stop_if_future(as.Date(NA), "Test"))
})

test_that("every access function refuses a future date before fetching", {
  # No network is needed: each of these fails at the guard, which sits ahead of
  # the first request.
  expect_error(accessCopernicus(vars = "SST", dates = future_date, bounding_box = bb),
               "have not happened yet")
  expect_error(accessHYCOM(vars = "SST", dates = future_date, bounding_box = bb),
               "have not happened yet")
  expect_error(accessCCMP(vars = "WSPD", dates = future_date, bounding_box = bb),
               "have not happened yet")
  expect_error(accessERDDAP(vars = "SST", dates = future_date, bounding_box = bb),
               "have not happened yet")
})

test_that("a future year/month window is refused too, not just explicit dates", {
  expect_error(
    accessCopernicus(vars = "SST", years = future_year, months = 1, bounding_box = bb),
    "have not happened yet")
})

test_that("the guard does not refuse the present", {
  # The point is to catch dates that cannot exist, not to narrow what can be
  # asked for. A window ending today is legitimate and must survive the check.
  this_year <- as.integer(format(Sys.Date(), "%Y"))
  expect_null(stop_if_future(seq(as.Date(paste0(this_year, "-01-01")),
                                 Sys.Date(), by = "month"), "Test"))
})
