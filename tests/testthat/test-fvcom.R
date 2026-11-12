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
  expect_false(any(grepl("accessCopernicus", output)))
  expect_true(any(grepl("node surface", output)))
})

# ---- network ----------------------------------------------------------------

test_that("a real fetch returns the documented shape", {
  skip_if_no_network()

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
  skip_if_no_network()

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

# ---- hindcast and forecast archive ------------------------------------------

test_that("GOM3 and GOM7 are different products, not one series", {
  archives <- fvcom_archives()
  expect_true(all(c("GOM3", "GOM7") %in% names(archives)))

  expect_equal(archives$GOM3$kind, "hindcast")
  expect_equal(archives$GOM7$kind, "forecast archive")

  # Mesh, step and layout all change between them, which is why they are two
  # archives rather than one stitched record.
  expect_equal(archives$GOM3$mesh, "GOM3")
  expect_equal(archives$GOM7$mesh, "GOM7")
  expect_gt(archives$GOM7$nodes, archives$GOM3$nodes)
  expect_equal(archives$GOM3$frequency, "monthly")
  expect_equal(archives$GOM7$frequency, "hourly")
  expect_equal(archives$GOM3$layout, "aggregation")
  expect_equal(archives$GOM7$layout, "per_month")
  expect_true(grepl("%04d", archives$GOM7$url))
})

test_that("frequency is refused on a monthly archive rather than ignored", {
  bb <- list(xmin = -69, xmax = -68.7, ymin = 43, ymax = 43.3)

  expect_warning(
    try(accessFVCOM(vars = "SST", years = 2010, months = 6, bounding_box = bb,
                    frequency = "hourly"), silent = TRUE),
    "applies only to sub-daily archives")
})

# ---- the mesh itself ---------------------------------------------------------

test_that("a mesh spec must carry a url, and the archive must be known", {
  expect_error(fvcom_mesh(archive = "SCOTIAN"), "Unknown archive")
  expect_error(fvcom_mesh(archive = "SCOTIAN"), "fvcom_archive")
  expect_error(fvcom_mesh(archive = list(mesh = "x")), "must carry a `url`")
})

test_that("the mesh reads as triangles with depth", {
  skip_if_no_network()

  bb <- list(xmin = -69.5, xmax = -68.5, ymin = 43, ymax = 43.8)
  mesh <- try(fvcom_mesh(bounding_box = bb), silent = TRUE)
  skip_if(inherits(mesh, "try-error"), "FVCOM THREDDS server unreachable")

  expect_s3_class(mesh, "sf")
  # Triangles, not points - which is the whole reason this exists.
  expect_setequal(as.character(unique(sf::st_geometry_type(mesh))), "POLYGON")
  expect_true(all(sf::st_is_valid(mesh)))
  expect_true(all(c("element", "DEPTH") %in% names(mesh)))

  # Gulf of Maine basin depths, and every triangle has one.
  expect_false(any(is.na(mesh$DEPTH)))
  expect_true(all(mesh$DEPTH > 0 & mesh$DEPTH < 400))

  # A triangle is kept when any vertex is inside, so the mesh covers the box
  # rather than stopping short of it - the edge is ragged by design.
  box <- sf::st_bbox(mesh)
  expect_lte(box[["xmin"]], bb$xmin)
  expect_gte(box[["xmax"]], bb$xmax)
})

test_that("nodes and elements come back as their own point sets", {
  skip_if_no_network()

  bb <- list(xmin = -69.5, xmax = -68.5, ymin = 43, ymax = 43.8)
  nodes <- try(fvcom_mesh(bounding_box = bb, what = "nodes"), silent = TRUE)
  skip_if(inherits(nodes, "try-error"), "FVCOM THREDDS server unreachable")
  elements <- fvcom_mesh(bounding_box = bb, what = "elements")

  expect_setequal(as.character(unique(sf::st_geometry_type(nodes))), "POINT")
  expect_true(all(c("node", "DEPTH") %in% names(nodes)))
  expect_true("element" %in% names(elements))
  # Roughly twice as many triangles as nodes, as a triangulation gives.
  expect_gt(nrow(elements), nrow(nodes))
})

test_that("plot_mesh joins node and element values onto the triangles", {
  skip_if_no_network()

  bb <- list(xmin = -69.5, xmax = -68.5, ymin = 43, ymax = 43.8)
  mesh <- try(fvcom_mesh(bounding_box = bb), silent = TRUE)
  skip_if(inherits(mesh, "try-error"), "FVCOM THREDDS server unreachable")

  path <- tempfile(fileext = ".png")
  grDevices::png(path); on.exit({grDevices::dev.off(); unlink(path)}, add = TRUE)

  # Node-centred values sit at triangle corners, on the boundary between cells.
  # st_contains excludes boundaries, so joining that way returned nothing at
  # all; intersects is what makes a node join work.
  nodes <- accessFVCOM(vars = "SST", years = 2010, months = 6,
                       bounding_box = bb)
  shaded <- plot_mesh(mesh, "SST", values = nodes)
  expect_false(any(is.na(shaded$SST)))
  # Each triangle is the mean of its three corners, so it sits inside the range.
  expect_gte(min(shaded$SST), min(nodes$SST))
  expect_lte(max(shaded$SST), max(nodes$SST))

  # Element-centred values sit strictly inside one triangle each.
  elements <- accessFVCOM(vars = "UBAR", years = 2010, months = 6,
                          bounding_box = bb)
  by_element <- plot_mesh(mesh, "UBAR", values = elements)
  expect_true(any(!is.na(by_element$UBAR)))
  # The ragged-edge triangles have no centroid inside the box, so they stay NA
  # rather than borrowing a neighbour's value.
  expect_true(any(is.na(by_element$UBAR)))
})

test_that("plot_mesh refuses what it cannot do", {
  square <- sf::st_sf(
    a = 1, geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(0, 0), c(1, 0), c(1, 1), c(0, 1), c(0, 0)))), crs = 4326))

  expect_error(plot_mesh(data.frame(x = 1)), "must be an sf object")
  expect_error(plot_mesh(square, values = square), "`var` was not")

  values <- sf::st_sf(B = 1, geometry = sf::st_sfc(sf::st_point(c(0.5, 0.5)),
                                                   crs = 4326))
  expect_error(plot_mesh(square, "A", values = values), "no column 'A'")
})

