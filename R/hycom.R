#' Catalog of HYCOM variables under the same names as the Copernicus ones
#'
#' HYCOM is the HYbrid Coordinate Ocean Model, and GOFS is the global forecast
#' system built on it by the US Naval Research Laboratory. This maps the
#' package's usual short names onto the HYCOM variables that supply them, so a
#' covariate fetched from HYCOM lands in a column with the same name it would
#' have had from Copernicus or FVCOM.
#'
#' @section Bottom fields are published outright:
#' HYCOM serves `salinity_bottom` and `water_temp_bottom` as variables in their
#' own right, so `BOTS` and `BOTT` are ordinary requests here. That is the one
#' place HYCOM is plainly easier than the Copernicus reanalysis, which publishes
#' bottom temperature but no bottom salinity and makes [accessEnvDat()] derive
#' one from the full depth column. If bottom salinity over 1994–2015 is what you
#' need, this is the cheapest source for it.
#'
#' @section Surface is a depth level, not a separate field:
#' HYCOM is on 40 fixed z-levels rather than sigma layers, so `SST` and `SSS`
#' are the 0 m level of the three-dimensional field. That is a genuine surface
#' value, unlike FVCOM's uppermost sigma layer, which is a fraction of the local
#' column.
#'
#' @return a named list, one entry per variable, each with `variable`, `label`,
#'   `units`, `surface` (whether it needs a depth index), and `description`
#' @examples
#' names(hycom_variables())
#' hycom_variables()$BOTS$variable
#' @seealso [accessHYCOM()], [hycom_archives()]
#' @export
hycom_variables <- function() {
  # `surface = TRUE` means the variable carries a depth axis and only its first
  # level is wanted. The bottom fields and surf_el have no depth axis at all.
  entry <- function(variable, label, units, description, surface = FALSE) {
    list(variable = variable, label = label, units = units, surface = surface,
         description = description)
  }

  list(
    SST = entry("water_temp", "Sea surface temperature", "degrees C",
                "Water temperature at the 0 m level.", surface = TRUE),
    SSS = entry("salinity", "Sea surface salinity", "PSU",
                "Salinity at the 0 m level.", surface = TRUE),
    BOTT = entry("water_temp_bottom", "Bottom temperature", "degrees C",
                 paste("Water temperature at the sea floor, published as its",
                       "own field rather than taken from a depth level.")),
    BOTS = entry("salinity_bottom", "Bottom salinity", "PSU",
                 paste("Salinity at the sea floor, published as its own field.",
                       "The Copernicus reanalysis has no equivalent and has to",
                       "derive one; see accessEnvDat().")),
    SSH = entry("surf_el", "Sea surface height", "m",
                "Water surface elevation above the model geoid."),
    UO = entry("water_u", "Eastward current velocity", "m/s",
               "Eastward water velocity at the 0 m level.", surface = TRUE),
    VO = entry("water_v", "Northward current velocity", "m/s",
               "Northward water velocity at the 0 m level.", surface = TRUE),
    UO_BOTTOM = entry("water_u_bottom", "Eastward bottom velocity", "m/s",
                      "Eastward water velocity at the sea floor."),
    VO_BOTTOM = entry("water_v_bottom", "Northward bottom velocity", "m/s",
                      "Northward water velocity at the sea floor.")
  )
}

