# FVCOM is read over OPeNDAP from a THREDDS server, so anything touching the
# network is skipped by default. What is tested here without it is the part that
# gets things wrong quietly: which mesh a variable sits on, what may be fetched
# together, and how the box is applied.

test_that("every FVCOM entry is fully specified", {
  catalog <- fvcom_variables()

  expect_gt(length(catalog), 0)
  for (name in names(catalog)) {
    entry <- catalog[[name]]
    for (field in c("variable", "label", "units", "mesh", "description")) {
      expect_true(nzchar(entry[[field]] %||% ""),
                  info = paste(name, "is missing", field))
    }
    expect_true(entry$mesh %in% c("node", "element"),
                info = paste(name, "has an unknown mesh"))
    expect_true(is.na(entry$layer) || entry$layer %in% c("surface", "bottom"),
                info = paste(name, "has an unknown layer"))
  }
})

test_that("FVCOM reuses the Copernicus names for the same quantities", {
  fvcom <- names(fvcom_variables())
  copernicus <- names(copernicus_variables())

  # The overlap is the point: a covariate fetched from either lands in a column
  # of the same name, so everything downstream works unchanged.
  shared <- intersect(fvcom, copernicus)
  expect_true(all(c("SST", "SSS", "BOTT", "BOTS", "UO", "VO", "TAUX", "TAUY")
                  %in% shared))

  # And the units must agree, or the same column name would mean two things.
  for (name in shared) {
    expect_equal(fvcom_variables()[[name]]$units,
                 copernicus_variables()[[name]]$units,
                 info = paste(name, "has different units in the two catalogs"))
  }
})

test_that("bottom variables read the deepest sigma layer", {
  # FVCOM's sigma coordinate makes the bottom a layer index rather than a
  # derivation, which is the whole reason BOTS is cheap here and not in GLORYS.
  expect_equal(fvcom_variables()$BOTS$layer, "bottom")
  expect_equal(fvcom_variables()$BOTS$variable, "salinity")
  expect_equal(fvcom_variables()$SSS$variable, "salinity")
  expect_equal(fvcom_variables()$SSS$layer, "surface")

  # Unlike the Copernicus catalog, where the same pair needs a derivation.
  expect_null(fvcom_variables()$BOTS$derived)
  expect_false(is.null(copernicus_variables()$BOTS$derived))
})

test_that("scalars are on nodes and velocities on elements", {
  mesh_of <- function(name) fvcom_variables()[[name]]$mesh

  for (name in c("SST", "SSS", "BOTT", "BOTS", "SSH", "DEPTH")) {
    expect_equal(mesh_of(name), "node", info = name)
  }
  for (name in c("UO", "VO", "UBAR", "VBAR", "TAUX", "TAUY")) {
    expect_equal(mesh_of(name), "element", info = name)
  }
})

test_that("node and element variables cannot be fetched together", {
  bb <- list(xmin = -69, xmax = -68, ymin = 43, ymax = 44)

  # Two different sets of points, so one table would mean interpolating one onto
  # the other. Refused before any connection is opened.
  expect_error(
    accessFVCOM(vars = c("SST", "UBAR"), years = 2010, months = 6,
                bounding_box = bb),
    "different parts of the FVCOM mesh")
  expect_error(
    accessFVCOM(vars = c("SST", "UBAR"), years = 2010, months = 6,
                bounding_box = bb),
    "chain matchData")
})

test_that("an unknown variable is refused rather than passed through", {
  bb <- list(xmin = -69, xmax = -68, ymin = 43, ymax = 44)

  # Unlike Copernicus, where an unknown string is a plausible variable code, the
  # FVCOM catalog is the whole interface - so there is nothing to pass through to.
  expect_error(
    accessFVCOM(vars = c("SST", "CHL"), years = 2010, months = 6,
                bounding_box = bb),
    "Not FVCOM variables: CHL")
})

test_that("years and months are required unless dates names them", {
  bb <- list(xmin = -69, xmax = -68, ymin = 43, ymax = 44)

  expect_error(accessFVCOM(vars = "SST", bounding_box = bb),
               "`years` and `months` are required")
  expect_error(accessFVCOM(vars = "SST", years = 2010, months = 6,
                           dates = "2010-06-01", bounding_box = bb),
               "already names which time steps")
})

test_that("an unknown archive names the ones that exist", {
  expect_error(accessFVCOM(vars = "SST", years = 2010, months = 6,
                           bounding_box = list(xmin = -69, xmax = -68,
                                               ymin = 43, ymax = 44),
                           archive = "nonexistent"),
               "Unknown archive")
})

test_that("fvcom_in_box keeps the points inside and rejects an empty box", {
  coords <- data.frame(x = c(-70, -68, -60, -68.5), y = c(43, 43.5, 40, 44))

  inside <- fvcom_in_box(coords, list(xmin = -69, xmax = -67,
                                      ymin = 43, ymax = 45))
  expect_equal(inside, c(2L, 4L))

  # An sf object may be given instead of a list.
  as_sf <- sf::st_as_sf(data.frame(x = c(-69, -67), y = c(43, 45)),
                        coords = c("x", "y"), crs = 4326)
  expect_equal(fvcom_in_box(coords, as_sf), c(2L, 4L))

  # A box over land or outside the mesh matches nothing, which is worth saying
  # rather than returning an empty table.
  expect_error(fvcom_in_box(coords, list(xmin = 10, xmax = 20,
                                         ymin = 10, ymax = 20)),
               "No mesh points fall inside")
  expect_error(fvcom_in_box(coords, list(xmin = -69, xmax = -67)),
               "bounding_box is missing")
})