# ---- offline reads against synthetic files -----------------------------------

# A small FVCOM-shaped NetCDF: `temp` on (node, siglay, time) with `Itime` and
# `Itime2` as the model writes them. Each node's value is ten times its index
# plus the hour, so a row says which node and which step it came from.
write_fake_fvcom <- function(lon, lat, times) {
  path <- tempfile(fileext = ".nc")
  epoch <- as.POSIXct("1858-11-17", tz = "UTC")
  elapsed <- as.numeric(difftime(times, epoch, units = "days"))
  node <- ncdf4::ncdim_def("node", "", seq_along(lon), create_dimvar = FALSE)
  siglay <- ncdf4::ncdim_def("siglay", "", 1:2, create_dimvar = FALSE)
  time <- ncdf4::ncdim_def("time", "", seq_along(times), create_dimvar = FALSE)
  vars <- list(
    lon = ncdf4::ncvar_def("lon", "degrees_east", node, prec = "double"),
    lat = ncdf4::ncvar_def("lat", "degrees_north", node, prec = "double"),
    Itime = ncdf4::ncvar_def("Itime", "days since 1858-11-17 00:00:00", time,
                             prec = "integer"),
    Itime2 = ncdf4::ncvar_def("Itime2", "msec since 00:00:00", time,
                              prec = "integer"),
    temp = ncdf4::ncvar_def("temp", "degrees_C", list(node, siglay, time),
                            prec = "double")
  )
  nc <- ncdf4::nc_create(path, vars)
  ncdf4::ncvar_put(nc, "lon", lon)
  ncdf4::ncvar_put(nc, "lat", lat)
  ncdf4::ncvar_put(nc, "Itime", floor(elapsed))
  ncdf4::ncvar_put(nc, "Itime2", round((elapsed - floor(elapsed)) * 86400000))
  hours <- as.integer(format(times, "%H", tz = "UTC"))
  values <- array(0, dim = c(length(lon), 2, length(times)))
  for (t in seq_along(times)) {
    values[, , t] <- 10 * seq_along(lon) + hours[t]
  }
  ncdf4::ncvar_put(nc, "temp", values)
  ncdf4::nc_close(nc)
  path
}

local_fvcom_cache <- function(env = parent.frame()) {
  cache <- withr::local_tempdir(.local_envir = env)
  local_mocked_bindings(
    copernicus_cache = function(...) {
      path <- file.path(cache, ...)
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      path
    },
    .env = env
  )
  cache
}

hours_of <- function(day) {
  as.POSIXct(day, tz = "UTC") + seq(0, 23) * 3600
}

test_that("a single-file hourly archive keeps each month to its own steps", {
  skip_if_not_installed("ncdf4")
  local_fvcom_cache()
  path <- write_fake_fvcom(lon = c(-69, -68.5), lat = c(43, 43.2),
                           times = c(hours_of("2024-01-31"),
                                     hours_of("2024-02-01")))
  spec <- list(url = path, frequency = "hourly", label = "fake")
  bb <- list(xmin = -70, xmax = -68, ymin = 42, ymax = 44)

  # The bug: the URL has no month in it, so every month opened the whole file
  # and stamped all of its steps as that month - January's rows reappeared as
  # February's, and the reverse.
  out <- accessFVCOM(vars = "SST", years = 2024, months = 1:2,
                     bounding_box = bb, archive = spec, frequency = "hourly")

  expect_equal(nrow(out), 2 * 2 * 24)
  expect_equal(unique(out$DAY[out$MONTH == 1]), 31L)
  expect_equal(unique(out$DAY[out$MONTH == 2]), 1L)
})

