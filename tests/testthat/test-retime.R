# Daily data over whole months, in the shape accessEnvDat() returns for a daily
# product. `value` is a function of the date, so period aggregates are known
# analytically.
daily_series <- function(months = 1:3, year = 2020L,
                         value = function(y, m, d) d,
                         cells = expand.grid(x = c(-70, -69.5), y = c(42, 42.5))) {
  out <- do.call(rbind, lapply(months, function(m) {
    n_days <- as.integer(lubridate::days_in_month(
      lubridate::ymd(paste(year, m, 1, sep = "-"))))
    do.call(rbind, lapply(seq_len(n_days), function(d) {
      g <- cells
      g$V <- value(year, m, d)
      g$YEAR <- year
      g$MONTH <- as.integer(m)
      g$DAY <- as.integer(d)
      g
    }))
  }))
  sf::st_as_sf(out, coords = c("x", "y"), crs = 4326)
}

monthly_series <- function(months = 1:12, year = 2020L,
                           value = function(m) 10 + 5 * sin(2 * pi * m / 12)) {
  out <- do.call(rbind, lapply(months, function(m) {
    g <- expand.grid(x = c(-70, -69.5), y = c(42, 42.5))
    g$V <- value(m)
    g$YEAR <- year
    g$MONTH <- as.integer(m)
    g$DAY <- 1L
    g
  }))
  sf::st_as_sf(out, coords = c("x", "y"), crs = 4326)
}

test_that("daily data aggregates to the analytic monthly mean", {
  # V is day-of-month, so January's mean is mean(1:31).
  monthly <- upscale_time(daily_series(months = 1), to = "month")

  expect_equal(unique(monthly$V), mean(1:31))
})

test_that("monthly data aggregates to the analytic annual mean", {
  annual <- upscale_time(monthly_series(value = function(m) 10 + m), to = "year")

  expect_equal(unique(annual$V), mean(11:22))
})

test_that("aggregated output is stamped so its resolution reads back correctly", {
  # detect_temporal_resolution() infers annual data from several years stamped on
  # one month, so the two have to agree on the convention or matchData() breaks
  # on anything this function returns.
  daily <- daily_series(months = 1:3)

  monthly <- upscale_time(daily, to = "month")
  expect_equal(unique(monthly$DAY), 1)
  expect_equal(detect_temporal_resolution(monthly), "month")

  two_years <- rbind(monthly_series(year = 2020L), monthly_series(year = 2021L))
  annual <- upscale_time(two_years, to = "year")
  expect_equal(unique(annual$MONTH), 1)
  expect_equal(unique(annual$DAY), 1)
  expect_equal(detect_temporal_resolution(annual), "year")
})

test_that("a partly downloaded period fails the coverage check", {
  # Four days of February is not a February mean, and the number alone does not
  # say so. The denominator is the days the month has, not the days fetched.
  daily <- daily_series(months = 1:2)
  partial <- daily[!(daily$MONTH == 2 & daily$DAY > 4), ]

  strict <- upscale_time(partial, to = "month")
  expect_true(all(is.na(strict$V[strict$MONTH == 2])))
  expect_false(any(is.na(strict$V[strict$MONTH == 1])))

  loose <- upscale_time(partial, to = "month", min_coverage = 0)
  expect_equal(unique(loose$V[loose$MONTH == 2]), mean(1:4))
})

test_that("keep_counts reports how many steps went into each value", {
  daily <- daily_series(months = 1:2)
  partial <- daily[!(daily$MONTH == 2 & daily$DAY > 4), ]

  out <- upscale_time(partial, to = "month", min_coverage = 0, keep_counts = TRUE)

  expect_true("V_n" %in% names(out))
  expect_equal(unique(out$V_n[out$MONTH == 1]), 31)
  expect_equal(unique(out$V_n[out$MONTH == 2]), 4)
})

test_that("methods other than the mean give the summary they name", {
  daily <- daily_series(months = 1)

  expect_equal(unique(upscale_time(daily, to = "month", method = "min")$V), 1)
  expect_equal(unique(upscale_time(daily, to = "month", method = "max")$V), 31)
  expect_equal(unique(upscale_time(daily, to = "month", method = "sum")$V), sum(1:31))
  expect_equal(unique(upscale_time(daily, to = "month", method = "median")$V),
               stats::median(1:31))
  expect_equal(unique(upscale_time(daily, to = "month", method = "sd")$V),
               stats::sd(1:31))
})