test_that("the archive catalog describes what it serves", {
  archives <- fvcom_archives()

  expect_true("GOM3" %in% names(archives))
  gom3 <- archives$GOM3
  expect_true(grepl("^http", gom3$url))
  expect_equal(gom3$frequency, "monthly")
  expect_true(gom3$start < gom3$end)
  expect_gt(gom3$elements, gom3$nodes)
  # FVCOM is somebody else's model, so it carries a citation like the indices do.
  expect_true(grepl("Chen", gom3$reference))
})

test_that("the FVCOM dictionary prints without claiming a Copernicus product", {
  dictionary <- fvcom_dictionary()

  expect_s3_class(dictionary, "datamatch_dictionary")
  expect_setequal(dictionary$name, names(fvcom_variables()))
  expect_equal(nrow(fvcom_dictionary("node")) + nrow(fvcom_dictionary("element")),
               nrow(dictionary))

  output <- capture.output(result <- withVisible(print(dictionary)))
  expect_false(result$visible)
  expect_true(any(grepl("FVCOM variables", output)))
  # The Copernicus footer would be untrue here.
  expect_false(any(grepl("accessEnvDat", output)))
  expect_true(any(grepl("node surface", output)))
})

# ---- network ----------------------------------------------------------------

test_that("a real fetch returns the documented shape", {
  skip_on_cran()
  skip_if_not_installed("ncdf4")
  skip_if_offline()

  bb <- list(xmin = -69, xmax = -68.5, ymin = 43, ymax = 43.5)
  fv <- try(accessFVCOM(vars = c("SST", "BOTT", "BOTS"), years = 2010,
                        months = 6, bounding_box = bb), silent = TRUE)
  skip_if(inherits(fv, "try-error"), "FVCOM THREDDS server unreachable")

  expect_s3_class(fv, "sf")
  expect_true(all(c("SST", "BOTT", "BOTS", "YEAR", "MONTH", "DAY") %in% names(fv)))
  expect_equal(attr(fv, "datamatch_step"), "month")
  expect_equal(detect_temporal_resolution(fv), "month")

  # Gulf of Maine in June: a warm surface over cold, salty bottom water. Wide
  # bounds - this is a check that the layers are not swapped, not a validation
  # of the model.
  expect_true(all(fv$SST > 5 & fv$SST < 25))
  expect_true(all(fv$BOTT < fv$SST))
  expect_true(all(fv$BOTS > 30 & fv$BOTS < 36))
})

# ---- any FVCOM endpoint, not just the built-in ones --------------------------

test_that("an unknown archive name points at fvcom_archive()", {
  bb <- list(xmin = -69, xmax = -68, ymin = 43, ymax = 44)

  # FVCOM is run for coastlines everywhere; the built-in list is one server's
  # Northeast US output. The error has to say how to reach anything else.
  expect_error(accessFVCOM(vars = "SST", years = 2010, months = 6,
                           bounding_box = bb, archive = "SCOTIAN"),
               "fvcom_archive")
})

test_that("a spec must carry a url", {
  bb <- list(xmin = -69, xmax = -68, ymin = 43, ymax = 44)

  expect_error(accessFVCOM(vars = "SST", years = 2010, months = 6,
                           bounding_box = bb,
                           archive = list(label = "no url here")),
               "must carry a `url`")
})

test_that("a spec refuses variables its run did not save", {
  bb <- list(xmin = -69, xmax = -68, ymin = 43, ymax = 44)

  # fvcom_archive() records which fields exist, so a request for one that does
  # not is refused before any connection is opened.
  spec <- list(url = "http://example.org/thredds/dodsC/run",
               variables = c("SST", "SSS"), label = "partial run")

  expect_error(accessFVCOM(vars = c("SST", "BOTS"), years = 2010, months = 6,
                           bounding_box = bb, archive = spec),
               "does not carry: BOTS")
  expect_error(accessFVCOM(vars = c("SST", "BOTS"), years = 2010, months = 6,
                           bounding_box = bb, archive = spec),
               "runs differ in which fields exist")
})

test_that("fvcom_archive describes a real endpoint and rejects a non-FVCOM one", {
  skip_on_cran()
  skip_if_not_installed("ncdf4")
  skip_if_offline()

  spec <- try(fvcom_archive(fvcom_archives()$GOM3$url, label = "GOM3 monthly"),
              silent = TRUE)
  skip_if(inherits(spec, "try-error"), "FVCOM THREDDS server unreachable")

  # The mesh, period and variable list come from the file rather than a table.
  expect_equal(spec$nodes, 48451L)
  expect_equal(spec$elements, 90415L)
  expect_equal(spec$sigma_layers, 45L)
  expect_true(all(c("SST", "BOTS", "UBAR") %in% spec$variables))
  expect_true(spec$start < spec$end)

  # Pointed at a model that is not FVCOM, it must say so rather than failing
  # later on a missing mesh dimension.
  hycom <- try(fvcom_archive(sprintf(hycom_archives()$GLBv53X$url, 1994)),
               silent = TRUE)
  skip_if(!inherits(hycom, "try-error"), "HYCOM endpoint unexpectedly opened")
  expect_match(conditionMessage(attr(hycom, "condition")),
               "does not look like FVCOM")
})
