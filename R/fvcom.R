#' Catalog of FVCOM variables under the same names as the Copernicus ones
#'
#' FVCOM is an unstructured-mesh coastal model, and NECOFS is the Northeast
#' Coastal Ocean Forecast System built on it at UMass Dartmouth. This maps the
#' package's usual short names onto the FVCOM variables that supply them, so a
#' covariate fetched from FVCOM lands in a column with the same name it would
#' have had from Copernicus and everything downstream works unchanged.
#'
#' @section Where a value sits in the vertical:
#' FVCOM uses **sigma coordinates**: each of the 45 layers is a fixed *fraction*
#' of the local water column rather than a fixed depth, so layer 1 is the surface
#' everywhere and layer 45 the sea floor everywhere. That is why `SST` and `BOTT`
#' are two entries reading one variable at two layers, and why bottom salinity
#' costs nothing here — `BOTS` is simply `salinity` at the bottom layer, where in
#' GLORYS it has to be derived. See [copernicus_variables()].
#'
#' The flip side is that a sigma layer is not a depth. Layer 45 sits at 98.9% of
#' the local depth, which is a metre off the bottom on the shelf and fifty
#' metres off it in the Northeast Channel.
#'
#' @section Nodes and elements:
#' An FVCOM mesh carries scalars on triangle **nodes** and velocities on triangle
#' **elements** (the centroids). These are two different sets of points — 48,451
#' and 90,415 on GOM3 — so a variable of each kind cannot land in one table
#' without interpolating one onto the other.
#'
#' [accessFVCOM()] refuses to fetch the two together rather than interpolating on
#' your behalf, in the same spirit as [accessCopernicus()] refusing to mix two
#' Copernicus grids. Fetch each and chain [matchData()], which matches to the
#' nearest point whichever mesh it belongs to.
#'
#' @return a named list, one entry per variable, each with `variable`, `label`,
#'   `units`, `mesh` (`"node"` or `"element"`), `layer`, and `description`
#' @examples
#' names(fvcom_variables())
#' fvcom_variables()$BOTS$variable
#' @seealso [accessFVCOM()], [fvcom_archives()]
#' @export
fvcom_variables <- function() {
  # `layer` is "surface", "bottom", or NA for a variable with no vertical
  # dimension at all. It is resolved to a sigma index at read time, because the
  # bottom index is the mesh's layer count rather than a constant.
  node <- function(variable, label, units, description, layer = NA_character_) {
    list(variable = variable, label = label, units = units, mesh = "node",
         layer = layer, description = description)
  }
  element <- function(variable, label, units, description,
                      layer = NA_character_) {
    list(variable = variable, label = label, units = units, mesh = "element",
         layer = layer, description = description)
  }

  list(
    SST = node("temp", "Sea surface temperature", "degrees C",
               paste("Temperature in the uppermost sigma layer. The same",
                     "quantity as the Copernicus SST, on a much finer mesh."),
               layer = "surface"),
    BOTT = node("temp", "Bottom temperature", "degrees C",
                "Temperature in the deepest sigma layer.", layer = "bottom"),
    SSS = node("salinity", "Sea surface salinity", "PSU",
               "Salinity in the uppermost sigma layer.", layer = "surface"),
    # Free here, unlike in the Copernicus reanalysis, which publishes no
    # sea-floor salinity and has to derive one from the full depth column.
    BOTS = node("salinity", "Bottom salinity", "PSU",
                paste("Salinity in the deepest sigma layer. Published outright",
                      "here, where the Copernicus reanalysis has none and",
                      "datamatch derives one."),
                layer = "bottom"),
    SSH = node("zeta", "Sea surface height", "m",
               "Surface elevation above the model geoid."),
    DEPTH = node("h", "Water depth", "m",
                 paste("Bathymetry at the node, as the model resolves it. Static:",
                       "the same value in every time step.")),
    SWRAD = node("short_wave", "Downward shortwave radiation", "W/m2",
                 "Surface shortwave flux driving the model."),
    NHF = node("net_heat_flux", "Net surface heat flux", "W/m2",
               paste("Net heat exchange across the surface. Positive into the",
                     "ocean.")),

    UO = element("u", "Eastward current velocity", "m/s",
                 "Eastward velocity in the uppermost sigma layer.",
                 layer = "surface"),
    VO = element("v", "Northward current velocity", "m/s",
                 "Northward velocity in the uppermost sigma layer.",
                 layer = "surface"),
    UBAR = element("ua", "Eastward depth-averaged velocity", "m/s",
                   paste("Eastward velocity averaged over the water column,",
                         "which is what sets transport rather than surface",
                         "drift.")),
    VBAR = element("va", "Northward depth-averaged velocity", "m/s",
                   "Northward velocity averaged over the water column."),
    TAUX = element("uwind_stress", "Eastward wind stress", "N/m2",
                   paste("Eastward surface wind stress used to force the model.",
                         "The same quantity as the Copernicus TAUX, but the",
                         "model's own forcing rather than an observation.")),
    TAUY = element("vwind_stress", "Northward wind stress", "N/m2",
                   "Northward surface wind stress used to force the model.")
  )
}

#' FVCOM archives this package ships with
#'
#' NECOFS is served over OPeNDAP from a THREDDS server at UMass Dartmouth. Each
#' entry names one mesh and one archive on it.
#'
#' @section This list is a convenience, not the limit:
#' FVCOM is a model rather than a data product, so there is no global FVCOM
#' archive to point at. Different groups run it for their own regions on their
#' own servers, and what is built in here is only what one server publishes for
#' the Northeast US shelf.
#'
#' Any other FVCOM output can be read by describing it with [fvcom_archive()]
#' and passing that to [accessFVCOM()], which is the intended route for every
#' region this package does not ship. FVCOM output shares one structure wherever
#' it is run — values on mesh nodes and element centroids, sigma layers,
#' `lon`/`lat` and `lonc`/`latc`, an `Itime` day count — and that structure is
#' what the reader depends on, not the region.
#'