#' HYCOM archives this package can read
#'
#' Served over OPeNDAP from the HYCOM THREDDS server at the Naval Research
#' Laboratory. Unlike the Copernicus and FVCOM sources, HYCOM publishes **one
#' dataset per year** rather than one aggregation, so a request spanning years
#' opens several.
#'
#' @section One reanalysis, then a chain of operational experiments:
#' `GLBv53X` is the GOFS 3.1 **reanalysis**: one internally consistent run over
#' 1994–2015, which is what makes it the default. Everything after it is
#' **operational** output — the model as it was running at the time, reassigned
#' an experiment number whenever it changed — so the later archives are short,
#' they overlap each other, and they are not a reanalysis.
#'
#' Together they reach the present:
#'
#' \tabular{lll}{
#'   `GLBv53X`  \tab 1994-01-01 to 2015-12-31 \tab reanalysis \cr
#'   `GLBv563`  \tab 2014-07-01 to 2016-09-30 \tab operational \cr
#'   `GLBv572`  \tab 2016-05-01 to 2017-02-01 \tab operational \cr
#'   `GLBv928`  \tab 2017-02-01 to 2017-06-01 \tab operational \cr
#'   `GLBv577`  \tab 2017-06-01 to 2017-10-01 \tab operational \cr
#'   `GLBv929`  \tab 2017-10-01 to 2018-03-20 \tab operational \cr
#'   `GLBv930`  \tab 2018-01-01 to 2020-02-19 \tab operational \cr
#'   `GLBy930`  \tab 2018-12-04 to 2024-09-05 \tab operational, finer grid
#' }
#'
#' @section Two seams to know about:
#' **They overlap.** `GLBv563` starts eighteen months before `GLBv53X` ends, and
#' several of the 2017 experiments abut or overlap. Nothing here picks between
#' them, because which one to prefer where they overlap is a judgement: the
#' reanalysis is the more consistent, the operational run the more recent.
#'
#' **The seam that matters is the run, not the grid.** Crossing from `GLBv53X`
#' into an operational archive means changing from a reanalysis to the model as
#' it was running at the time, which is a genuine discontinuity in how the
#' values were produced.
#'
#' The grid difference is smaller than it looks. `GLBv0.08` carries 3251
#' latitudes and `GLBy0.08` carries 4251, but both span -80 to 90 and both are
#' spaced 0.04 degrees through the middle latitudes — `GLBv0.08` stretches
#' toward the poles where `GLBy0.08` stays uniform. Between 40 and 45 N the two
#' hold the same 126 latitudes, identically, so on a mid-latitude shelf the cells
#' *do* correspond and a series spanning the seam is on one grid. They diverge
#' at high latitude, where a polar study would be comparing different cells.
#'
#' The longitude convention differs too — `GLBv0.08` runs -180 to 180 and
#' `GLBy0.08` runs 0 to 360 — but that is handled internally. Give
#' `bounding_box` negative west for either.
#'
#' [accessHYCOM()] reads one archive per call and names the others when a
#' request falls outside the one asked for, rather than stitching them silently.
#'
#' @return a named list, one entry per archive, each with `url`, `layout`,
#'   `start`, `end`, `step_hours`, `kind`, `label`, and `reference`
#' @examples
#' names(hycom_archives())
#' hycom_archives()$GLBv53X$end
#'
#' # Which archives cover a given day
#' hycom_covering(as.Date("2019-06-15"))
#' @seealso [accessHYCOM()], [hycom_covering()]
#' @export
hycom_archives <- function() {
  # The GOFS reference is the same paper for every experiment; only the run
  # differs.
  gofs <- paste(
    "Chassignet EP, Hurlburt HE, Smedstad OM, Halliwell GR, Hogan PJ,",
    "Wallcraft AJ, Baraille R, Bleck R (2007). The HYCOM (HYbrid Coordinate",
    "Ocean Model) data assimilative system.",
    "Journal of Marine Systems 65:60-83. doi:10.1016/j.jmarsys.2005.09.016"
  )

  # `layout` is how the experiment is published. The reanalysis is split into one
  # dataset per year, so its url is a template; the operational runs are each a
  # single aggregation.
  archive <- function(url, layout, start, end, kind, label,
                      resolution = "0.08 deg longitude, 0.04 deg latitude") {
    list(url = url, layout = layout, start = as.Date(start), end = as.Date(end),
         step_hours = 3L, kind = kind, resolution = resolution, label = label,
         reference = gofs)
  }

  list(
    GLBv53X = archive(
      "https://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_53.X/data/%d",
      "per_year", "1994-01-01", "2015-12-31", "reanalysis",
      "HYCOM + NCODA GOFS 3.1 reanalysis (GLBv0.08 expt_53.X)"),

    GLBv563 = archive(
      "https://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_56.3",
      "single", "2014-07-01", "2016-09-30", "operational",
      "HYCOM GOFS 3.1 operational (GLBv0.08 expt_56.3)"),

    GLBv572 = archive(
      "https://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_57.2",
      "single", "2016-05-01", "2017-02-01", "operational",
      "HYCOM GOFS 3.1 operational (GLBv0.08 expt_57.2)"),

    GLBv928 = archive(
      "https://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_92.8",
      "single", "2017-02-01", "2017-06-01", "operational",
      "HYCOM GOFS 3.1 operational (GLBv0.08 expt_92.8)"),

    GLBv577 = archive(
      "https://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_57.7",
      "single", "2017-06-01", "2017-10-01", "operational",
      "HYCOM GOFS 3.1 operational (GLBv0.08 expt_57.7)"),

    GLBv929 = archive(
      "https://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_92.9",
      "single", "2017-10-01", "2018-03-20", "operational",
      "HYCOM GOFS 3.1 operational (GLBv0.08 expt_92.9)"),

    GLBv930 = archive(
      "https://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_93.0",
      "single", "2018-01-01", "2020-02-19", "operational",
      "HYCOM GOFS 3.1 operational (GLBv0.08 expt_93.0)"),

    # A different grid from every entry above: 4251 latitudes rather than 3251.
    GLBy930 = archive(
      "https://tds.hycom.org/thredds/dodsC/GLBy0.08/expt_93.0",
      "single", "2018-12-04", "2024-09-05", "operational",
      "HYCOM GOFS 3.1 operational (GLBy0.08 expt_93.0)",
      resolution = "0.08 deg longitude, 0.04 deg latitude, GLBy grid")
  )
}