test_that("each cell keeps its own series", {
  # Two cells with different values must not be pooled into one aggregate.
  cells <- expand.grid(x = c(-70, -69.5), y = 42)
  daily <- daily_series(months = 1, cells = cells)
  daily$V <- daily$V + ifelse(sf::st_coordinates(daily)[, 1] == -70, 0, 100)

  monthly <- upscale_time(daily, to = "month")

  expect_equal(nrow(monthly), 2)
  expect_setequal(monthly$V, c(mean(1:31), mean(1:31) + 100))
})

test_that("step gives every fine step its own period's value", {
  # The trap this guards: interpolating between month midpoints would put the
  # first half of February on January's value.
  monthly <- monthly_series()

  daily <- downscale_time(monthly, to = "day", method = "step")

  for (m in 1:12) {
    in_month <- daily[daily$MONTH == m, ]
    expect_equal(length(unique(in_month$V)), 1)
    expect_equal(unique(in_month$V), unique(monthly$V[monthly$MONTH == m]))
  }
})

test_that("step preserves the period mean and linear does not", {
  # The documented reason step is the default. Interpolating monthly means to
  # daily values and averaging back up does not recover the months.
  monthly <- monthly_series()
  month_value <- vapply(1:12, function(m) unique(monthly$V[monthly$MONTH == m]),
                        numeric(1))

  daily_mean <- function(d) {
    vapply(1:12, function(m) {
      in_month <- d[d$MONTH == m, ]
      mean(in_month$V[!duplicated(in_month$DAY)])
    }, numeric(1))
  }

  by_step <- downscale_time(monthly, to = "day", method = "step")
  by_linear <- downscale_time(monthly, to = "day", method = "linear")

  expect_equal(daily_mean(by_step), month_value)
  expect_false(isTRUE(all.equal(daily_mean(by_linear), month_value)))
})

test_that("downscaled output covers every day and reads back as daily", {
  monthly <- monthly_series(months = 1:3)

  daily <- downscale_time(monthly, to = "day")

  expect_equal(detect_temporal_resolution(daily), "day")
  expect_setequal(unique(daily$DAY[daily$MONTH == 1]), 1:31)
  expect_setequal(unique(daily$DAY[daily$MONTH == 2]), 1:29)  # 2020 is a leap year
})

test_that("linear and spline produce smooth series that step does not", {
  monthly <- monthly_series()

  by_step <- downscale_time(monthly, to = "day", method = "step")
  by_linear <- downscale_time(monthly, to = "day", method = "linear")
  by_spline <- downscale_time(monthly, to = "day", method = "spline")

  # step introduces no value the source did not already hold; the smooth methods
  # fill in between them.
  expect_setequal(round(unique(by_step$V), 6), round(unique(monthly$V), 6))
  expect_gt(length(unique(round(by_linear$V, 6))), 100)
  expect_gt(length(unique(round(by_spline$V, 6))), 100)
})

test_that("annual data disaggregates to months", {
  annual <- rbind(
    monthly_series(months = 1, year = 2019L, value = function(m) 10),
    monthly_series(months = 1, year = 2020L, value = function(m) 20))

  monthly <- downscale_time(annual, to = "month")

  expect_setequal(unique(monthly$MONTH), 1:12)
  expect_equal(unique(monthly$V[monthly$YEAR == 2019]), 10)
})

test_that("extrapolate controls what happens beyond the outermost periods", {
  monthly <- monthly_series(months = 3:6)

  held <- downscale_time(monthly, to = "day", method = "linear", extrapolate = TRUE)
  cut <- downscale_time(monthly, to = "day", method = "linear", extrapolate = FALSE)

  # Before mid-March there is no second point to interpolate between.
  early <- cut$MONTH == 3 & cut$DAY < 10
  expect_true(all(is.na(cut$V[early])))
  expect_false(any(is.na(held$V[held$MONTH == 3 & held$DAY < 10])))
})

test_that("resampling the wrong way is refused and names the other function", {
  monthly <- monthly_series()
  daily <- daily_series(months = 1)

  expect_error(downscale_time(daily, to = "month"), "upscale_time")
  expect_error(upscale_time(monthly, to = "month"), "nothing to do")
})

test_that("categorical columns survive as factors", {
  monthly <- monthly_series()
  monthly$SRC <- factor(ifelse(monthly$MONTH < 7, "satellite", "model"),
                        levels = c("satellite", "model"))

  annual <- upscale_time(monthly, to = "year")
  expect_s3_class(annual$SRC, "factor")
  expect_setequal(levels(annual$SRC), c("satellite", "model"))

  daily <- downscale_time(monthly, to = "day")
  expect_s3_class(daily$SRC, "factor")
  # A month's source label must not be smeared across the year boundary.
  expect_true(all(as.character(daily$SRC[daily$MONTH == 1]) == "satellite"))
  expect_true(all(as.character(daily$SRC[daily$MONTH == 12]) == "model"))
})