#' @section Why only the monthly means:
#' The 30-year GOM3 hindcast is published as hourly fields and as monthly means
#' of them. Only the monthly aggregation is listed here, because the hourly one
#' cannot be opened at all: it carries 342,348 time steps, and `nc_open()` reads
#' the whole time coordinate before returning anything, so the DAP request for it
#' times out. The failure takes upwards of ten minutes to arrive and reads as
#' `NetCDF: DAP failure`, which says nothing about the cause.
#'
#' @return a named list, one entry per archive, each with `url`, `mesh`,
#'   `frequency`, `start`, `end`, `nodes`, `elements`, and `reference`
#' @examples
#' names(fvcom_archives())
#' fvcom_archives()$GOM3$url
#' @seealso [accessFVCOM()]
#' @export
fvcom_archives <- function() {
  list(
    GOM3 = list(
      url = paste0("http://www.smast.umassd.edu:8080/thredds/dodsC/",
                   "fvcom/hindcasts/30yr_gom3/mean"),
      layout = "aggregation",
      mesh = "GOM3",
      kind = "hindcast",
      frequency = "monthly",
      start = as.Date("1978-01-01"),
      end = as.Date("2013-12-31"),
      nodes = 48451L,
      elements = 90415L,
      label = "NECOFS Northeast US 30+ year hindcast, GOM3 mesh, monthly means",
      reference = fvcom_reference()
    ),

    # The archived operational forecast. A different mesh and a different kind of
    # product from the hindcast above, not a continuation of it - see the
    # Hindcast and forecast archive section.
    GOM7 = list(
      url = paste0("http://www.smast.umassd.edu:8080/thredds/dodsC/",
                   "models/fvcom/NECOFS/Archive/NECOFS_GOM/%04d/",
                   "necofs_%04d%02d.nc"),
      layout = "per_month",
      mesh = "GOM7",
      kind = "forecast archive",
      frequency = "hourly",
      start = as.Date("2025-01-01"),
      end = Sys.Date(),
      # As of the 2025-03 file onward. Operational output remeshes: the
      # 2025-01 file carries 198,594 nodes and 356,280 elements. These are
      # descriptive only - the reader takes the mesh from each file it opens,
      # precisely because it moves.
      nodes = 207081L,
      elements = 371290L,
      mesh_varies = TRUE,
      # The operational run saves fewer fields than the hindcast: no surface
      # forcing and no wind stress. Declared so a request for one is refused
      # before a connection is opened rather than failing at the read.
      variables = c("SST", "BOTT", "SSS", "BOTS", "SSH", "DEPTH",
                    "UO", "VO", "UBAR", "VBAR"),
      label = "NECOFS Gulf of Maine forecast archive, GOM7 mesh, hourly",
      reference = fvcom_reference()
    )
  )
}

#' The FVCOM citation, which is one paper for every run
#'
#' @return <char> the reference
#' @keywords internal
fvcom_reference <- function() {
  paste("Chen C, Beardsley RC, Cowles G (2006). An unstructured grid,",
        "finite-volume coastal ocean model (FVCOM) system.",
        "Oceanography 19(1):78-89. doi:10.5670/oceanog.2006.92")
}

#' Describe any FVCOM archive, so it can be read like a built-in one
#'
#' [fvcom_archives()] ships the NECOFS Gulf of Maine hindcast because that is
#' what one server publishes. FVCOM itself is run for coastlines everywhere, by
#' groups who publish on their own THREDDS servers, and this is how to reach any
#' of them: point it at an OPeNDAP endpoint and it works out the rest.
#'
#' The reader depends on FVCOM's structure rather than on the region, so
#' anything written by FVCOM should work — values on nodes and element
#' centroids, sigma layers, `lon`/`lat` and `lonc`/`latc`, and an `Itime` day
#' count. What differs between deployments is the mesh, the period, and which
#' variables were saved, all of which are read from the file.
#'
#' @section What it checks:
#' The endpoint is opened and inspected once, so a URL that is wrong, blocked, or
#' not FVCOM fails here — with the reason — rather than part-way through a fetch.
#' The mesh size, time span, and variable list come back in the returned spec, so
#' `str()` on it says what the archive actually holds.
#'
#' @section A caution about aggregations:
#' Point this at an aggregation of hourly output and it may not open at all.
#' `nc_open()` reads the whole time coordinate first, and a decade of hourly
#' fields is enough time steps to exceed a server's DAP timeout — which is
#' exactly why the built-in GOM3 entry is the monthly mean. Prefer a monthly
#' aggregation, or a single file, over a long hourly one.
#'
#' @param url <char> the OPeNDAP endpoint, as a THREDDS `dodsC` URL
#' @param label <char> a human-readable name; defaults to the URL
#' @param reference <char> the citation for this model run, if there is one.
#'   FVCOM output is somebody's work, and this is where to record whose.
#' @param frequency <char> what one time step represents, for documentation
#' @return a list in the shape [fvcom_archives()] entries take, ready to pass to
#'   [accessFVCOM()] as `archive`
#' @examples
#' \dontrun{
#' # Any FVCOM endpoint, not just the built-in ones
#' mine <- fvcom_archive(
#'   "http://www.smast.umassd.edu:8080/thredds/dodsC/fvcom/hindcasts/30yr_gom3/mean",
#'   label = "GOM3 monthly means")
#'
#' str(mine)   # mesh size, period, and variables actually present
#'
#' env <- accessFVCOM(vars = "SST", years = 2010, months = 1:12,
#'                    bounding_box = bb, archive = mine)
#' }
#' @seealso [accessFVCOM()], [fvcom_archives()]
#' @export
fvcom_archive <- function(url, label = NULL, reference = NA_character_,
                          frequency = "monthly") {
  spec <- list(url = url, mesh = NA_character_, frequency = frequency,
               label = label %||% url, reference = reference)

  handle <- fvcom_open(spec)
  on.exit(ncdf4::nc_close(handle), add = TRUE)

  # An FVCOM file is recognisable by its mesh dimensions. Without them this is
  # some other model, and every assumption the reader makes about nodes,
  # elements and sigma layers is wrong.
  for (required in c("node", "nele")) {
    if (is.null(handle$dim[[required]])) {
      stop("This does not look like FVCOM output: it has no '", required,
           "' dimension.\n  ", url,
           "\nFVCOM files carry values on mesh nodes and element centroids, ",
           "and this has neither.", call. = FALSE)
    }
  }
  for (required in c("lon", "lat")) {
    if (is.null(handle$var[[required]])) {
      stop("This FVCOM archive has no '", required, "' variable, so its mesh ",
           "cannot be placed.\n  ", url, call. = FALSE)
    }
  }

  times <- fvcom_times(handle)

  spec$mesh <- "unstructured"
  spec$nodes <- handle$dim$node$len
  spec$elements <- handle$dim$nele$len
  spec$sigma_layers <- handle$dim$siglay$len %||% NA_integer_
  spec$start <- min(times)
  spec$end <- max(times)
  spec$steps <- length(times)
  # Which of the catalog's variables this run actually saved. FVCOM writes what
  # its configuration asks for, so another deployment may carry fewer, or more.
  spec$variables <- names(fvcom_variables())[
    vapply(fvcom_variables(), function(entry) {
      !is.null(handle$var[[entry$variable]])
    }, logical(1))]

  spec
}

