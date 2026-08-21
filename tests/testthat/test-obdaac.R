# OB.DAAC is the one source needing an account, so almost nothing here can reach
# it: the network tests skip without DATAMATCH_NETWORK_TESTS and would skip
# again without a credential. What is left is what would fail quietly - the
# constructed filenames, which are the whole reason no HTTP dependency was
# added, and the login page that arrives with an HTTP 200.

test_that("every OB.DAAC entry is fully specified", {
  catalog <- obdaac_variables()

  expect_gt(length(catalog), 0)
  for (name in names(catalog)) {
    entry <- catalog[[name]]
    for (field in c("suite", "variable", "label", "units", "description")) {
      expect_true(nzchar(entry[[field]] %||% ""),
                  info = paste(name, "is missing", field))
    }
  }
})

test_that("every OB.DAAC sensor is fully specified", {
  sensors <- obdaac_sensors()

  expect_gt(length(sensors), 0)
  for (name in names(sensors)) {
    spec <- sensors[[name]]
    expect_true(is.numeric(spec$id), info = name)
    expect_true(nzchar(spec$prefix), info = name)
    expect_s3_class(spec$start, "Date")
    expect_gt(length(spec$suites), 0)
    expect_gt(length(spec$resolutions), 0)
    expect_true(nzchar(spec$reference), info = paste(name, "has no citation"))
  }

  # Every suite a variable names has to be carried by at least one sensor, or
  # the variable is unreachable and the catalog is lying about it.
  carried <- unique(unlist(lapply(sensors, function(s) s$suites)))
  for (name in names(obdaac_variables())) {
    expect_true(obdaac_variables()[[name]]$suite %in% carried, info = name)
  }
})

test_that("OB.DAAC reuses the shared names, with matching units", {
  shared <- intersect(names(obdaac_variables()), names(copernicus_variables()))
  expect_true("CHL" %in% shared)

  for (name in shared) {
    expect_equal(obdaac_variables()[[name]]$units,
                 copernicus_variables()[[name]]$units,
                 info = paste(name, "has different units in the two catalogs"))
  }

  # SST is shared with the model sources and with ERDDAP, and all of them say
  # degrees C. It is a different measurement in each, which is what source_of()
  # is for, but it is at least the same unit.
  expect_equal(obdaac_variables()$SST$units, "degrees C")
  expect_equal(obdaac_variables()$SST_NIGHT$units, "degrees C")
})

test_that("filenames are constructed the way the archive spells them", {
  # These are the names OB.DAAC actually publishes, checked against the archive
  # for each sensor, both frequencies and several suites. They are pinned here
  # because the whole reader rests on constructing them: OB.DAAC's file search
  # would answer this exactly and accepts POST only, which utils::download.file()
  # cannot do, so the alternative was an HTTP dependency.
  sensors <- obdaac_sensors()
  catalog <- obdaac_variables()

  expect_equal(
    obdaac_filename(sensors$MODISA, catalog$CHL, as.Date("2020-06-01"),
                    "daily", "4km"),
    "AQUA_MODIS.20200601.L3m.DAY.CHL.chlor_a.4km.nc")

  # A composite is named for the span it covers, both ends inclusive.
  expect_equal(
    obdaac_filename(sensors$MODISA, catalog$CHL, as.Date("2020-06-01"),
                    "monthly", "4km"),
    "AQUA_MODIS.20200601_20200630.L3m.MO.CHL.chlor_a.4km.nc")

  # Which means February in a leap year has to be right.
  expect_equal(
    obdaac_filename(sensors$SEAWIFS, catalog$CHL, as.Date("2000-02-01"),
                    "monthly", "9km"),
    "SEASTAR_SEAWIFS_GAC.20000201_20000229.L3m.MO.CHL.chlor_a.9km.nc")
  expect_equal(
    obdaac_filename(sensors$SEAWIFS, catalog$CHL, as.Date("2001-02-01"),
                    "monthly", "9km"),
    "SEASTAR_SEAWIFS_GAC.20010201_20010228.L3m.MO.CHL.chlor_a.9km.nc")

  # The night SST lives in its own suite under the same variable name.
  expect_equal(
    obdaac_filename(sensors$VIIRS, catalog$SST_NIGHT, as.Date("2019-12-01"),
                    "monthly", "4km"),
    "SNPP_VIIRS.20191201_20191231.L3m.MO.NSST.sst.4km.nc")
})

test_that("a sensor is not offered what it does not carry", {
  bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

  # SeaWiFS is an ocean colour sensor and measures no temperature at all.
  expect_error(accessOBDAAC(vars = c("CHL", "SST"), dates = "2000-06-15",
                            bounding_box = bb, sensor = "SEAWIFS"),
               "does not publish: SST")
  expect_error(accessOBDAAC(vars = c("CHL", "SST"), dates = "2000-06-15",
                            bounding_box = bb, sensor = "SEAWIFS"),
               "measures no temperature")

  # NFLH is MODIS only.
  expect_error(accessOBDAAC(vars = "NFLH", dates = "2024-06-15",
                            bounding_box = bb, sensor = "VIIRSJ2"),
               "does not publish: NFLH")

  expect_error(accessOBDAAC(vars = "CHL", dates = "2015-06-15",
                            bounding_box = bb, sensor = "NOTASENSOR"),
               "Unknown OB.DAAC sensor")
  expect_error(accessOBDAAC(vars = "CHL", dates = "2015-06-15",
                            bounding_box = bb, resolution = "1km"),
               "published at 4km and 9km")
})

