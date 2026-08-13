# ERDDAP is reached over HTTPS, so network tests are opt-in. The rest checks
# what fails quietly: the time-range snapping, and what is refused up front.

test_that("every ERDDAP dataset entry is fully specified", {
  catalog <- erddap_datasets()

  expect_gt(length(catalog), 0)
  for (name in names(catalog)) {
    spec <- catalog[[name]]
    for (field in c("server", "dataset_id", "label", "reference")) {
      expect_true(nzchar(spec[[field]] %||% ""),
                  info = paste(name, "is missing", field))
    }
    expect_true(grepl("^https://", spec$server), info = name)
    expect_true(is.logical(spec$has_altitude), info = name)
    # Every variable must carry units, or a shared column name means two things.
    expect_setequal(names(spec$units), names(spec$variables))
  }
})

test_that("ERDDAP reuses the shared names for the same quantities", {
  mur <- erddap_datasets()$MUR
  expect_true("SST" %in% names(mur$variables))
  expect_equal(unname(mur$units["SST"]), copernicus_variables()$SST$units)

  chl <- erddap_datasets()$VIIRSCHL
  expect_true("CHL" %in% names(chl$variables))
  expect_equal(unname(chl$units["CHL"]), copernicus_variables()$CHL$units)
})

test_that("an unknown dataset or variable is refused before connecting", {
  bb <- list(xmin = -69, xmax = -68.5, ymin = 43, ymax = 43.5)

  expect_error(accessERDDAP(vars = "SST", dates = "2015-06-15",
                            bounding_box = bb, dataset = "nope"),
               "Unknown ERDDAP dataset")
  # And it points at the escape hatch, since ERDDAP hosts far more than ships.
  expect_error(accessERDDAP(vars = "SST", dates = "2015-06-15",
                            bounding_box = bb, dataset = "nope"),
               "erddap_dataset")
  expect_error(accessERDDAP(vars = c("SST", "CHL"), dates = "2015-06-15",
                            bounding_box = bb),
               "Not variables of MUR: CHL")
})

test_that("days outside a dataset's record are refused or warned about", {
  bb <- list(xmin = -69, xmax = -68.5, ymin = 43, ymax = 43.5)

  # MUR begins in June 2002.
  expect_error(accessERDDAP(vars = "SST", dates = "1999-06-15",
                            bounding_box = bb),
               "every requested day is outside it")
  # VIIRSCHL2018 ended in July 2022, and its end date is known rather than open.
  expect_error(accessERDDAP(vars = "CHL", dates = "2024-06-15",
                            bounding_box = bb, dataset = "VIIRSCHL2018"),
               "every requested day is outside it")

  expect_error(accessERDDAP(vars = "SST", bounding_box = bb),
               "`years` and `months` are required")
  expect_error(accessERDDAP(vars = "SST", years = 2015, months = 6,
                            dates = "2015-06-15", bounding_box = bb),
               "already names which days")
  expect_error(accessERDDAP(vars = "SST", dates = "2015-06-15",
                            bounding_box = list(xmin = -69, xmax = -68)),
               "bounding_box is missing")
})

test_that("a dataset spec must carry a server and an id", {
  bb <- list(xmin = -69, xmax = -68.5, ymin = 43, ymax = 43.5)

  expect_error(accessERDDAP(vars = "SST", dates = "2015-06-15",
                            bounding_box = bb,
                            dataset = list(dataset_id = "jplMURSST41")),
               "must carry `server` and `dataset_id`")
})

test_that("the .das parser reads variables, units and the time range", {
  # The real format, so the parser is exercised without a server. This is the
  # half that would fail silently: a format change produces an empty catalog
  # rather than an error.
  das <- c("Attributes {", "  time {",
           '    String units "seconds since 1970-01-01T00:00:00Z";',
           "    Float64 actual_range 1.022922e+9, 1.7865252e+9;", "  }",
           "  latitude {", '    String units "degrees_north";',
           "    Float32 actual_range -89.99, 89.99;", "  }",
           "  longitude {", '    String units "degrees_east";', "  }",
           "  analysed_sst {", '    String units "degree_C";', "  }", "}")

  parsed <- erddap_parse_das(das)

  expect_true(all(c("time", "latitude", "longitude", "analysed_sst") %in%
                    names(parsed)))
  expect_equal(parsed$analysed_sst$units, "degree_C")
  expect_equal(parsed$latitude$actual_range, c(-89.99, 89.99), tolerance = 1e-6)
  expect_length(parsed$time$actual_range, 2)

  # The time range is what start/end are derived from, so it must decode to the
  # dates the catalog claims for MUR.
  span <- as.Date(as.POSIXct(parsed$time$actual_range, origin = "1970-01-01",
                             tz = "UTC"))
  expect_equal(span[1], as.Date("2002-06-01"))
})

# ---- network ----------------------------------------------------------------

test_that("MUR returns the documented shape at its stated resolution", {
  skip_if_no_network()

  bb <- list(xmin = -69, xmax = -68.5, ymin = 43, ymax = 43.5)
  mur <- try(accessERDDAP(vars = c("SST", "SST_ERROR"), dates = "2015-06-15",
                          bounding_box = bb), silent = TRUE)
  skip_if(inherits(mur, "try-error"), "ERDDAP unreachable")

  expect_s3_class(mur, "sf")
  expect_equal(attr(mur, "datamatch_step"), "day")
  expect_equal(source_of(mur), "erddap:MUR")

  # 0.01 degrees over half a degree each way is about 51 x 51 cells - far finer
  # than any model here, which is the reason to reach for it.
  expect_gt(nrow(mur), 2000)
  expect_true(all(mur$SST > 0 & mur$SST < 30))

  coords <- sf::st_coordinates(mur)
  expect_true(all(coords[, 1] >= -69 & coords[, 1] <= -68.5))
})

test_that("only the requested day is returned, despite griddap snapping", {
  skip_if_no_network()

  bb <- list(xmin = -69, xmax = -68.8, ymin = 43, ymax = 43.2)
  mur <- try(accessERDDAP(vars = "SST", dates = "2015-06-15",
                          bounding_box = bb), silent = TRUE)
  skip_if(inherits(mur, "try-error"), "ERDDAP unreachable")

  # griddap snaps a range's endpoints to the nearest step, so asking for
  # 00:00:00-23:59:59 also returns the *next* day's 09:00 field. If that were
  # kept, every cell would appear twice and the second value would be tomorrow's.
  expect_setequal(unique(mur$DAY), 15L)
  expect_equal(anyDuplicated(sf::st_as_text(sf::st_geometry(mur))), 0)
})

test_that("VIIRS chlorophyll reads and lands in a CHL column", {
  skip_if_no_network()

  bb <- list(xmin = -69, xmax = -68.5, ymin = 43, ymax = 43.5)
  chl <- try(accessERDDAP(vars = "CHL", dates = "2022-06-15",
                          bounding_box = bb, dataset = "VIIRSCHL"),
             silent = TRUE)
  skip_if(inherits(chl, "try-error"), "ERDDAP unreachable")

  expect_true("CHL" %in% names(chl))
  expect_equal(source_of(chl), "erddap:VIIRSCHL")
  # Gulf of Maine summer chlorophyll: order 0.1-10 mg/m3.
  expect_true(all(chl$CHL > 0.01 & chl$CHL < 50))
})