#' The OPeNDAP handle for an archive, with a readable failure
#'
#' `ncdf4` is a `Suggests`, and the server is a remote one that is sometimes
#' down. Both failures are reported here rather than as a raw netCDF error,
#' which names a URL and nothing about what to do.
#'
#' @param archive one entry of [fvcom_archives()]
#' @return an open `ncdf4` handle; the caller closes it
#' @keywords internal
fvcom_open <- function(archive) {
  if (!requireNamespace("ncdf4", quietly = TRUE)) {
    stop("Reading FVCOM needs the ncdf4 package, which datamatch suggests ",
         "rather than requires.\nInstall it with:  install.packages(\"ncdf4\")",
         call. = FALSE)
  }

  handle <- tryCatch(ncdf4::nc_open(archive$url), error = function(e) e)
  if (inherits(handle, "error")) {
    stop("Could not open the FVCOM archive over OPeNDAP:\n  ", archive$url,
         "\n", conditionMessage(handle),
         "\nThe THREDDS server at UMass Dartmouth may be down or unreachable ",
         "from here.\nIt is a plain HTTP service on port 8080, which some ",
         "networks block.", call. = FALSE)
  }
  handle
}

#' Time steps of an FVCOM archive, as dates
#'
#' Computed from `Itime`, the integer day count, and not from the `Times`
#' character axis beside it. Both are present and `Times` is the more obvious
#' choice, but on the 30-year GOM3 mean it is corrupt: the first step reads
#' `1878-01-14T03:009//-500000`, a century out with a mangled time. Parsing it
#' would silently place the whole record in the wrong era.
#'
#' `Itime` is sound, and its `units` attribute declares the epoch
#' (`days since 1858-11-17`, the Modified Julian Day epoch). The epoch is read
#' from that attribute rather than assumed, so an archive counting from some
#' other origin is handled rather than misread.
#'
#' @param handle an open `ncdf4` handle
#' @return a `Date` vector, one per time step
#' @keywords internal
fvcom_times <- function(handle) {
  units <- ncdf4::ncatt_get(handle, "Itime", "units")$value
  if (is.null(units) || !grepl("since", units)) {
    stop("The archive's time axis carries no usable epoch.", call. = FALSE)
  }

  epoch <- as.Date(substr(trimws(sub("^.*since\\s+", "", units)), 1, 10))
  if (is.na(epoch)) {
    stop("The archive's time epoch could not be read from '", units, "'.",
         call. = FALSE)
  }

  parsed <- epoch + as.numeric(ncdf4::ncvar_get(handle, "Itime"))
  if (anyNA(parsed)) {
    stop("The archive's time axis could not be read as dates.", call. = FALSE)
  }
  parsed
}

#' Node or element coordinates of a mesh
#'
#' Scalars sit on nodes and velocities on element centroids, so which set of
#' coordinates a value belongs to depends on the variable.
#'
#' @param handle an open `ncdf4` handle
#' @param mesh `"node"` or `"element"`
#' @return a data frame of `x` and `y`
#' @keywords internal
fvcom_coordinates <- function(handle, mesh) {
  names <- if (mesh == "node") c("lon", "lat") else c("lonc", "latc")
  data.frame(x = as.numeric(ncdf4::ncvar_get(handle, names[1])),
             y = as.numeric(ncdf4::ncvar_get(handle, names[2])))
}

#' Mesh coordinates, cached to disk
#'
#' The mesh never changes, so its coordinates are worth keeping. Without this a
#' fully cached request would still open an OPeNDAP connection and pull 48,451
#' points to work out which rows it already has — several seconds to discover
#' there is nothing to do. Everywhere else in this package a cached call is
#' cheap, and this keeps that true here.
#'
#' @param archive_name <char> the archive's name, part of the cache key
#' @param spec one entry of [fvcom_archives()]
#' @param mesh `"node"` or `"element"`
#' @return a data frame of `x` and `y`
#' @keywords internal
fvcom_mesh_coordinates <- function(archive_name, spec, mesh) {
  cached <- copernicus_cache("fvcom",
                             paste0(archive_name, "_", mesh, "_mesh.rds"))
  if (file.exists(cached)) return(readRDS(cached))

  # Only an aggregation may be cached this way. A per-month archive can change
  # mesh between files - NECOFS GOM7 carries 198,594 nodes in January 2025 and
  # 207,081 from March - so a mesh read once and reused would attach one month's
  # coordinates to another month's values, silently and wrongly. Those archives
  # read their mesh per file instead; see accessFVCOM().
  if (identical(spec$layout, "per_month")) {
    stop("A per-month archive's mesh is read per file, not cached: it can ",
         "change between months.", call. = FALSE)
  }

  handle <- fvcom_open(spec)
  on.exit(ncdf4::nc_close(handle), add = TRUE)

  coords <- fvcom_coordinates(handle, mesh)
  saveRDS(coords, cached)
  coords
}

