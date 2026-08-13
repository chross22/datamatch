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
#' @section Coverage and the gap after 2015:
#' Only the GOFS 3.1 reanalysis, `GLBv0.08/expt_53.X`, is listed. It runs
#' 1994–2015, which overlaps GLORYS well. HYCOM's later record is split across
#' several short experiments with differing grids and variable sets, and picking
#' between them is a judgement about which to track rather than a lookup — so
#' this offers the one long consistent record and says nothing about the rest.
#'
#' @return a named list, one entry per archive, each with `url` (a template
#'   taking the year), `years`, `step_hours`, `label`, and `reference`
#' @examples
#' names(hycom_archives())
#' hycom_archives()$GLBv53X$years
#' @seealso [accessHYCOM()]
#' @export
hycom_archives <- function() {
  list(
    GLBv53X = list(
      url = "https://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_53.X/data/%d",
      years = 1994:2015,
      step_hours = 3L,
      resolution = "0.08 degrees longitude, 0.04 degrees latitude",
      label = "HYCOM + NCODA GOFS 3.1 reanalysis (GLBv0.08 expt_53.X)",
      reference = paste(
        "Chassignet EP, Hurlburt HE, Smedstad OM, Halliwell GR, Hogan PJ,",
        "Wallcraft AJ, Baraille R, Bleck R (2007). The HYCOM (HYbrid Coordinate",
        "Ocean Model) data assimilative system.",
        "Journal of Marine Systems 65:60-83. doi:10.1016/j.jmarsys.2005.09.016"
      )
    )
  )
}

#' Open one year of a HYCOM archive
#'
#' @param spec one entry of [hycom_archives()]
#' @param year <integer> the year to open
#' @return an open `ncdf4` handle; the caller closes it
#' @keywords internal
hycom_open <- function(spec, year) {
  if (!requireNamespace("ncdf4", quietly = TRUE)) {
    stop("Reading HYCOM needs the ncdf4 package, which datamatch suggests ",
         "rather than requires.\nInstall it with:  install.packages(\"ncdf4\")",
         call. = FALSE)
  }

  url <- sprintf(spec$url, year)
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
         ".\nLongitudes here are negative west.", call. = FALSE)
  }
  list(start = min(inside), count = length(inside),
       values = values[min(inside):max(inside)])
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

  ncdf4::ncvar_get(handle, entry$variable, start = start, count = count,
                   collapse_degen = TRUE)
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
#' @section One dataset per year:
#' HYCOM splits its record by year, so a request spanning years opens one
#' connection per year rather than one aggregation. Years outside the archive
#' are warned about and skipped rather than failing the call.
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
#' @param archive <char> which archive to read, from [hycom_archives()]
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

  wanted_years <- unique(as.integer(format(days, "%Y")))
  outside <- setdiff(wanted_years, spec$years)
  if (length(outside) > 0) {
    if (length(setdiff(wanted_years, outside)) == 0) {
      stop("None of the requested years are in this archive, which covers ",
           min(spec$years), " to ", max(spec$years), ".", call. = FALSE)
    }
    warning("Year(s) outside the archive (", min(spec$years), " to ",
            max(spec$years), ") are skipped: ",
            paste(outside, collapse = ", "), call. = FALSE)
    days <- days[as.integer(format(days, "%Y")) %in% spec$years]
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
    lon_window <- hycom_window(lon, bounding_box[["xmin"]],
                               bounding_box[["xmax"]], "longitude")
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