#' Which HYCOM archives cover a given date
#'
#' The archives overlap, so a date can fall in more than one, and after 2015 the
#' choice between them is a judgement rather than a lookup — the reanalysis is
#' the more internally consistent, the operational run the more recent. This
#' reports the candidates instead of picking one.
#'
#' @param dates one or more `Date` values, or anything [parse_dates()] accepts
#' @return <char> the names of the archives spanning every date given, in
#'   catalog order; empty if none does
#' @examples
#' hycom_covering("2010-06-15")     # the reanalysis alone
#' hycom_covering("2015-06-15")     # reanalysis and an operational run
#' hycom_covering("2025-06-15")     # none: past the end of the record
#' @seealso [hycom_archives()], [accessHYCOM()]
#' @export
hycom_covering <- function(dates) {
  dates <- parse_dates(dates)
  archives <- hycom_archives()

  names(archives)[vapply(archives, function(spec) {
    all(dates >= spec$start & dates <= spec$end)
  }, logical(1))]
}

#' Open a HYCOM archive, or one year of it
#'
#' The reanalysis is published one dataset per year and the operational runs
#' each as a single aggregation, so `layout` decides whether the year is part of
#' the address or ignored.
#'
#' @param spec one entry of [hycom_archives()]
#' @param year <integer> the year to open, used only when `layout` is
#'   `"per_year"`
#' @return an open `ncdf4` handle; the caller closes it
#' @keywords internal
hycom_open <- function(spec, year) {
  if (!requireNamespace("ncdf4", quietly = TRUE)) {
    stop("Reading HYCOM needs the ncdf4 package, which datamatch suggests ",
         "rather than requires.\nInstall it with:  install.packages(\"ncdf4\")",
         call. = FALSE)
  }

  url <- if (identical(spec$layout, "per_year")) sprintf(spec$url, year) else spec$url
  handle <- tryCatch(ncdf4::nc_open(url), error = function(e) e)
  if (inherits(handle, "error")) {
    stop("Could not open the HYCOM archive for ", year, " over OPeNDAP:\n  ",
         url, "\n", conditionMessage(handle),
         "\nThe HYCOM THREDDS server may be down or unreachable from here.",
         call. = FALSE)
  }
  handle
}