test_that("a blanket method leaves categorical columns to a safe one", {
  monthly <- monthly_series()
  monthly$SRC <- factor(ifelse(monthly$MONTH < 7, "satellite", "model"))

  expect_no_error(upscale_time(monthly, to = "year", method = "mean"))
  expect_no_error(downscale_time(monthly, to = "day", method = "linear"))
})

test_that("naming a categorical with an impossible method is an error", {
  monthly <- monthly_series()
  monthly$SRC <- factor(ifelse(monthly$MONTH < 7, "satellite", "model"))

  expect_error(upscale_time(monthly, to = "year", method = c(SRC = "mean")),
               "not numeric")
  expect_error(downscale_time(monthly, to = "day", method = c(SRC = "linear")),
               "not numeric")
})

test_that("per-variable methods are applied per variable", {
  daily <- daily_series(months = 1)
  daily$W <- daily$V

  out <- upscale_time(daily, to = "month", method = c(V = "min", W = "max"))

  expect_equal(unique(out$V), 1)
  expect_equal(unique(out$W), 31)
})

test_that("unknown methods and columns are reported", {
  daily <- daily_series(months = 1)

  expect_error(upscale_time(daily, to = "month", method = "linear"), "Unknown method")
  expect_error(downscale_time(monthly_series(), to = "day", method = "mean"),
               "Unknown method")
  expect_error(upscale_time(daily, to = "month", vars = "NOPE"), "NOPE")
})

test_that("missing values are skipped rather than poisoning the aggregate", {
  daily <- daily_series(months = 1)
  daily$V[daily$DAY %in% 1:5] <- NA

  out <- upscale_time(daily, to = "month", min_coverage = 0)

  expect_equal(unique(out$V), mean(6:31))
})

# ---- hourly to daily --------------------------------------------------------

# Hourly data in the shape accessEnvDat(frequency = "hourly") returns: the daily
# calendar plus an HOUR column.
hourly_series <- function(days = 1:2, month = 6L, year = 2015L,
                          value = function(h) h,
                          cells = expand.grid(x = c(-70, -69.5), y = c(42, 42.5))) {
  out <- do.call(rbind, lapply(days, function(d) {
    do.call(rbind, lapply(0:23, function(h) {
      g <- cells
      g$V <- value(h)
      g$YEAR <- year
      g$MONTH <- month
      g$DAY <- as.integer(d)
      g$HOUR <- as.integer(h)
      g
    }))
  }))
  sf::st_as_sf(out, coords = c("x", "y"), crs = 4326)
}

test_that("hourly data is recognised as hourly", {
  hourly <- hourly_series()

  expect_equal(detect_temporal_resolution(hourly), "hour")
  # HOUR is a time stamp, not a covariate. Averaged across a day it would give
  # 11.5 in a column that looks like a measurement.
  expect_equal(covariate_columns(hourly), "V")
})

test_that("hourly aggregates to daily means", {
  daily <- upscale_time(hourly_series(), to = "day")

  # Four cells over two days, and the mean of 0:23.
  expect_equal(nrow(daily), 8)
  expect_equal(unique(daily$V), mean(0:23))

  # HOUR is consumed rather than carried through - it is the axis being
  # aggregated away - and the result reads back as daily.
  expect_false("HOUR" %in% names(daily))
  expect_setequal(names(daily), c("YEAR", "MONTH", "DAY", "V", "geometry"))
  expect_equal(detect_temporal_resolution(daily), "day")
})

test_that("a partly-fetched day fails the coverage check", {
  # Six hours of a 24-hour day is not a daily mean, and nothing in the number
  # says so. The denominator is the 24 hours the day *has*.
  partial <- hourly_series()
  partial <- partial[partial$HOUR < 6, ]

  expect_true(all(is.na(upscale_time(partial, to = "day")$V)))
  expect_equal(unique(upscale_time(partial, to = "day", min_coverage = 0)$V),
               mean(0:5))
})

test_that("hourly can be aggregated past daily", {
  monthly <- upscale_time(hourly_series(days = 1:30), to = "month",
                          min_coverage = 0)

  expect_equal(nrow(monthly), 4)
  expect_equal(unique(monthly$V), mean(0:23))
})

test_that("aggregating to a step at or below the source is refused", {
  expect_error(upscale_time(hourly_series(), to = "day", vars = "V") |>
                 upscale_time(to = "day"),
               "finer than|same as")
  # And monthly data cannot be aggregated to days.
  expect_error(upscale_time(monthly_series(), to = "day"), "finer than")
})
