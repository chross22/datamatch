# CEFI is read over OPeNDAP, so network tests are skipped by default. The rest
# checks what would otherwise fail quietly: the unit conversions, which are the
# only thing making a CEFI CHL comparable to anyone else's, and the several
# things this source refuses on purpose.

test_that("every CEFI entry is fully specified", {
  catalog <- cefi_variables()

  expect_gt(length(catalog), 0)
  for (name in names(catalog)) {
    entry <- catalog[[name]]
    for (field in c("variable", "label", "units", "description")) {
      expect_true(nzchar(entry[[field]] %||% ""),
                  info = paste(name, "is missing", field))
    }
    expect_true(is.numeric(entry$scale) && entry$scale > 0,
                info = paste(name, "has no usable scale"))
    expect_true(is.logical(entry$daily), info = paste(name, "daily"))
  }
})

test_that("CEFI reuses the shared names, with matching units", {
  # The whole premise is that a covariate arrives in a column of the same name
  # whichever source supplied it. That only means anything if the units match,
  # which for four CEFI variables takes a conversion - so this is the test that
  # catches a conversion being dropped.
  shared <- intersect(names(cefi_variables()), names(copernicus_variables()))
  expect_true(all(c("SST", "SSS", "BOTT", "BOTS", "SSH", "MLD", "SIC",
                    "CHL", "NO3", "PO4", "O2", "PH", "UO", "VO") %in% shared))

  for (name in shared) {
    expect_equal(cefi_variables()[[name]]$units,
                 copernicus_variables()[[name]]$units,
                 info = paste(name, "has different units in the two catalogs"))
  }
})

test_that("the converted variables are the ones that need converting", {
  catalog <- cefi_variables()

  # COBALT writes chlorophyll in kg/m3 and the nutrients in mol/m3, where this
  # package uses mg/m3 and mmol/m3. Pinned because a scale silently reverting
  # to 1 would put CHL six orders of magnitude out in a column that still looks
  # like chlorophyll.
  expect_equal(catalog$CHL$scale, 1e6)
  for (name in c("NO3", "PO4", "O2")) {
    expect_equal(catalog[[name]]$scale, 1000, info = name)
  }
  expect_equal(catalog$BOTO2$scale, 1e6)

  # Everything else is already in the package's units.
  unconverted <- c("SST", "SSS", "BOTT", "BOTS", "SSH", "MLD", "SIC", "UO",
                   "VO", "PH", "PCO2", "PHYC", "MESOZOO")
  for (name in unconverted) {
    expect_equal(catalog[[name]]$scale, 1, info = name)
  }
})

test_that("BOTS from CEFI is published rather than derived", {
  # The Copernicus reanalysis has to fetch ~50 levels and keep the deepest wet
  # one, and reports the depth it used. CEFI publishes sob outright, so there
  # is nothing to derive and no BOTS_depth to return.
  expect_equal(cefi_variables()$BOTS$variable, "sob")
  expect_null(cefi_variables()$BOTS$derived)
  expect_match(cefi_variables()$BOTS$description, "publishes this directly")
})

test_that("a daily request for a monthly-only variable says what is daily", {
  bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

  # The NWA12 hindcast saves everything monthly and only biogeochemistry daily.
  # Left unchecked this fetches nothing and joins to nothing.
  expect_error(accessCEFI(vars = "SST", frequency = "daily",
                          dates = "2015-06-15", bounding_box = bb),
               "saves no daily SST")
  expect_error(accessCEFI(vars = "SST", frequency = "daily",
                          dates = "2015-06-15", bounding_box = bb),
               "Available daily: CHL")

  # The ones that are daily are not refused.
  for (name in c("CHL", "NO3", "PH", "PCO2", "PHYC", "MESOZOO", "BOTO2")) {
    expect_true(cefi_variables()[[name]]$daily, info = name)
  }
})

test_that("asking CEFI for PP explains why it has none", {
  bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

  # intpp is a water-column integral in mol/m2/s and the package's PP is a
  # volumetric rate in mg/m2/day. Sharing the name would make a nonsense of any
  # comparison, so a bare "not a CEFI variable" is not enough.
  expect_error(accessCEFI(vars = "PP", years = 2015, months = 6,
                          bounding_box = bb),
               "Not CEFI variables: PP")
  expect_error(accessCEFI(vars = "PP", years = 2015, months = 6,
                          bounding_box = bb),
               "intpp")
})