#' Time steps of an open HYCOM year, as UTC instants
#'
#' The axis is hours from an epoch named in its own `units` attribute, and the
#' values are negative for anything before it — the reanalysis counts from
#' 2000-01-01 and starts in 1994. Read rather than assumed for that reason.
#'
#' @param handle an open `ncdf4` handle
#' @return a `POSIXct` vector in UTC, one per time step
#' @keywords internal
hycom_times <- function(handle) {
  units <- ncdf4::ncatt_get(handle, "time", "units")$value
  if (is.null(units) || !grepl("since", units)) {
    stop("The HYCOM time axis carries no usable epoch.", call. = FALSE)
  }

  epoch <- as.POSIXct(substr(trimws(sub("^.*since\\s+", "", units)), 1, 19),
                      tz = "UTC")
  if (is.na(epoch)) {
    stop("The HYCOM time epoch could not be read from '", units, "'.",
         call. = FALSE)
  }

  # Hours is the only unit this server uses; anything else would silently
  # rescale the whole axis, so it is checked rather than assumed.
  if (!grepl("^hours", trimws(units))) {
    stop("The HYCOM time axis is in unexpected units: '", units, "'.",
         call. = FALSE)
  }
  epoch + as.numeric(ncdf4::ncvar_get(handle, "time")) * 3600
}

#' The contiguous index window covering a bounding box
#'
#' HYCOM is a regular grid whose coordinates increase monotonically, so a box is
#' a contiguous run of indices on each axis and can be asked for as a slice.
#' That is the opposite of FVCOM, whose mesh numbering is not spatially coherent
#' and has to be read whole — see [fvcom_in_box()].
#'
#' Computed from the coordinate values rather than from a step, because HYCOM's
#' latitude spacing is not uniform: it is finer near the equator than toward the
#' poles, so anything derived from `lat[2] - lat[1]` would be wrong at most
#' latitudes.
#'
#' @param values <numeric> the axis coordinates, increasing
#' @param lower,upper the requested range
#' @param axis <char> the axis name, for the error
#' @return `list(start =, count =, values =)`, one-based
#' @keywords internal
hycom_window <- function(values, lower, upper, axis) {
  inside <- which(values >= lower & values <= upper)
  if (length(inside) == 0) {
    stop("The bounding box selects no ", axis, " on the HYCOM grid.\nIts ",
         axis, " runs ", round(min(values), 2), " to ", round(max(values), 2),
         "; the request asked for ", round(lower, 2), " to ", round(upper, 2),
         ".", call. = FALSE)
  }
  list(start = min(inside), count = length(inside),
       values = values[min(inside):max(inside)],
       keep = seq_len(length(inside)))
}

