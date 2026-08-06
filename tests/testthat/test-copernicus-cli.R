
test_that("the cache filename distinguishes requests that differ", {
  small <- list(xmin = -69, xmax = -68, ymin = 42, ymax = 43)
  large <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
  day <- as.Date("2018-06-01")
  name <- function(vars, bb, depth = c(0, 1)) {
    cache_filename("PROD", "DSET", day, vars, bb, depth)
  }

  # The bug this fixes: a file written for one variable over a small box was
  # reused for a request wanting two variables over a large one, which either
  # failed for the missing variable or silently returned the wrong area.
  expect_false(name("thetao", small) == name(c("thetao", "so"), small))
  expect_false(name(c("thetao", "so"), small) == name(c("thetao", "so"), large))
  expect_false(name("thetao", small) == name("thetao", small, depth = c(0, 50)))

  # And the same request has to hit the cache, whatever order it names its
  # variables in, or nothing is ever reused.
  expect_equal(name(c("so", "thetao"), large), name(c("thetao", "so"), large))

  # The dataset and date stay readable at the front so the cache can be browsed.
  expect_match(name("thetao", small), "^PROD_DSET_2018-06-01_")
  expect_match(name("thetao", small), "[.]nc$")
})

test_that("the hash is stable and looks like a hash", {
  expect_equal(short_hash("abc"), short_hash("abc"))
  expect_false(short_hash("abc") == short_hash("abd"))
  expect_match(short_hash("abc"), "^[0-9a-f]{8}$")
  expect_match(short_hash(""), "^[0-9a-f]{8}$")
})