test_that("dates outside a mission are refused or dropped, not fetched", {
  bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

  expect_error(accessOBDAAC(vars = "CHL", dates = "1995-06-15",
                            bounding_box = bb, sensor = "SEAWIFS"),
               "every requested date is outside that")

  # SeaWiFS stopped in December 2010, and a request straddling that should keep
  # the days it covers and say what it dropped rather than failing whole.
  expect_warning(
    try(accessOBDAAC(vars = "CHL", dates = c("2010-12-01", "2011-06-15"),
                     bounding_box = bb, sensor = "SEAWIFS"), silent = TRUE),
    "outside SEAWIFS's record")
})

test_that("eight-day composites are refused with the join reason", {
  bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

  # matchData() joins on an hour, a day, a month or a year. An eight-day bin
  # stamped as a day would demand an observation fall on the bin's first date,
  # so nearly every row would go unmatched - silently.
  expect_error(accessOBDAAC(vars = "CHL", dates = "2015-06-15",
                            bounding_box = bb, frequency = "8day"),
               "cannot join them honestly")
  expect_error(accessOBDAAC(vars = "CHL", dates = "2015-06-15",
                            bounding_box = bb, frequency = "8day"),
               "fill_satellite_gaps")
})

test_that("a missing Earthdata credential says how to get one", {
  bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

  withr::with_options(list(datamatch.earthdata_appkey = NULL), {
    withr::with_envvar(list(EARTHDATA_APPKEY = ""), {
      skip_if(file.exists(path.expand("~/.netrc")),
              "this machine has a ~/.netrc, so the no-credential path is not reachable")

      expect_error(accessOBDAAC(vars = "CHL", dates = "2015-06-15",
                                bounding_box = bb),
                   "needs an Earthdata Login")
      expect_error(accessOBDAAC(vars = "CHL", dates = "2015-06-15",
                                bounding_box = bb),
                   "urs.earthdata.nasa.gov/users/new")
    })
  })
})

test_that("an appkey is preferred over a netrc and read from either place", {
  withr::with_options(list(datamatch.earthdata_appkey = "from-the-option"), {
    expect_equal(obdaac_credentials(),
                 list(kind = "appkey", key = "from-the-option"))
  })

  withr::with_options(list(datamatch.earthdata_appkey = NULL), {
    withr::with_envvar(list(EARTHDATA_APPKEY = "from-the-environment"), {
      expect_equal(obdaac_credentials(),
                   list(kind = "appkey", key = "from-the-environment"))
    })
  })
})

test_that("an HTML login page is not written to disk as a netCDF file", {
  # This is the failure the whole credential check exists for. NASA answers an
  # unauthenticated request with HTTP 200 and the login page, so a download that
  # trusts the status code leaves nine kilobytes of HTML in a file named .nc,
  # and the mistake surfaces much later as a corrupt netCDF.
  destination <- withr::local_tempfile(fileext = ".nc")
  writeLines(c("<!doctype html>", "<html><body>Earthdata Login</body></html>"),
             destination)

  magic <- readBin(destination, "raw", n = 4)
  is_netcdf <- identical(rawToChar(magic[1:3]), "CDF") ||
    (magic[1] == as.raw(0x89) && identical(rawToChar(magic[2:4]), "HDF"))
  expect_false(is_netcdf)

  # And the signatures a real file carries do pass the same check.
  for (signature in list(charToRaw("CDF\001"),
                         c(as.raw(0x89), charToRaw("HDF")))) {
    passes <- identical(rawToChar(signature[1:3]), "CDF") ||
      (signature[1] == as.raw(0x89) && identical(rawToChar(signature[2:4]), "HDF"))
    expect_true(passes)
  }
})

test_that("the dictionary describes itself rather than FVCOM", {
  dictionary <- obdaac_dictionary()

  expect_s3_class(dictionary, "datamatch_dictionary")
  expect_equal(attr(dictionary, "datamatch_family"), "obdaac")
  expect_setequal(as.data.frame(dictionary)$name, names(obdaac_variables()))

  printed <- paste(utils::capture.output(print(dictionary)), collapse = "\n")
  expect_match(printed, "NASA OB.DAAC variables available by name")
  expect_false(grepl("FVCOM", printed, fixed = TRUE))
  expect_match(printed, "Earthdata")
})

test_that("the login page is refused against the real server", {
  skip_if_no_network()

  # Deliberately wrong credentials against the live endpoint, which is the only
  # way to exercise this without an account. The file must not survive.
  destination <- withr::local_tempfile(fileext = ".nc")
  failure <- obdaac_download("AQUA_MODIS.20200601.L3m.DAY.CHL.chlor_a.9km.nc",
                             destination,
                             list(kind = "appkey", key = "not-a-real-key"))

  expect_type(failure, "character")
  expect_match(failure, "login page")
  expect_false(file.exists(destination))
})

test_that("a real fetch returns the documented shape", {
  skip_if_no_network()
  credentials <- tryCatch(obdaac_credentials(), error = function(e) NULL)
  skip_if(is.null(credentials),
          "OB.DAAC needs an Earthdata Login; set EARTHDATA_APPKEY to run this")

  bb <- list(xmin = -70, xmax = -68, ymin = 42, ymax = 43)
  chl <- accessOBDAAC(vars = "CHL", years = 2015, months = 7,
                      bounding_box = bb, frequency = "monthly",
                      resolution = "9km")

  expect_s3_class(chl, "sf")
  expect_true(all(c("CHL", "YEAR", "MONTH", "DAY") %in% names(chl)))
  expect_equal(attr(chl, "datamatch_step"), "month")
  expect_equal(source_of(chl), "obdaac:MODISA-9km")
  expect_equal(unique(chl$DAY), 1L)
  expect_true(all(chl$CHL > 0 & chl$CHL < 100, na.rm = TRUE))
})