#' The longitude window, in whichever convention the archive uses
#'
#' HYCOM is not consistent with itself here. The `GLBv0.08` experiments run
#' -180 to 180 and `GLBy0.08` runs 0 to 360, so a Northwest Atlantic box that
#' works against the reanalysis selects nothing against the later grid — which
#' is how this was found.
#'
#' The convention is read off the coordinates rather than recorded per archive,
#' so a grid this package has not seen is handled by inspection instead of by a
#' table that can go stale. `bounding_box` is negative west throughout, as with
#' every other source, and the returned longitudes are converted back.
#'
#' @section Boxes that wrap:
#' In the 0-360 convention a box straddling the prime meridian is two runs of
#' indices rather than one, and OPeNDAP wants a contiguous slice. Such a box is
#' read as the span between its extremes and filtered locally — correct, but it
#' transfers most of a latitude row to keep two edges of it. `keep` carries the
#' positions to retain within the slice.
#'
#' @param lon <numeric> the archive's longitude axis
#' @param xmin,xmax the requested range, negative west
#' @return `list(start =, count =, values =, keep =)`, one-based, with `values`
#'   negative west
#' @keywords internal
hycom_lon_window <- function(lon, xmin, xmax) {
  if (max(lon) > 180) {
    wanted <- to_360(c(xmin, xmax))
    inside <- if (wanted[1] <= wanted[2]) {
      which(lon >= wanted[1] & lon <= wanted[2])
    } else {
      which(lon >= wanted[1] | lon <= wanted[2])
    }
  } else {
    inside <- which(lon >= xmin & lon <= xmax)
  }

  if (length(inside) == 0) {
    stop("The bounding box selects no longitude on the HYCOM grid.\nIts ",
         "longitude runs ", round(min(lon), 2), " to ", round(max(lon), 2),
         "; the request asked for ", round(xmin, 2), " to ", round(xmax, 2),
         " negative west.\nGive the box negative west whichever archive is ",
         "being read; it is converted here.", call. = FALSE)
  }

  start <- min(inside)
  count <- max(inside) - start + 1
  list(start = start, count = count,
       values = to_180(lon[inside]),
       keep = inside - start + 1)
}

#' Read one HYCOM variable over a window at one time step
#'
#' @param handle an open `ncdf4` handle
#' @param entry one entry of [hycom_variables()]
#' @param step <integer> the time index
#' @param lon_window,lat_window output of [hycom_window()]
#' @return a numeric matrix, longitude by latitude
#' @keywords internal
hycom_read_variable <- function(handle, entry, step, lon_window, lat_window) {
  variable <- handle$var[[entry$variable]]
  if (is.null(variable)) {
    stop("This HYCOM archive does not carry '", entry$variable, "'.",
         "\nIt has: ", paste(names(handle$var), collapse = ", "), call. = FALSE)
  }

  if (isTRUE(entry$surface)) {
    # Level 1 is 0 m. The whole depth axis is never wanted here: these are
    # surface entries, and a bottom value comes from its own field instead.
    start <- c(lon_window$start, lat_window$start, 1, step)
    count <- c(lon_window$count, lat_window$count, 1, 1)
  } else {
    start <- c(lon_window$start, lat_window$start, step)
    count <- c(lon_window$count, lat_window$count, 1)
  }

  values <- ncdf4::ncvar_get(handle, entry$variable, start = start,
                             count = count, collapse_degen = TRUE)
  # A wrapped longitude box is read as one contiguous span and trimmed here, so
  # only the cells actually asked for survive.
  values[lon_window$keep, , drop = FALSE]
}