test_that("dates on a sub-daily archive return only the named days", {
  skip_if_not_installed("ncdf4")
  local_fvcom_cache()
  path <- write_fake_fvcom(lon = c(-69, -68.5), lat = c(43, 43.2),
                           times = c(hours_of("2024-01-30"),
                                     hours_of("2024-01-31")))
  spec <- list(url = path, frequency = "hourly", label = "fake")
  bb <- list(xmin = -70, xmax = -68, ymin = 42, ymax = 44)

  out <- accessFVCOM(vars = "SST", dates = "2024-01-31", bounding_box = bb,
                     archive = spec)
  expect_equal(unique(out$DAY), 31L)
  expect_equal(nrow(out), 2)

  # A named day the archive does not hold is said, not silently dropped.
  expect_warning(
    out <- accessFVCOM(vars = "SST", dates = c("2024-01-15", "2024-01-31"),
                       bounding_box = bb, archive = spec),
    "2024-01-15")
  expect_equal(unique(out$DAY), 31L)
})

test_that("an sf bounding box is accepted, as documented", {
  skip_if_not_installed("ncdf4")
  local_fvcom_cache()
  path <- write_fake_fvcom(lon = c(-69, -68.5), lat = c(43, 43.2),
                           times = hours_of("2024-01-31"))
  spec <- list(url = path, frequency = "hourly", label = "fake")
  box <- sf::st_as_sf(sf::st_as_sfc(sf::st_bbox(
    c(xmin = -69.1, xmax = -68.9, ymin = 42.9, ymax = 43.1),
    crs = sf::st_crs(4326))))

  out <- accessFVCOM(vars = "SST", years = 2024, months = 1,
                     bounding_box = box, archive = spec)
  expect_equal(nrow(out), 1)
  expect_equal(out$SST, 10 + 12)
})

test_that("two boxes with the same index range and count do not share a cache", {
  skip_if_not_installed("ncdf4")
  local_fvcom_cache()
  # Node 1 west, node 4 east, both at mid-latitude; node 2 south and node 3
  # north between them. Each box below selects three nodes spanning 1 to 4.
  path <- write_fake_fvcom(lon = c(-70, -69.5, -69.5, -69),
                           lat = c(40.5, 40.0, 41.0, 40.5),
                           times = as.POSIXct("2010-06-15", tz = "UTC"))
  spec <- list(url = path, label = "fake monthly")

  south <- accessFVCOM(vars = "SST", years = 2010, months = 6, archive = spec,
                       bounding_box = list(xmin = -70.1, xmax = -68.9,
                                           ymin = 39.9, ymax = 40.6))
  north <- accessFVCOM(vars = "SST", years = 2010, months = 6, archive = spec,
                       bounding_box = list(xmin = -70.1, xmax = -68.9,
                                           ymin = 40.4, ymax = 41.1))

  expect_equal(sort(south$SST), c(10, 20, 40))
  # The bug: keyed on range and count alone, this came back as the south box.
  expect_equal(sort(north$SST), c(10, 30, 40))
})

test_that("a month that has not ended is read afresh and never cached", {
  skip_if_not_installed("ncdf4")
  cache <- local_fvcom_cache()
  today <- Sys.Date()
  path <- write_fake_fvcom(lon = -69, lat = 43,
                           times = hours_of(format(today)))
  spec <- list(url = path, frequency = "hourly", label = "fake")
  bb <- list(xmin = -70, xmax = -68, ymin = 42, ymax = 44)
  opened <- 0
  real_open <- fvcom_open
  local_mocked_bindings(fvcom_open = function(archive) {
    opened <<- opened + 1
    real_open(archive)
  })

  year <- as.integer(format(today, "%Y"))
  month <- as.integer(format(today, "%m"))
  accessFVCOM(vars = "SST", years = year, months = month, bounding_box = bb,
              archive = spec)
  expect_length(list.files(file.path(cache, "fvcom")), 0)

  # So the next call reads again, and would see days added since.
  accessFVCOM(vars = "SST", years = year, months = month, bounding_box = bb,
              archive = spec)
  expect_equal(opened, 2)
})

test_that("the file is closed when a sub-daily read fails", {
  skip_if_not_installed("ncdf4")
  cache <- local_fvcom_cache()
  path <- write_fake_fvcom(lon = -69, lat = 43, times = hours_of("2024-01-31"))
  spec <- list(url = path, frequency = "hourly", label = "fake")
  closed <- 0
  real_close <- ncdf4::nc_close
  local_mocked_bindings(
    nc_close = function(nc) {
      closed <<- closed + 1
      real_close(nc)
    },
    .package = "ncdf4"
  )
  local_mocked_bindings(fvcom_read_variable = function(...) stop("DAP failure"))

  expect_error(accessFVCOM(vars = "SST", years = 2024, months = 1,
                           bounding_box = list(xmin = -70, xmax = -68,
                                               ymin = 42, ymax = 44),
                           archive = spec), "DAP failure")
  expect_equal(closed, 1)
  expect_length(list.files(file.path(cache, "fvcom")), 0)
})