test_that("the experiments that cannot be read are refused with the reason", {
  bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
  known <- cefi_experiments()

  expect_true(known$hindcast$readable)
  expect_true(known$decadal_forecast$readable)

  # The seasonal forecast is not a gap in this package's coverage but a
  # limitation of the server: DAP2 cannot represent its 64-bit coordinate, and
  # reading it over DAP4 crashes R outright. Refusing beats segfaulting.
  expect_error(accessCEFI(vars = "SST", years = 2025, months = 6,
                          bounding_box = bb, experiment = "seasonal_forecast"),
               "cannot be read through this package")
  expect_error(accessCEFI(vars = "SST", years = 2025, months = 6,
                          bounding_box = bb, experiment = "seasonal_forecast"),
               "fileServer")

  for (name in c("seasonal_forecast", "seasonal_reforecast",
                 "long_term_projection", "multi_decadal_outlook")) {
    expect_false(known[[name]]$readable, info = name)
    expect_true(nzchar(known[[name]]$why), info = name)
  }
})

test_that("a forecast will not guess an initialisation or a member", {
  bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

  # Sixty initialisations cover any given year, and each holds ten members whose
  # average is a modelling decision. Both are questions about the analysis, so
  # neither is defaulted.
  expect_error(
    suppressWarnings(accessCEFI(vars = "SST", years = 1985, months = 6,
                                bounding_box = bb,
                                experiment = "decadal_forecast")),
    "`init` is required")
  expect_error(
    suppressWarnings(accessCEFI(vars = "SST", years = 1985, months = 6,
                                bounding_box = bb,
                                experiment = "decadal_forecast",
                                init = "198001")),
    "`member` is required")

  # And it says on every call that it is experimental.
  expect_warning(
    try(accessCEFI(vars = "SST", years = 1985, months = 6, bounding_box = bb,
                   experiment = "decadal_forecast"), silent = TRUE),
    "experimental")

  # The hindcast is a single run and takes neither.
  expect_error(accessCEFI(vars = "SST", years = 2015, months = 6,
                          bounding_box = bb, member = 1),
               "single run")
})

test_that("contiguous runs group indices without reading across gaps", {
  # A scattered handful of steps should be one request per stretch, not one per
  # step and not one spanning the whole record.
  expect_equal(unname(lapply(contiguous_runs(c(3, 1, 2)), as.integer)),
               list(1:3))
  expect_equal(unname(lapply(contiguous_runs(c(1, 2, 5, 6, 9)), as.integer)),
               list(1:2, 5:6, 9L))
  expect_equal(contiguous_runs(integer(0)), list())

  # Duplicates are a real case: several dates in one month name one field.
  expect_equal(unname(lapply(contiguous_runs(c(4, 4, 5)), as.integer)),
               list(4:5))
})

test_that("a member key survives the single-run case", {
  # as.character(NA_integer_) is NA_character_, which cannot name a list
  # element. The hindcast carries NA where a forecast carries a member number.
  expect_equal(member_key(NA_integer_), "single")
  expect_equal(member_key(3L), "3")
})

test_that("the source tag records the release rather than the alias", {
  # `latest` is the right default and a useless thing to record: two fetches a
  # year apart would carry the same tag and different numbers.
  expect_equal(
    cefi_release_of("tos.nwa.full.hcast.monthly.regrid.r20250715.199301-202312.nc"),
    "r20250715")
  expect_equal(cefi_release_of("no-release-here.nc", fallback = "latest"),
               "latest")
})

test_that("a variable is matched on the whole leading segment", {
  # `tos` must not match `tossq`, the squared field beside it, which is a
  # different quantity and would read without complaint.
  files <- c("tos.nwa.full.hcast.monthly.regrid.r20250715.199301-202312.nc",
             "tossq.nwa.full.hcast.monthly.regrid.r20250715.199301-202312.nc")

  expect_match(cefi_file_for(files, "tos"), "^tos\\.")
  expect_match(cefi_file_for(files, "tossq"), "^tossq\\.")
  expect_true(is.na(cefi_file_for(files, "sos")))
})