#' Access HYCOM output from the GOFS 3.1 reanalysis
#'
#' Reads HYCOM over OPeNDAP and returns it as an `sf` point object with one row
#' per grid cell and time step — the same shape [accessEnvDat()] and
#' [accessFVCOM()] return, so [matchData()] joins it unchanged.
#'
#' @section Why reach for it:
#' Two reasons, both about what the Copernicus reanalysis lacks. HYCOM publishes
#' **bottom salinity and bottom temperature as fields**, where GLORYS12V1 has
#' only bottom temperature and `BOTS` has to be derived from the full depth
#' column. And it is an **independent model**, so agreement between it and
#' Copernicus is evidence about a result in a way that either one alone is not.
#'
#' A covariate taken from HYCOM is **not interchangeable** with the same-named
#' covariate from Copernicus or FVCOM, though this returns it in a column of the
#' same name. Three different models. Say which you used.
#'
#' @section Three-hourly, and no monthly mean:
#' HYCOM publishes instantaneous fields every three hours. There is no monthly
#' or daily mean to fetch, so this does not offer one:
#'
#' \itemize{
#'   \item `frequency = "daily"` (the default) takes **one snapshot per day**, at
#'     the hour given by `hour`. It is an instant, not a daily mean, and a
#'     12:00 UTC snapshot of a tidal shelf sea is not the day's average.
#'   \item `frequency = "3hourly"` returns every step, with an `HOUR` column.
#' }
#'
#' A real mean is then [upscale_time()]'s job, which keeps the aggregation
#' visible and the choice of summary yours:
#'
#' ```
#' steps <- accessHYCOM(vars = "SST", frequency = "3hourly", years = 2010,
#'                      months = 6, bounding_box = bb)
#' daily <- upscale_time(steps, to = "day")     # a genuine daily mean
#' ```
#'
#' Fetching a month of three-hourly data is 248 downloads over a slow protocol.
#' Prefer `dates` and a small box unless the whole series is genuinely wanted.
#'
#' @section Reaching past 2015:
#' The default archive is the **reanalysis**, `GLBv53X`, which is one
#' internally consistent run over 1994–2015. HYCOM continues to the present, but
#' as a chain of shorter **operational** experiments — the model as it was
#' running at the time. [hycom_archives()] lists them and [hycom_covering()]
#' says which span a given date:
#'
#' ```
#' hycom_covering("2019-06-15")
#' #> [1] "GLBv930" "GLBy930"
#'
#' recent <- accessHYCOM(vars = "BOTS", dates = "2019-06-15",
#'                       bounding_box = bb, archive = "GLBy930")
#' ```
#'
#' One archive is read per call, and a request falling outside the one named is
#' told which others hold it rather than being stitched to them silently. The
#' archives overlap, so where two cover a date there is a real choice between
#' the more consistent run and the more recent one, and crossing from the
#' reanalysis into an operational run is a discontinuity in how the values were
#' made. The grids themselves agree through the middle latitudes, so on a shelf
#' the cells line up across the seam even though the runs do not — see
#' [hycom_archives()].
#'
#' @section One dataset per year, sometimes:
#' The reanalysis is published one dataset per year, so a request spanning years
#' opens one connection per year. The operational archives are each a single
#' aggregation and open once.
#'
#' @param vars <char> variables to read, from [hycom_variables()]
#' @param years <numeric> years to read. Required unless `dates` is given.
#' @param months <numeric> months to read. Required unless `dates` is given.
#' @param bounding_box <list> named list with `xmin`, `xmax`, `ymin`, `ymax`, or
#'   an `sf`/`sfc` object to take the bounding box of. Longitudes are negative
#'   west, as elsewhere in this package.
#' @param dates the exact dates to read, as `YYYYMMDD` strings, `YYYY-MM-DD`
#'   strings, or `Date` objects
#' @param frequency <char> `"daily"` (the default) for one snapshot per day, or
#'   `"3hourly"` for every step. Neither is a mean; see the Three-hourly section.
#' @param hour <integer> which UTC hour to take when `frequency = "daily"`. Must
#'   be a multiple of 3, since that is the model's step.
#' @param archive <char> which archive to read, from [hycom_archives()]. The
#'   default is the 1994–2015 reanalysis; later years live in the operational
#'   archives, which [hycom_covering()] will name for a given date.
#' @param overwrite <logical> re-read time steps already cached
#' @return <sf object> one row per grid cell per time step, with `YEAR`, `MONTH`
#'   and `DAY`, an `HOUR` column when `frequency = "3hourly"`, and a column per
#'   requested variable
#' @examples
#' \dontrun{
#' bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
#'
#' # Bottom salinity, which the Copernicus reanalysis cannot serve directly
#' bottom <- accessHYCOM(vars = c("BOTT", "BOTS"), years = 2010, months = 1:12,
#'                       bounding_box = bb)
#'
#' matched <- matchData(observations, bottom)
#'
#' # Every three-hourly step, then a genuine daily mean
#' steps <- accessHYCOM(vars = "SST", frequency = "3hourly",
#'                      dates = "2010-06-15", bounding_box = bb)
#' daily <- upscale_time(steps, to = "day")
#' }
#' @seealso [hycom_variables()] for what can be read, [accessEnvDat()] and
#'   [accessFVCOM()] for the other sources, [matchData()] for joining any of them
#' @export
accessHYCOM <- function(vars, years = NULL, months = NULL, bounding_box,
                        dates = NULL, frequency = c("daily", "3hourly"),
                        hour = 12L, archive = "GLBv53X", overwrite = FALSE) {
  frequency <- match.arg(frequency)

  archives <- hycom_archives()
  if (!archive %in% names(archives)) {
    stop("Unknown archive '", archive, "'. Available: ",
         paste(names(archives), collapse = ", "), call. = FALSE)
  }
  spec <- archives[[archive]]

  catalog <- hycom_variables()
  unknown <- setdiff(vars, names(catalog))
  if (length(unknown) > 0) {
    stop("Not HYCOM variables: ", paste(unknown, collapse = ", "),
         "\nAvailable: ", paste(names(catalog), collapse = ", "),
         call. = FALSE)
  }
  entries <- catalog[vars]

  if (frequency == "daily" && (hour %% spec$step_hours != 0 || hour < 0 ||
                               hour > 23)) {
    stop("`hour` must be a multiple of ", spec$step_hours, " between 0 and 23, ",
         "since that is this archive's step.\nGiven: ", hour, call. = FALSE)
  }

  # Which days to read. Months are expanded to their days here, because HYCOM
  # has no monthly field to ask for - every step is an instant.
  if (!is.null(dates)) {
    if (!is.null(years) || !is.null(months)) {
      stop("`dates` already names which days to read, so `years` and `months` ",
           "are not used with it.", call. = FALSE)
    }
    days <- parse_dates(dates)
  } else {
    if (is.null(years) || is.null(months)) {
      stop("`years` and `months` are required, unless `dates` names the days ",
           "to read.", call. = FALSE)
    }
    days <- do.call(c, lapply(years, function(y) {
      do.call(c, lapply(months, function(m) {
        start <- lubridate::ymd(paste(y, m, 1, sep = "-"))
        seq(start, by = "day", length.out = lubridate::days_in_month(start))
      }))
    }))
    days <- sort(unique(days))
  }

  outside <- days < spec$start | days > spec$end
  if (any(outside)) {
    # The archives overlap and no single one reaches from 1994 to the present,
    # so "outside this archive" is usually "inside a different one". Naming them
    # turns a dead end into the next call to make.
    elsewhere <- unique(unlist(lapply(days[outside], function(day) {
      setdiff(hycom_covering(day), archive)
    })))
    advice <- if (length(elsewhere) > 0) {
      paste0("\nThose dates are in: ", paste(elsewhere, collapse = ", "),
             ".\nRead each archive in its own call and chain matchData(). The ",
             "reanalysis and the\noperational runs are different runs, which is ",
             "a seam in the values worth knowing\nabout; the grids themselves ",
             "agree through the middle latitudes.")
    } else {
      "\nNo archive in hycom_archives() covers them."
    }

    if (all(outside)) {
      stop("This archive covers ", format(spec$start), " to ", format(spec$end),
           ", and every requested day is outside it.", advice, call. = FALSE)
    }
    warning(sum(outside), " day(s) outside this archive (", format(spec$start),
            " to ", format(spec$end), ") are skipped.", advice, call. = FALSE)
    days <- days[!outside]
  }

  if (inherits(bounding_box, c("sf", "sfc"))) {
    bounding_box <- sf::st_bbox(bounding_box)
  }
  missing_edges <- setdiff(c("xmin", "xmax", "ymin", "ymax"),
                           names(bounding_box))
  if (length(missing_edges) > 0) {
    stop("bounding_box is missing: ", paste(missing_edges, collapse = ", "),
         call. = FALSE)
  }

  key <- short_hash(paste(
    paste(sort(vars), collapse = ","),
    paste(round(unlist(bounding_box[c("xmin", "xmax", "ymin", "ymax")]), 6),
          collapse = ","),
    frequency, if (frequency == "daily") hour else "all", sep = "|"))

  paths <- vapply(days, function(day) {
    copernicus_cache("hycom", paste0(archive, "_", format(day, "%Y%m%d"), "_",
                                     key, ".rds"))
  }, character(1))

  # One connection per year, opened only if that year has something missing.
  needed <- if (overwrite) rep(TRUE, length(days)) else !file.exists(paths)
  by_year <- split(seq_along(days), format(days, "%Y"))

  for (year_label in names(by_year)) {
    index <- by_year[[year_label]]
    if (!any(needed[index])) next

    handle <- hycom_open(spec, as.integer(year_label))
    times <- hycom_times(handle)
    stamps <- format(times, "%Y-%m-%d %H", tz = "UTC")

    lon <- as.numeric(ncdf4::ncvar_get(handle, "lon"))
    lat <- as.numeric(ncdf4::ncvar_get(handle, "lat"))
    lon_window <- hycom_lon_window(lon, bounding_box[["xmin"]],
                                   bounding_box[["xmax"]])
    lat_window <- hycom_window(lat, bounding_box[["ymin"]],
                               bounding_box[["ymax"]], "latitude")
    grid <- expand.grid(x = lon_window$values, y = lat_window$values)

    for (i in index[needed[index]]) {
      hours <- if (frequency == "daily") hour else seq(0, 23, by = spec$step_hours)
      steps <- match(paste(format(days[i], "%Y-%m-%d"), sprintf("%02d", hours)),
                     stamps)

      frames <- lapply(which(!is.na(steps)), function(j) {
        frame <- grid
        for (name in vars) {
          frame[[name]] <- as.numeric(hycom_read_variable(
            handle, entries[[name]], steps[j], lon_window, lat_window))
        }
        frame$YEAR <- as.integer(format(days[i], "%Y"))
        frame$MONTH <- as.integer(format(days[i], "%m"))
        frame$DAY <- as.integer(format(days[i], "%d"))
        if (frequency == "3hourly") frame$HOUR <- as.integer(hours[j])
        frame
      })

      if (length(frames) == 0) next

      frame <- dplyr::bind_rows(frames)
      # Cells outside the model's ocean are NA at every variable, as they would
      # be from any other source in this package.
      frame <- frame[rowSums(!is.na(frame[vars])) > 0, , drop = FALSE]
      rownames(frame) <- NULL
      saveRDS(frame, paths[i])
    }

    ncdf4::nc_close(handle)
  }

  usable <- file.exists(paths)
  if (!any(usable)) {
    stop("No HYCOM data could be read for the requested days.", call. = FALSE)
  }
  if (any(!usable)) {
    warning(sum(!usable), " requested day(s) are not in the archive and were ",
            "skipped.", call. = FALSE)
  }

  out <- sf::st_as_sf(dplyr::bind_rows(lapply(paths[usable], readRDS)),
                      coords = c("x", "y"), crs = sf::st_crs(4326))
  attr(out, "datamatch_step") <- if (frequency == "3hourly") "hour" else "day"
  out
}

#' Printable dictionary of HYCOM variables
#'
#' @return a data frame of class `datamatch_dictionary`
#' @examples
#' hycom_dictionary()
#' @seealso [hycom_variables()]
#' @export
hycom_dictionary <- function() {
  catalog <- hycom_variables()

  dictionary <- do.call(rbind, lapply(names(catalog), function(name) {
    entry <- catalog[[name]]
    data.frame(name = name, variable = entry$variable, label = entry$label,
               units = entry$units,
               source = if (isTRUE(entry$surface)) "0 m level" else "own field",
               layer = NA_character_,
               description = entry$description, stringsAsFactors = FALSE)
  }))

  class(dictionary) <- c("datamatch_dictionary", "data.frame")
  dictionary
}