#' Which points of a mesh fall inside a bounding box
#'
#' The mesh is subset here rather than in the request. FVCOM numbers its points
#' in mesh-generation order, which is not spatially coherent: on GOM3 a Gulf of
#' Maine box needs 94% of the index range to reach 40% of its points, so asking
#' the server for a contiguous slice saves almost nothing over reading the field
#' whole. A field is 388 KB, which is cheaper to fetch entire than to negotiate.
#'
#' @param coords output of [fvcom_coordinates()]
#' @param bounding_box a named list or vector with `xmin`, `xmax`, `ymin`, `ymax`
#' @return <integer> the indices inside the box
#' @keywords internal
fvcom_in_box <- function(coords, bounding_box) {
  if (inherits(bounding_box, c("sf", "sfc"))) {
    bounding_box <- sf::st_bbox(bounding_box)
  }
  missing <- setdiff(c("xmin", "xmax", "ymin", "ymax"), names(bounding_box))
  if (length(missing) > 0) {
    stop("bounding_box is missing: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }

  inside <- which(coords$x >= bounding_box[["xmin"]] &
                  coords$x <= bounding_box[["xmax"]] &
                  coords$y >= bounding_box[["ymin"]] &
                  coords$y <= bounding_box[["ymax"]])

  if (length(inside) == 0) {
    stop("No mesh points fall inside the bounding box.\nThe GOM3 mesh covers ",
         "roughly -75.7 to -56.9 E and 35.3 to 46.1 N, and is a coastal mesh: ",
         "it\nhas no points on land, and coarsens offshore. Check the box's ",
         "sign convention -\nlongitudes here are negative west.", call. = FALSE)
  }
  inside
}

#' Read one variable at one time step
#'
#' @param handle an open `ncdf4` handle
#' @param entry one entry of [fvcom_variables()]
#' @param step <integer> the time index to read
#' @param layers <integer> how many sigma layers the archive has
#' @param keep <integer> mesh indices to retain
#' @return <numeric> one value per kept point
#' @keywords internal
fvcom_read_variable <- function(handle, entry, step, layers, keep) {
  variable <- handle$var[[entry$variable]]
  if (is.null(variable)) {
    stop("The archive does not carry '", entry$variable, "'.", call. = FALSE)
  }
  dims <- vapply(variable$dim, function(d) d$name, character(1))

  # `h` is bathymetry: one value per node for all time, so it has no time axis
  # to index into.
  if (!"time" %in% dims) {
    values <- ncdf4::ncvar_get(handle, entry$variable)
    return(as.numeric(values)[keep])
  }

  has_sigma <- any(grepl("^sigla?y?", dims))
  if (has_sigma) {
    # Layer 1 is the surface and the last is the sea floor, everywhere, because
    # sigma layers are fractions of the local column rather than depths.
    index <- if (identical(entry$layer, "bottom")) layers else 1L
    values <- ncdf4::ncvar_get(handle, entry$variable,
                               start = c(1, index, step), count = c(-1, 1, 1))
  } else {
    values <- ncdf4::ncvar_get(handle, entry$variable,
                               start = c(1, step), count = c(-1, 1))
  }
  as.numeric(values)[keep]
}

#' Access FVCOM output from the NECOFS hindcast
#'
#' Reads an unstructured-mesh FVCOM archive over OPeNDAP and returns it as an
#' `sf` point object with one row per mesh point and time step — the same shape
#' [accessCopernicus()] returns, so [matchData()] joins it unchanged.
#'
#' @section What this is, and when to prefer it:
#' NECOFS is a regional coastal model on a triangular mesh that refines toward
#' the coast. Over the Gulf of Maine it resolves structure the global reanalyses
#' cannot: over -70 to -66 E and 41 to 44 N, GLORYS resolves 1,742 cells where
#' GOM3 carries 6,579 nodes, concentrated where the bathymetry is complicated.
#'
#' That resolution is the reason to use it, and its limits are the reason not to.
#' It is one regional model rather than a reanalysis assimilating observations
#' basin-wide, it stops at the mesh boundary, and it ends in 2013. A covariate
#' taken from FVCOM is **not interchangeable** with the same-named covariate from
#' Copernicus, even though this returns it in a column of the same name — they
#' are different models on different meshes. Say which you used.
#'
#' @section Nodes and elements:
#' Scalars (`SST`, `SSS`, `BOTT`, `BOTS`, `SSH`) sit on mesh nodes; velocities
#' and stresses (`UO`, `VO`, `UBAR`, `VBAR`, `TAUX`, `TAUY`) sit on element
#' centroids. Those are two different sets of points, so the two kinds cannot be
#' fetched together — mixing them is an error rather than a silent interpolation
#' of one onto the other. Fetch each and chain [matchData()].
#'
#' @section Bottom salinity:
#' `BOTS` costs nothing here. FVCOM's sigma coordinate makes the deepest layer
#' the sea floor at every node, so bottom salinity is a layer index rather than
#' the derivation [accessCopernicus()] needs against GLORYS. If bottom properties are
#' the point of the analysis, this is the cheaper source for them.
#'
#' @section Reading other regions:
#' FVCOM is a model, not a data product, so there is no global archive of it.
#' Groups run it for their own coastlines and publish on their own servers, and
#' the archives built in here are only what one server publishes for the
#' Northeast US. Anything else is reached by describing it once:
#'
#' ```
#' elsewhere <- fvcom_archive("http://example.org/thredds/dodsC/some_fvcom_run")
#' env <- accessFVCOM(vars = "SST", years = 2010, months = 1:12,
#'                    bounding_box = bb, archive = elsewhere)
#' ```
#'
#' Everything this function does depends on FVCOM's structure rather than on the
#' region, so any FVCOM output should read. What differs between deployments —
#' the mesh, the period, which fields were saved — is read from the file, and
#' [fvcom_archive()] reports it.
#'
#' @section Hindcast and forecast archive are different products:
#' Two NECOFS archives ship, and the second is not a continuation of the first:
#'
#' \itemize{
#'   \item **`GOM3`** (the default) is the 30-year **hindcast**, monthly means on
#'     the 48,451-node GOM3 mesh, 1978–2013. One consistent retrospective run.
#'   \item **`GOM7`** is the archived **operational forecast**, hourly on the
#'     207,081-node GOM7 mesh, 2025 onward. It is the model as it was running at
#'     the time, stitched across whatever versions were current.
#' }
#'
#' Three things change at once between them — the mesh, the time step, and
#' whether the output is retrospective — so they are offered as separate
#' archives rather than joined into one series. `GOM7` also saves fewer fields:
#' it carries no wind stress, so `TAUX` and `TAUY` are unavailable there.
#'
#' Between 2014 and 2024 this server publishes neither, which is a gap in NECOFS
#' rather than in this package.
#'
#' @section Sub-daily archives:
#' `GOM7` is hourly, so `frequency` chooses what to take from it:
#'
#' \itemize{
#'   \item `"daily"` (the default) reads **one snapshot per day**, at `hour`.
#'   \item `"hourly"` reads every hour.
#' }
#'
#' The default is the snapshot deliberately. A month of hourly GOM7 is 720 reads
#' of a 207,081-node field, which is a long transfer to keep a shelf-sized corner
#' of it, and a snapshot is usually what a daily covariate wants. A snapshot is
#' an instant rather than a daily mean; [upscale_time()] makes a real mean from
#' `frequency = "hourly"` if that is what is needed.
#'
#' `frequency` does nothing on a monthly archive such as `GOM3`, and saying so
#' beats silently ignoring it.
#'
#' @section Only monthly means, on the hindcast:
#' The hindcast is published hourly and as monthly means of those hours. Only the
#' monthly aggregation is offered, because the hourly one cannot be opened: it
#' carries 342,348 time steps, and reading the time coordinate — which
#' `nc_open()` does before returning anything — exceeds the server's DAP timeout.
#' The failure takes over ten minutes to arrive and says only
#' `NetCDF: DAP failure`.
#'
#' Sub-monthly FVCOM is therefore not a matter of passing a different argument
#' here. It would need the per-file datasets behind the aggregation, read one
#' month at a time.
#'
#' @param vars <char> variables to read, from [fvcom_variables()]
#' @param years <numeric> years to read. Required unless `dates` is given.
#' @param months <numeric> months to read. Required unless `dates` is given.
#' @param bounding_box <list> named list with `xmin`, `xmax`, `ymin`, `ymax`, or
#'   an `sf`/`sfc` object to take the bounding box of
#' @param dates the months to read, named as dates. On a monthly archive any
#'   date selects the month containing it.
#' @param frequency <char> for a sub-daily archive such as `GOM7`, `"daily"`
#'   (the default) for one snapshot per day or `"hourly"` for every hour.
#'   Ignored, with a warning, on a monthly archive.
#' @param hour <integer> which UTC hour the daily snapshot takes, 0 to 23.
#' @param archive which archive to read: the name of one from
#'   [fvcom_archives()], or a spec from [fvcom_archive()] describing any other
#'   FVCOM endpoint. The built-in list covers the Northeast US shelf only,
#'   because that is what one server publishes; [fvcom_archive()] is how every
#'   other region is reached.
#' @param overwrite <logical> re-read time steps already cached
#' @return <sf object> one row per mesh point per time step, with `YEAR`,
#'   `MONTH` and `DAY`, and a column per requested variable
#' @examples
#' \dontrun{
#' bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
#'
#' # Scalars live on nodes
#' fv <- accessFVCOM(vars = c("SST", "BOTT", "BOTS"), years = 2010:2013,
#'                   months = 1:12, bounding_box = bb)
#'
#' matched <- matchData(observations, fv)
#'
#' # Velocities live on elements, so they are a second call
#' currents <- accessFVCOM(vars = c("UBAR", "VBAR"), years = 2010:2013,
#'                         months = 1:12, bounding_box = bb)
#' matched <- matchData(matched, currents)
#' }
#' @seealso [fvcom_variables()] for what can be read, [accessCopernicus()],
#'   [accessHYCOM()], [accessCCMP()] and [accessERDDAP()] for the other sources,
#'   [matchData()] for joining any of them to observations
#' @export
accessFVCOM <- function(vars, years = NULL, months = NULL, bounding_box,
                        dates = NULL, frequency = c("daily", "hourly"),
                        hour = 12L, archive = "GOM3", overwrite = FALSE) {
  frequency_given <- !missing(frequency)
  frequency <- match.arg(frequency)
  # `archive` is either the name of a built-in or a spec from fvcom_archive(),
  # which is how any other region's FVCOM output is reached.
  if (is.list(archive)) {
    spec <- archive
    if (is.null(spec$url)) {
      stop("An archive given as a list must carry a `url`. Build one with ",
           "fvcom_archive().", call. = FALSE)
    }
    archive_name <- spec$label %||% spec$url
  } else {
    archives <- fvcom_archives()
    if (!archive %in% names(archives)) {
      stop("Unknown archive '", archive, "'. Built in: ",
           paste(names(archives), collapse = ", "),
           "\nFVCOM is run for coastlines everywhere and this package ships ",
           "only what one\nserver publishes. To read any other, describe it ",
           "with fvcom_archive(url) and pass\nthat here as `archive`.",
           call. = FALSE)
    }
    spec <- archives[[archive]]
    archive_name <- archive
  }

  # Part of every cache filename, so it has to be short and filesystem-safe. A
  # built-in's name already is; a user-supplied endpoint is a URL, which is
  # neither, so it is hashed.
  archive_key <- if (is.list(archive)) {
    paste0("custom-", short_hash(spec$url))
  } else {
    archive
  }

  catalog <- fvcom_variables()
  unknown <- setdiff(vars, names(catalog))
  if (length(unknown) > 0) {
    stop("Not FVCOM variables: ", paste(unknown, collapse = ", "),
         "\nAvailable: ", paste(names(catalog), collapse = ", "),
         "\nThese are FVCOM's own names, which overlap the Copernicus ones ",
         "deliberately but\nare not the same set.", call. = FALSE)
  }
  entries <- catalog[vars]

  # A spec built by fvcom_archive() knows which variables its run actually
  # saved, so a request for one it does not have is refused before connecting.
  if (!is.null(spec$variables)) {
    absent <- setdiff(vars, spec$variables)
    if (length(absent) > 0) {
      stop("This archive does not carry: ", paste(absent, collapse = ", "),
           "\nIt has: ", paste(spec$variables, collapse = ", "),
           "\nFVCOM saves what its configuration asks for, so runs differ in ",
           "which fields exist.", call. = FALSE)
    }
  }

  # Nodes and elements are two different sets of points. Returning both in one
  # table would mean interpolating one onto the other, which is a modelling
  # decision rather than a fetch.
  meshes <- unique(vapply(entries, function(e) e$mesh, character(1)))
  if (length(meshes) > 1) {
    grouped <- vapply(meshes, function(m) {
      paste(vars[vapply(entries, function(e) e$mesh, character(1)) == m],
            collapse = ", ")
    }, character(1))
    stop("These variables sit on different parts of the FVCOM mesh and cannot ",
         "be read together:\n  ",
         paste(paste0(grouped, "  ->  ", meshes, "s"), collapse = "\n  "),
         "\nScalars are on nodes and velocities on element centroids - two ",
         "different sets of\npoints. Call accessFVCOM() once for each and chain ",
         "matchData().", call. = FALSE)
  }
  mesh <- meshes

  # The archive is monthly, so a date selects the month containing it. Said
  # rather than assumed, because `dates` on a daily Copernicus fetch means the
  # days themselves.
  if (!is.null(dates)) {
    if (!is.null(years) || !is.null(months)) {
      stop("`dates` already names which time steps to read, so `years` and ",
           "`months` are not\nused with it.", call. = FALSE)
    }
    dates <- parse_dates(dates)
    stop_if_future(dates, "FVCOM")
    years <- as.integer(format(dates, "%Y"))
    months <- as.integer(format(dates, "%m"))
    wanted <- unique(paste(years, months, sep = "-"))
  } else {
    if (is.null(years) || is.null(months)) {
      stop("`years` and `months` are required, unless `dates` names the time ",
           "steps to read.", call. = FALSE)
    }
    grid <- expand.grid(MONTH = months, YEAR = years)
    wanted <- unique(paste(grid$YEAR, grid$MONTH, sep = "-"))
  }

  # An archive is either monthly, in which case its own step is all there is, or
  # sub-daily, in which case `frequency` chooses between every hour and one
  # snapshot a day.
  sub_daily <- identical(spec$layout, "per_month") ||
    identical(spec$frequency, "hourly")

  if (!sub_daily && frequency_given) {
    warning("`frequency` applies only to sub-daily archives, and ",
            if (is.list(archive)) "this one" else archive,
            " is ", spec$frequency %||% "monthly",
            ". Ignoring it.", call. = FALSE)
  }
  if (sub_daily && frequency == "daily" && (hour < 0 || hour > 23)) {
    stop("`hour` must be between 0 and 23. Given: ", hour, call. = FALSE)
  }
  step <- if (!sub_daily) "month" else if (frequency == "hourly") "hour" else "day"

  # An aggregation has one mesh for the whole archive, so it is read once and
  # cached, and the cache key can be built from the resulting indices. A
  # per-month archive cannot: its mesh may change between files, so the mesh is
  # read inside the loop and the key is built from the box itself.
  if (sub_daily) {
    coords <- NULL
    keep <- NULL
    box_key <- paste(round(unlist(bounding_box[c("xmin", "xmax", "ymin",
                                                 "ymax")]), 6), collapse = ",")
  } else {
    coords <- fvcom_mesh_coordinates(archive_key, spec, mesh)
    keep <- fvcom_in_box(coords, bounding_box)
    box_key <- paste(paste(range(keep), collapse = "-"), length(keep), sep = "|")
  }

  # Keyed on the month asked for rather than on the archive's own timestamp, so
  # a cache hit needs no time axis and no connection.
  key <- short_hash(paste(paste(sort(vars), collapse = ","), box_key, step,
                          if (identical(step, "day")) hour else "all",
                          sep = "|"))
  paths <- vapply(wanted, function(period) {
    parts <- as.integer(strsplit(period, "-", fixed = TRUE)[[1]])
    copernicus_cache("fvcom", paste0(archive_key, "_", mesh, "_",
                                     sprintf("%04d%02d", parts[1], parts[2]),
                                     "_", key, ".rds"))
  }, character(1))

  needed <- if (overwrite) rep(TRUE, length(paths)) else !file.exists(paths)

  # Only reach for the network when something is actually missing. A wholly
  # cached request reads from disk and never opens the archive.
  if (any(needed) && sub_daily) {
    # A per-month archive is one file per month, so each month is opened in turn
    # rather than one aggregation being indexed into.
    for (i in which(needed)) {
      parts <- as.integer(strsplit(wanted[i], "-", fixed = TRUE)[[1]])
      month_spec <- spec
      month_spec$url <- sprintf(spec$url, parts[1], parts[1], parts[2])

      handle <- tryCatch(fvcom_open(month_spec), error = function(e) e)
      if (inherits(handle, "error")) {
        warning("No file for ", wanted[i], " in this archive; skipping.",
                call. = FALSE)
        next
      }

      # This file's own mesh. Read per file because it can differ between
      # months, which is why it is not cached for these archives.
      month_coords <- fvcom_coordinates(handle, mesh)
      month_keep <- fvcom_in_box(month_coords, bounding_box)

      times <- fvcom_hourly_times(handle)
      hours <- as.integer(format(times, "%H", tz = "UTC"))
      days <- as.integer(format(times, "%d", tz = "UTC"))

      # Every hour of the month, or one snapshot per day. The default is the
      # snapshot: a month of hourly GOM7 is 720 reads of a 207,081-node field,
      # which is hours of transfer to keep a shelf-sized corner of it.
      steps <- if (step == "hour") seq_along(times) else which(hours == hour)

      layers <- handle$dim$siglay$len %||% 1L
      frames <- lapply(steps, function(s) {
        frame <- month_coords[month_keep, , drop = FALSE]
        for (name in vars) {
          frame[[name]] <- fvcom_read_variable(handle, entries[[name]], s,
                                               layers, month_keep)
        }
        frame$YEAR <- parts[1]
        frame$MONTH <- parts[2]
        frame$DAY <- days[s]
        if (step == "hour") frame$HOUR <- hours[s]
        frame
      })
      ncdf4::nc_close(handle)

      if (length(frames) == 0) next
      frame <- dplyr::bind_rows(frames)
      rownames(frame) <- NULL
      saveRDS(frame, paths[i])
    }
  } else if (any(needed)) {
    handle <- fvcom_open(spec)
    on.exit(ncdf4::nc_close(handle), add = TRUE)

    times <- fvcom_times(handle)
    available <- paste(as.integer(format(times, "%Y")),
                       as.integer(format(times, "%m")), sep = "-")
    steps <- match(wanted, available)

    outside <- needed & is.na(steps)
    if (all(is.na(steps)) && !any(!needed)) {
      stop("None of the requested months are in this archive, which covers ",
           format(spec$start, "%Y-%m"), " to ", format(spec$end, "%Y-%m"), ".",
           call. = FALSE)
    }
    if (any(outside)) {
      warning(sum(outside), " requested month(s) are outside the archive (",
              format(spec$start, "%Y-%m"), " to ", format(spec$end, "%Y-%m"),
              ") and are skipped: ",
              paste(utils::head(wanted[outside], 5), collapse = ", "),
              if (sum(outside) > 5) ", ..." else "", call. = FALSE)
    }

    layers <- handle$dim$siglay$len %||% 1L

    for (i in which(needed & !is.na(steps))) {
      frame <- coords[keep, , drop = FALSE]
      for (name in vars) {
        frame[[name]] <- fvcom_read_variable(handle, entries[[name]], steps[i],
                                             layers, keep)
      }
      parts <- as.integer(strsplit(wanted[i], "-", fixed = TRUE)[[1]])
      frame$YEAR <- parts[1]
      frame$MONTH <- parts[2]
      # Stamped day 1 like every other monthly product in this package, so
      # detect_temporal_resolution() reads it back as monthly. The archive's own
      # stamp is mid-month, which is where the mean is centred rather than a day
      # it covers.
      frame$DAY <- 1L
      rownames(frame) <- NULL

      saveRDS(frame, paths[i])
    }
  }

  usable <- file.exists(paths)
  if (!any(usable)) {
    stop("None of the requested months are in this archive, which covers ",
         format(spec$start, "%Y-%m"), " to ", format(spec$end, "%Y-%m"), ".",
         call. = FALSE)
  }
  frames <- lapply(paths[usable], readRDS)

  out <- sf::st_as_sf(dplyr::bind_rows(frames), coords = c("x", "y"),
                      crs = sf::st_crs(4326))
  attr(out, "datamatch_step") <- step
  stamp_source(out, "fvcom", archive_key)
}

#' Time steps of one sub-daily FVCOM file, as UTC instants
#'
#' [fvcom_times()] returns dates, which is all a monthly aggregation needs. An
#' hourly file needs the hour as well, so this keeps `Itime2` — the milliseconds
#' within the day that the date-only reader discards.
#'
#' @param handle an open `ncdf4` handle
#' @return a `POSIXct` vector in UTC, one per time step
#' @keywords internal
fvcom_hourly_times <- function(handle) {
  units <- ncdf4::ncatt_get(handle, "Itime", "units")$value
  epoch <- as.Date(substr(trimws(sub("^.*since\\s+", "", units)), 1, 10))
  if (is.na(epoch)) {
    stop("The archive's time epoch could not be read from '", units, "'.",
         call. = FALSE)
  }

  days <- as.numeric(ncdf4::ncvar_get(handle, "Itime"))
  # Itime2 is milliseconds past midnight. Absent on a file storing whole days.
  millis <- tryCatch(as.numeric(ncdf4::ncvar_get(handle, "Itime2")),
                     error = function(e) rep(0, length(days)))

  as.POSIXct(epoch, tz = "UTC") + days * 86400 + millis / 1000
}

#' Printable dictionary of FVCOM variables
#'
#' @param mesh filter to `"node"`, `"element"`, or `"all"`
#' @return a data frame of class `datamatch_dictionary`
#' @examples
#' fvcom_dictionary()
#' fvcom_dictionary("element")
#' @seealso [fvcom_variables()]
#' @export
fvcom_dictionary <- function(mesh = c("all", "node", "element")) {
  mesh <- match.arg(mesh)
  catalog <- fvcom_variables()

  dictionary <- do.call(rbind, lapply(names(catalog), function(name) {
    entry <- catalog[[name]]
    data.frame(name = name, variable = entry$variable, label = entry$label,
               units = entry$units, source = entry$mesh,
               layer = entry$layer %||% NA_character_,
               description = entry$description, stringsAsFactors = FALSE)
  }))

  if (mesh != "all") {
    dictionary <- dictionary[dictionary$source == mesh, ]
    rownames(dictionary) <- NULL
  }

  class(dictionary) <- c("datamatch_dictionary", "data.frame")
  # Named so print() describes this dictionary rather than guessing at it.
  attr(dictionary, "datamatch_family") <- "fvcom"
  dictionary
}

#' Read an FVCOM mesh on its own, with no data on it
#'
#' [accessFVCOM()] returns values at points — nodes for scalars, element
#' centroids for velocities. That is what [matchData()] needs, but it is not the
#' mesh: it is a scatter of the mesh's points, and drawing it shows dots where
#' the grid is triangles. This returns the triangles themselves, so the grid can
#' actually be plotted.
#'
#' @section Why the points are not enough:
#' An FVCOM mesh is a triangulation, and which nodes form each triangle lives in
#' a connectivity array (`nv`) that a point fetch never reads. Without it there
#' is no way to draw a cell boundary, shade a cell by its value, or show how the
#' resolution changes across a shelf — all of which are the usual reasons for
#' looking at an unstructured model in the first place.
#'
#' The result carries no time dimension and no covariates. It is the grid.
#'
#' @section What comes back:
#' \itemize{
#'   \item `"polygons"` (the default) — one `POLYGON` per element, with the
#'     element index and `DEPTH`, the mean of its three nodes' bathymetry. This
#'     is what to plot.
#'   \item `"nodes"` — the mesh nodes as `POINT`s, with `DEPTH`. Scalars such as
#'     `SST` and `BOTS` live here.
#'   \item `"elements"` — the element centroids as `POINT`s. Velocities and
#'     stresses live here.
#' }
#'
#' @section Bounding box:
#' A triangle is kept when **any** of its three vertices falls inside the box, so
#' the returned mesh covers the box rather than stopping short of it. The edge is
#' therefore ragged, and a triangle may extend a little beyond what was asked
#' for. Clipping to the box exactly would cut triangles into shapes the model
#' does not have.
#'
#' @section Meshes that move:
#' `GOM3` has one mesh for its whole record. `GOM7` does not — it is operational
#' output and remeshes between files, carrying 198,594 nodes in January 2025 and
#' 207,081 from March. For an archive like that the mesh belongs to a particular
#' month, so `date` says which; it defaults to the start of the record.
#'
#' @param archive which archive's mesh: a name from [fvcom_archives()], or a spec
#'   from [fvcom_archive()]
#' @param bounding_box <list> optional named list with `xmin`, `xmax`, `ymin`,
#'   `ymax`, or an `sf`/`sfc` object. `NULL` returns the whole mesh, which for
#'   GOM3 is 90,415 triangles.
#' @param what <char> `"polygons"`, `"nodes"`, or `"elements"`
#' @param date the month whose mesh to read, for an archive that remeshes.
#'   Ignored for a single-mesh archive.
#' @return an `sf` object: `POLYGON` for `"polygons"`, `POINT` otherwise, in
#'   EPSG:4326
#' @examples
#' \dontrun{
#' bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
#'
#' mesh <- fvcom_mesh(bounding_box = bb)
#' plot(sf::st_geometry(mesh))                 # the grid itself
#' plot(mesh["DEPTH"], border = NA)            # shaded by bathymetry
#'
#' # Shade the triangles by a fetched value. Join spatially rather than by
#' # position: accessFVCOM() returns only the points inside the box, so its row
#' # order does not correspond to the mesh's element numbering.
#' currents <- accessFVCOM(vars = "UBAR", years = 2010, months = 6,
#'                         bounding_box = bb)
#' shaded <- sf::st_join(mesh, currents["UBAR"], join = sf::st_contains)
#' plot(shaded["UBAR"], border = NA)
#' }
#' @seealso [accessFVCOM()] for values on the mesh, [fvcom_archives()]
#' @export
fvcom_mesh <- function(archive = "GOM3", bounding_box = NULL,
                       what = c("polygons", "nodes", "elements"), date = NULL) {
  what <- match.arg(what)

  if (is.list(archive)) {
    spec <- archive
    if (is.null(spec$url)) {
      stop("An archive given as a list must carry a `url`. Build one with ",
           "fvcom_archive().", call. = FALSE)
    }
  } else {
    archives <- fvcom_archives()
    if (!archive %in% names(archives)) {
      stop("Unknown archive '", archive, "'. Built in: ",
           paste(names(archives), collapse = ", "),
           "\nTo read any other, describe it with fvcom_archive(url).",
           call. = FALSE)
    }
    spec <- archives[[archive]]
  }

  # A per-month archive's url is a template, and its mesh can differ between
  # months, so some month has to be named. See the Meshes that move section.
  if (identical(spec$layout, "per_month")) {
    when <- if (is.null(date)) spec$start else parse_dates(date)[1]
    spec$url <- sprintf(spec$url, as.integer(format(when, "%Y")),
                        as.integer(format(when, "%Y")),
                        as.integer(format(when, "%m")))
  }

  handle <- fvcom_open(spec)
  on.exit(ncdf4::nc_close(handle), add = TRUE)

  if (identical(what, "elements")) {
    coords <- fvcom_coordinates(handle, "element")
    coords$element <- seq_len(nrow(coords))
    keep <- if (is.null(bounding_box)) {
      seq_len(nrow(coords))
    } else {
      fvcom_in_box(coords, bounding_box)
    }
    return(sf::st_as_sf(coords[keep, , drop = FALSE], coords = c("x", "y"),
                        crs = sf::st_crs(4326)))
  }

  nodes <- fvcom_coordinates(handle, "node")
  nodes$node <- seq_len(nrow(nodes))
  depth <- if (!is.null(handle$var[["h"]])) {
    as.numeric(ncdf4::ncvar_get(handle, "h"))
  } else {
    rep(NA_real_, nrow(nodes))
  }
  nodes$DEPTH <- depth

  if (identical(what, "nodes")) {
    keep <- if (is.null(bounding_box)) {
      seq_len(nrow(nodes))
    } else {
      fvcom_in_box(nodes, bounding_box)
    }
    return(sf::st_as_sf(nodes[keep, , drop = FALSE], coords = c("x", "y"),
                        crs = sf::st_crs(4326)))
  }

  if (is.null(handle$var[["nv"]])) {
    stop("This archive has no `nv` connectivity array, so its triangles cannot ",
         "be built.\nWithout it the mesh is only a set of points; use ",
         "what = \"nodes\".", call. = FALSE)
  }
  # [nele, 3], one-based node indices - FVCOM is written in Fortran.
  nv <- ncdf4::ncvar_get(handle, "nv")

  # A triangle is kept when any vertex is inside, so the mesh covers the box
  # rather than stopping short of it.
  keep <- if (is.null(bounding_box)) {
    seq_len(nrow(nv))
  } else {
    inside <- rep(FALSE, nrow(nodes))
    inside[fvcom_in_box(nodes, bounding_box)] <- TRUE
    which(inside[nv[, 1]] | inside[nv[, 2]] | inside[nv[, 3]])
  }
  if (length(keep) == 0) {
    stop("No mesh triangles fall inside the bounding box.", call. = FALSE)
  }

  x <- nodes$x
  y <- nodes$y
  triangles <- lapply(keep, function(i) {
    vertices <- nv[i, ]
    # Closed ring: the first vertex repeated at the end, as sf requires.
    ring <- cbind(x[c(vertices, vertices[1])], y[c(vertices, vertices[1])])
    sf::st_polygon(list(ring))
  })

  out <- sf::st_sf(
    element = keep,
    DEPTH = rowMeans(matrix(depth[nv[keep, ]], ncol = 3)),
    geometry = sf::st_sfc(triangles, crs = sf::st_crs(4326)))
  attr(out, "datamatch_mesh") <- spec$mesh %||% "unstructured"
  out
}