test_that("a forecast file is chosen by its initialisation", {
  files <- c("tos.nwa.full.dc_fcast.monthly.regrid.r20250925.enss.i198001.nc",
             "tos.nwa.full.dc_fcast.monthly.regrid.r20250925.enss.i198101.nc")

  expect_match(cefi_file_for(files, "tos", init = "i198001"), "i198001")
  expect_true(is.na(cefi_file_for(files, "tos", init = "i199901")))
})

test_that("the dictionary describes itself rather than FVCOM", {
  dictionary <- cefi_dictionary()

  expect_s3_class(dictionary, "datamatch_dictionary")
  expect_equal(attr(dictionary, "datamatch_family"), "cefi")
  expect_setequal(as.data.frame(dictionary)$name, names(cefi_variables()))

  printed <- paste(utils::capture.output(print(dictionary)), collapse = "\n")
  expect_match(printed, "CEFI variables available by name")
  expect_false(grepl("FVCOM", printed, fixed = TRUE))
  expect_match(printed, "cefi_dictionary")
})

test_that("a real fetch returns the documented shape", {
  skip_if_no_network()

  bb <- list(xmin = -70, xmax = -68, ymin = 42, ymax = 43)
  env <- accessCEFI(vars = c("SST", "BOTT", "BOTS", "CHL"), years = 2015,
                    months = 6:7, bounding_box = bb)

  expect_s3_class(env, "sf")
  expect_true(all(c("SST", "BOTT", "BOTS", "CHL", "YEAR", "MONTH", "DAY") %in%
                    names(env)))
  expect_equal(attr(env, "datamatch_step"), "month")
  expect_match(source_of(env), "^cefi:NWA12-hindcast-r[0-9]{8}$")

  # Monthly fields are stamped on the month, as every monthly source here is.
  expect_equal(sort(unique(env$MONTH)), c(6L, 7L))
  expect_equal(unique(env$DAY), 1L)

  # Gulf of Maine in early summer. Wide bounds - this is checking the units
  # survived the conversion, not the model.
  expect_true(all(env$SST > 0 & env$SST < 30, na.rm = TRUE))
  expect_true(all(env$BOTS > 25 & env$BOTS < 38, na.rm = TRUE))
  expect_true(all(env$CHL > 0 & env$CHL < 100, na.rm = TRUE))

  # No BOTS_depth: CEFI publishes sea-floor salinity rather than deriving it.
  expect_false("BOTS_depth" %in% names(env))
})

test_that("daily biogeochemistry reads on the days asked for", {
  skip_if_no_network()

  bb <- list(xmin = -70, xmax = -68, ymin = 42, ymax = 43)
  bgc <- accessCEFI(vars = c("CHL", "NO3", "PH"), frequency = "daily",
                    dates = c("2015-06-15", "2015-07-20"), bounding_box = bb)

  expect_equal(attr(bgc, "datamatch_step"), "day")
  expect_equal(sort(unique(bgc$DAY)), c(15L, 20L))
  expect_true(all(bgc$PH > 7 & bgc$PH < 9, na.rm = TRUE))
})

test_that("a box outside the domain is refused, not returned empty", {
  skip_if_no_network()

  # CEFI is regional. An empty join is the failure this is here to prevent.
  expect_error(accessCEFI(vars = "SST", years = 2015, months = 6,
                          bounding_box = list(xmin = 100, xmax = 110,
                                              ymin = 10, ymax = 20)),
               "selects no CEFI cells")
})

test_that("each ensemble member carries its own source tag", {
  skip_if_no_network()

  bb <- list(xmin = -70, xmax = -68, ymin = 42, ymax = 43)
  forecast <- suppressWarnings(
    accessCEFI(vars = "SST", years = 1985, months = 6, bounding_box = bb,
               experiment = "decadal_forecast", init = "198001",
               member = c(1, 2)))

  # Two members are two realisations, not two copies, so a row has to say which
  # it came from rather than the object saying "one of these two".
  tags <- unique(row_sources(forecast))
  expect_length(tags, 2)
  expect_match(tags[1], "i198001-m01$")
  expect_match(tags[2], "i198001-m02$")
})
