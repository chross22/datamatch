
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

test_that("the client is asked to report errors, not silenced", {
  # QUIET suppresses the client's explanation as well as its chatter. An
  # out-of-range date then exits non-zero with no output at all, which leaves
  # accessCopernicus() promising "Client output:" and showing nothing.
  args <- build_copernicus_args(
    dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1D-m", vars = "thetao",
    bb = list(xmin = -70, xmax = -69, ymin = 42, ymax = 43),
    depth = c(0, 1), time = as.Date("2020-01-01"), ofile = "/tmp/x.nc")

  expect_equal(args[which(args == "--log-level") + 1], "ERROR")
  expect_false("QUIET" %in% args)
})

# A stand-in for the copernicusmarine client: a shell script that records each
# argument it receives on its own line, then writes the output file it was
# asked for. FAKE_CLIENT_FAIL makes it write half a file and exit non-zero.
local_fake_client <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(pattern = "fake client ", .local_envir = env)
  log <- file.path(dir, "args.log")
  script <- file.path(dir, "copernicusmarine")
  writeLines(c(
    "#!/bin/sh",
    paste0("log=", shQuote(log)),
    "for a in \"$@\"; do printf '%s\\n' \"$a\" >> \"$log\"; done",
    "while [ $# -gt 0 ]; do",
    "  case \"$1\" in",
    "    --output-directory) dir=\"$2\";;",
    "    --output-filename) file=\"$2\";;",
    "  esac",
    "  shift",
    "done",
    "if [ -n \"$FAKE_CLIENT_FAIL\" ]; then printf 'trunc' > \"$dir/$file\"; exit 1; fi",
    "printf 'complete' > \"$dir/$file\""
  ), script)
  Sys.chmod(script, "0755")
  withr::local_options(datamatch.copernicusmarine = script, .local_envir = env)
  list(dir = dir, log = log)
}

test_that("arguments reach the client whole, and are never run as commands", {
  skip_on_os("windows")
  client <- local_fake_client()
  cache <- withr::local_tempdir(pattern = "cache with space ")
  ofile <- file.path(cache, "a day.nc")
  marker <- file.path(tempdir(), paste0("injected-", Sys.getpid()))
  unlink(marker)

  # The bug: system2() pastes its arguments into a shell command, so the space
  # split the path in two and the semicolon ran a second command.
  download_copernicus_subset(
    dataset_id = paste0("ds;touch ", marker), vars = "thetao",
    bb = list(xmin = -70, xmax = -69, ymin = 42, ymax = 43),
    depth = c(0, 1), time = as.Date("2020-01-01"), ofile = ofile,
    tries = 1, wait = 0)

  received <- readLines(client$log)
  expect_false(file.exists(marker))
  expect_equal(received[which(received == "--dataset-id") + 1],
               paste0("ds;touch ", marker))
  expect_equal(received[which(received == "--output-filename") + 1], "a day.nc")
  expect_equal(readLines(ofile, warn = FALSE), "complete")
})

test_that("a failed download leaves no file to be mistaken for a cached one", {
  skip_on_os("windows")
  local_fake_client()
  withr::local_envvar(FAKE_CLIENT_FAIL = "1")
  cache <- withr::local_tempdir()
  ofile <- file.path(cache, "day.nc")

  expect_error(
    download_copernicus_subset(
      dataset_id = "ds", vars = "thetao",
      bb = list(xmin = -70, xmax = -69, ymin = 42, ymax = 43),
      depth = c(0, 1), time = as.Date("2020-01-01"), ofile = ofile,
      tries = 1, wait = 0),
    "failed after 1 attempt")

  # Neither the truncated file nor its working directory is left behind.
  expect_false(file.exists(ofile))
  expect_length(list.files(cache, all.files = TRUE, no.. = TRUE), 0)
})

test_that("the cache filename takes an sf bounding box", {
  bb <- list(xmin = -70, xmax = -69, ymin = 42, ymax = 43)
  box <- sf::st_as_sf(sf::st_as_sfc(sf::st_bbox(unlist(bb),
                                                crs = sf::st_crs(4326))))
  day <- as.Date("2018-06-01")

  expect_equal(cache_filename("P", "D", day, "thetao", box, c(0, 1)),
               cache_filename("P", "D", day, "thetao", bb, c(0, 1)))
})
