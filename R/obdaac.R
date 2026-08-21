#' Ocean colour sensors read through NASA OB.DAAC
#'
#' OB.DAAC is NASA's Ocean Biology Distributed Active Archive Center, and it
#' holds the ocean colour record — every mission from SeaWiFS in 1997 to PACE,
#' all reprocessed together so that a series crossing from one sensor to the
#' next is crossing between consistent products rather than between eras.
#'
#' @section Why reach for it, and why not:
#' [accessERDDAP()] serves satellite chlorophyll with no account at all, which
#' is genuinely easier, and it is the right first stop. What it cannot give you
#' is **length**: its VIIRS entries begin in 2012 at the earliest. OB.DAAC has
#' SeaWiFS from September 1997, which is the difference between a decade of
#' chlorophyll and nearly three, and it has the sensors either side of any gap
#' you need to bridge.
#'
#' It also carries what ocean colour measures besides chlorophyll — diffuse
#' attenuation, photosynthetically available radiation, particulate organic and
#' inorganic carbon — on the same grid, from the same retrieval.
#'
#' Against that: **every fetch needs an Earthdata Login**, which is the one
#' place in this package where a download will not work until you have gone and
#' created an account. [accessOBDAAC()] says how.
#'
#' @section The sensors are not interchangeable:
#' They overlap, and where they overlap they disagree. Two sensors' `CHL` on
#' the same day are two retrievals with different bands, different atmospheric
#' corrections and different calibration histories, and stitching a series
#' across a mission boundary puts a step in it that is instrumental rather than
#' oceanographic. [source_of()] records which sensor produced a fetch for
#' exactly this reason.
#'
#' Where a long consistent record matters more than any one sensor, prefer a
#' merged product — the Copernicus-GlobColour entries in
#' [copernicus_variables()] are multi-sensor and built for that.
#'
#' @section What each carries:
#' \tabular{lll}{
#'   `SEAWIFS`  \tab colour only          \tab 1997-09 to 2010-12 \cr
#'   `MODIST`   \tab colour, SST, FLH     \tab 2000-02 onward \cr
#'   `MODISA`   \tab colour, SST, FLH     \tab 2002-07 onward \cr
#'   `VIIRS`    \tab colour, SST          \tab 2012-01 onward \cr
#'   `VIIRSJ1`  \tab colour, SST          \tab 2017-12 onward \cr
#'   `VIIRSJ2`  \tab colour only          \tab 2023-03 onward
#' }
#'
#' Every start and end above was read out of the archive rather than taken from
#' a mission description, so they are the first and last day OB.DAAC actually
#' publishes a Level-3 field for.
#'
#' @section Why PACE is not here:
#' PACE is the newest ocean colour mission and its absence is deliberate, for
#' two reasons that compound.
#'
#' Its standard Level-3 mapped catalog publishes inherent optical properties,
#' diffuse attenuation, PAR and surface reflectance — and **no chlorophyll
#' suite**. PACE chlorophyll exists, but not on this path, so the one variable
#' most people would come to it for is not what this route would give them.
#'
#' What is left could still be read, except that PACE names a processing
#' version where every older sensor names a product —
#' `PACE_OCI.20250615.L3m.DAY.KD.V3_2.4km.nc` against
#' `AQUA_MODIS.20200601.L3m.DAY.KD.Kd_490.4km.nc`. That version changes with
#' each reprocessing and cannot be constructed, only looked up, and looking it
#' up needs OB.DAAC's file search, which accepts POST only. Hard-coding a
#' version would work until the next reprocessing and then fail silently.
#'
#' Read PACE directly with `earthdatalogin` or `rsi` where you need it.
#'
#' @return a named list, one entry per sensor, each with `id`, `prefix`,
#'   `start`, `end`, `suites`, `resolutions`, `label` and `reference`
#' @examples
#' names(obdaac_sensors())
#' obdaac_sensors()$MODISA$start
#' @seealso [accessOBDAAC()], [obdaac_variables()]
#' @export
obdaac_sensors <- function() {
  # `id` is the numeric mission identifier the OB.DAAC file search takes.
  # `suites` is which product suites that mission publishes, which is what
  # decides whether a variable can be asked of it.
  colour <- c("CHL", "KD", "PAR", "PIC", "POC")

  list(
    SEAWIFS = list(
      id = 6L, prefix = "SEASTAR_SEAWIFS_GAC",
      start = as.Date("1997-09-04"), end = as.Date("2010-12-11"),
      suites = colour, resolutions = c("4km", "9km"),
      label = "SeaWiFS on OrbView-2, global area coverage",
      reference = paste(
        "McClain CR, Feldman GC, Hooker SB (2004). An overview of the SeaWiFS",
        "project and strategies for producing a climate research quality",
        "global ocean bio-optical time series. Deep-Sea Research II",
        "51:5-42. doi:10.1016/j.dsr2.2003.11.001")),

    MODIST = list(
      id = 8L, prefix = "TERRA_MODIS",
      start = as.Date("2000-02-24"), end = NA,
      suites = c(colour, "SST", "NSST", "SST4", "FLH"),
      resolutions = c("4km", "9km"),
      label = "MODIS on Terra",
      reference = modis_reference()),

    MODISA = list(
      id = 7L, prefix = "AQUA_MODIS",
      start = as.Date("2002-07-04"), end = NA,
      suites = c(colour, "SST", "NSST", "SST4", "FLH"),
      resolutions = c("4km", "9km"),
      label = "MODIS on Aqua",
      reference = modis_reference()),

    VIIRS = list(
      id = 14L, prefix = "SNPP_VIIRS",
      start = as.Date("2012-01-02"), end = NA,
      suites = c(colour, "SST", "NSST"), resolutions = c("4km", "9km"),
      label = "VIIRS on Suomi-NPP",
      reference = viirs_reference()),

    VIIRSJ1 = list(
      id = 33L, prefix = "JPSS1_VIIRS",
      start = as.Date("2017-12-13"), end = NA,
      suites = c(colour, "SST", "NSST"), resolutions = c("4km", "9km"),
      label = "VIIRS on NOAA-20 (JPSS-1)",
      reference = viirs_reference()),

    VIIRSJ2 = list(
      id = 43L, prefix = "JPSS2_VIIRS",
      start = as.Date("2023-03-31"), end = NA,
      suites = colour, resolutions = c("4km", "9km"),
      label = "VIIRS on NOAA-21 (JPSS-2)",
      reference = viirs_reference())
  )
}

#' @keywords internal
#' @noRd
modis_reference <- function() {
  paste("Esaias WE, Abbott MR, Barton I, et al. (1998). An overview of MODIS",
        "capabilities for ocean science observations. IEEE Transactions on",
        "Geoscience and Remote Sensing 36:1250-1265. doi:10.1109/36.701076")
}

#' @keywords internal
#' @noRd
viirs_reference <- function() {
  paste("Wang M, Liu X, Tan L, et al. (2013). Impacts of VIIRS SDR",
        "performance on ocean color products. Journal of Geophysical",
        "Research: Atmospheres 118:10347-10360. doi:10.1002/jgrd.50793")
}

#' Catalog of OB.DAAC variables under familiar names
#'
#' Maps the names this package uses onto the product suite and the variable
#' inside it that supply them.
#'
#' @section Which SST this is:
#' MODIS and VIIRS publish more than one sea surface temperature, and they are
#' different measurements rather than different names for one:
#'
#' \itemize{
#'   \item **`SST`** is the 11 um retrieval from the daytime pass, which sees
#'     the skin of the ocean including whatever the sun has warmed that
#'     afternoon.
#'   \item **`SST_NIGHT`** is the same 11 um retrieval from the night pass,
#'     with that diurnal warming absent. It is the one to use where a
#'     comparison across days or sensors has to be like for like.
#' }
#'
#' Neither is the foundation temperature that `MUR` in [erddap_datasets()]
#' analyses, and none of the three is the topmost model level that a reanalysis
#' calls `SST`. All four arrive in a column called `SST` unless you ask for the
#' night one, and [source_of()] is what tells them apart.
#'
#' @section Chlorophyll is not gap-free:
#' These are single-sensor Level-3 composites, so a daily field is mostly cloud
#' outside the tropics and a `CHL` column from one is mostly `NA`. That is the
#' honest state of the measurement rather than a fault, and there are three
#' ways through it: composite in time by asking for `frequency = "8day"` or
#' `"monthly"`, interpolate with [fill_satellite_gaps()], which records what it
#' filled, or use a gap-free product — the daily Copernicus `CHL` and the
#' `VIIRSCHL` entry in [erddap_datasets()] are both already interpolated.
#'
#' @return a named list, one entry per variable, each with `suite`, `variable`,
#'   `label`, `units` and `description`
#' @examples
#' names(obdaac_variables())
#' obdaac_variables()$CHL$suite
#' @seealso [accessOBDAAC()], [obdaac_dictionary()] for a printable table
#' @export
obdaac_variables <- function() {
  entry <- function(suite, variable, label, units, description) {
    list(suite = suite, variable = variable, label = label, units = units,
         description = description)
  }

  list(
    CHL = entry("CHL", "chlor_a", "Chlorophyll-a concentration (satellite)",
                "mg/m3",
                paste("Near-surface chlorophyll-a from the OCx/OCI band-ratio",
                      "algorithm. A retrieval rather than a model field, so",
                      "it is gappy under cloud - see the Chlorophyll is not",
                      "gap-free section.")),
    KD490 = entry("KD", "Kd_490", "Diffuse attenuation at 490 nm", "1/m",
                  paste("How fast blue-green light is attenuated with depth.",
                        "A measure of water clarity, and what sets the depth",
                        "of the euphotic zone.")),
    PAR = entry("PAR", "par", "Photosynthetically available radiation",
                "einstein/m2/day",
                paste("Daily integrated downwelling radiation between 400 and",
                      "700 nm at the sea surface. The light available to",
                      "photosynthesis.")),
    POC = entry("POC", "poc", "Particulate organic carbon", "mg/m3",
                "Near-surface particulate organic carbon."),
    PIC = entry("PIC", "pic", "Particulate inorganic carbon", "mol/m3",
                paste("Near-surface particulate inorganic carbon, which is",
                      "largely coccolithophore calcite.")),
    SST = entry("SST", "sst", "Sea surface temperature (daytime)",
                "degrees C",
                paste("11 um sea surface temperature from the daytime pass.",
                      "A skin temperature that includes diurnal warming; see",
                      "the Which SST this is section.")),
    SST_NIGHT = entry("NSST", "sst", "Sea surface temperature (night)",
                      "degrees C",
                      paste("11 um sea surface temperature from the night",
                            "pass, without the day's surface warming.")),
    NFLH = entry("FLH", "nflh", "Normalized fluorescence line height",
                 "W/m2/um/sr",
                 paste("Chlorophyll fluorescence above the background",
                       "reflectance. Responds to physiological state as well",
                       "as biomass, and so is not simply another chlorophyll.",
                       "MODIS only."))
  )
}

#' Where an Earthdata Login credential is found
#'
#' @section Why this package cannot avoid it:
#' OB.DAAC requires an Earthdata Login on every data access point. There is no
#' anonymous route, and the failure when you have not got one is unhelpful in a
#' particular way: the server answers **HTTP 200** with the login page, so a
#' naive download writes nine kilobytes of HTML into a file called `.nc` and
#' the error surfaces later as a corrupt netCDF. [obdaac_download()] checks the
#' bytes for this and says what actually happened.
#'
#' @section Setting one up:
#' Register once at <https://urs.earthdata.nasa.gov/users/new>, then either:
#'
#' \itemize{
#'   \item **An appkey**, which is the simpler of the two. Generate one at
#'     <https://oceandata.sci.gsfc.nasa.gov/appkey/> and put it in
#'     `options(datamatch.earthdata_appkey = "...")`, or in the
#'     `EARTHDATA_APPKEY` environment variable. It is a bearer token, so keep
#'     it out of scripts you share — `.Renviron` is the usual home.
#'   \item **A `~/.netrc`**, which is what NASA's own examples use and what
#'     other tools on your machine may already read:
#'     `machine urs.earthdata.nasa.gov login USERNAME password PASSWORD`.
#'     Set it to mode 600. This needs `curl` on the `PATH`.
#' }
#'
#' The appkey is preferred where both are present, because it needs no cookie
#' jar and no external program.
#'
#' @return a list with `kind` and, for an appkey, `key`
#' @keywords internal
obdaac_credentials <- function() {
  key <- getOption("datamatch.earthdata_appkey",
                   default = Sys.getenv("EARTHDATA_APPKEY"))
  if (is.character(key) && nzchar(key)) {
    return(list(kind = "appkey", key = key))
  }

  netrc <- path.expand("~/.netrc")
  if (file.exists(netrc) &&
      any(grepl("urs.earthdata.nasa.gov",
                readLines(netrc, warn = FALSE), fixed = TRUE))) {
    if (nzchar(Sys.which("curl"))) return(list(kind = "netrc"))
    stop("~/.netrc has Earthdata credentials but `curl` is not on the PATH, ",
         "and the netrc route needs it.\nUse an appkey instead: ",
         "https://oceandata.sci.gsfc.nasa.gov/appkey/", call. = FALSE)
  }

  stop("Reading OB.DAAC needs an Earthdata Login, which this package cannot ",
       "create for you.\n",
       "  1. Register once at https://urs.earthdata.nasa.gov/users/new\n",
       "  2. Generate an appkey at https://oceandata.sci.gsfc.nasa.gov/appkey/\n",
       "  3. Put it in ~/.Renviron as  EARTHDATA_APPKEY=your-key\n",
       "     or set options(datamatch.earthdata_appkey = \"your-key\")\n",
       "A ~/.netrc entry for urs.earthdata.nasa.gov works too. See ",
       "?accessOBDAAC.", call. = FALSE)
}

#' The OB.DAAC filename that holds one variable for one period
#'
#' @section Why the name is constructed rather than looked up:
#' OB.DAAC has a file search that would answer this exactly, report each file's
#' size, and know which days a sensor missed. It accepts **POST only**, and
#' `utils::download.file()` cannot POST, so using it would mean adding an HTTP
#' package to reach one endpoint.
#'
#' The names are worth constructing instead because they are strictly regular
#' across every sensor and suite here — verified against the archive for
#' SeaWiFS, both MODIS instruments and all three VIIRS, for daily and monthly,
#' for the colour suites and the temperature ones. The one mission whose names
#' are *not* constructible is PACE, and it is left out for that reason among
#' others; see [obdaac_sensors()].
#'
#' What is lost is the ability to know, before trying, that a sensor returned
#' nothing on a given day. That surfaces as a failed download for that step
#' instead, which [accessOBDAAC()] reports by name and carries on past.
#'
#' @param sensor one entry of [obdaac_sensors()]
#' @param entry one entry of [obdaac_variables()]
#' @param when <Date> the day, or the first of the month for a composite
#' @param frequency <char> `"daily"` or `"monthly"`
#' @param resolution <char> `"4km"` or `"9km"`
#' @return <char> the filename
#' @keywords internal
obdaac_filename <- function(sensor, entry, when, frequency, resolution) {
  # A daily field is named for its day; a monthly composite for the span it
  # covers, both ends inclusive, which is why the month length is needed.
  span <- if (frequency == "monthly") {
    last <- lubridate::ceiling_date(when, "month") - 1
    paste0(format(when, "%Y%m%d"), "_", format(last, "%Y%m%d"))
  } else {
    format(when, "%Y%m%d")
  }

  paste0(sensor$prefix, ".", span, ".L3m.", obdaac_period(frequency), ".",
         entry$suite, ".", entry$variable, ".", resolution, ".nc")
}

#' The period token a frequency is published under
#'
#' @param frequency <char> `"daily"` or `"monthly"`
#' @return <char> the token in an OB.DAAC filename
#' @keywords internal
obdaac_period <- function(frequency) {
  switch(frequency, daily = "DAY", monthly = "MO")
}

#' About how large one global Level-3 mapped file is
#'
#' Used to say what a request is about to transfer before it starts, in the way
#' [accessCCMP()] does, because nothing in the call hints at the cost and the
#' difference between the two resolutions is a factor of three.
#'
#' These are measured from the archive rather than derived from the grid: a 4 km
#' daily chlorophyll field is about 15 MB and its 9 km counterpart about 5, and
#' the temperature suites are somewhat smaller than the colour ones. One number
#' per resolution is enough for a warning about order of magnitude.
#'
#' @param resolution <char> `"4km"` or `"9km"`
#' @return <numeric> bytes
#' @keywords internal
obdaac_typical_bytes <- function(resolution) {
  switch(resolution, "4km" = 15e6, "9km" = 5e6, 15e6)
}

#' Download one OB.DAAC file, refusing the login page
#'
#' @section Why the status code is not enough:
#' An unauthenticated request is answered with **HTTP 200 and the Earthdata
#' Login page**, not with a 401. A download that trusts the status code
#' therefore writes nine kilobytes of HTML into a file named `.nc`, and the
#' mistake surfaces much later as a corrupt netCDF, naming neither the
#' credential nor the file.
#'
#' The first bytes are checked instead. Every file here is netCDF, which begins
#' either `CDF` or the HDF5 signature, and an HTML document begins with
#' neither.
#'
#' @param file <char> the filename to fetch
#' @param destination <char> where to write it
#' @param credentials from [obdaac_credentials()]
#' @return `NULL` on success, or a one-line description of the failure
#' @keywords internal
obdaac_download <- function(file, destination, credentials) {
  url <- paste0("https://oceandata.sci.gsfc.nasa.gov/ob/getfile/", file)

  status <- tryCatch({
    if (credentials$kind == "appkey") {
      utils::download.file(paste0(url, "?appkey=", credentials$key),
                           destination, mode = "wb", quiet = TRUE)
    } else {
      cookies <- path.expand("~/.urs_cookies")
      utils::download.file(
        url, destination, mode = "wb", quiet = TRUE, method = "curl",
        extra = c("-n", "-L", "-c", shQuote(cookies), "-b", shQuote(cookies)))
    }
  }, error = function(e) conditionMessage(e),
     warning = function(w) conditionMessage(w))

  if (!identical(status, 0L) || !file.exists(destination)) {
    if (file.exists(destination)) unlink(destination)
    return(paste0("  ", file, ": ",
                  if (is.character(status)) status else "download failed"))
  }

  magic <- readBin(destination, "raw", n = 4)
  is_netcdf <- identical(rawToChar(magic[1:3]), "CDF") ||
    (magic[1] == as.raw(0x89) && identical(rawToChar(magic[2:4]), "HDF"))

  if (!is_netcdf) {
    unlink(destination)
    return(paste0(
      "  ", file, ": the server returned a login page rather than the file, ",
      "so the Earthdata\n    credential is missing, wrong or expired. If it ",
      "is set, check it has not been\n    revoked - see ?accessOBDAAC. A ",
      "date the sensor did not return also lands here."))
  }
  NULL
}

#' Read a bounding box out of one OB.DAAC Level-3 mapped file
#'
#' @section Latitude runs the other way:
#' These are global equidistant-cylindrical grids with latitude descending from
#' 90 to -90, where most of this package's sources ascend. It makes no
#' difference to the indexing — a latitude window is still one contiguous run —
#' and the coordinates are paired with their values in file order either way,
#' so nothing downstream sees it. Noted because it looks like a bug the first
#' time the raw arrays are inspected.
#'
#' @param path <char> the downloaded file
#' @param entry one entry of [obdaac_variables()]
#' @param bounding_box <list> the box, negative west
#' @return a data frame of `x`, `y` and the value, or `NULL` if the box
#'   selects nothing
#' @keywords internal
obdaac_read <- function(path, entry, bounding_box) {
  handle <- ncdf4::nc_open(path)
  on.exit(ncdf4::nc_close(handle), add = TRUE)

  if (is.null(handle$var[[entry$variable]])) {
    stop("The OB.DAAC file has no '", entry$variable, "' variable.\n  ",
         basename(path), "\nIt holds: ",
         paste(utils::head(names(handle$var), 8), collapse = ", "),
         "\nThis usually means the suite was reprocessed into a different ",
         "shape; please report it.", call. = FALSE)
  }

  lon <- as.numeric(handle$dim$lon$vals)
  lat <- as.numeric(handle$dim$lat$vals)

  keep_lon <- which(lon >= bounding_box[["xmin"]] & lon <= bounding_box[["xmax"]])
  keep_lat <- which(lat >= bounding_box[["ymin"]] & lat <= bounding_box[["ymax"]])
  if (length(keep_lon) == 0 || length(keep_lat) == 0) return(NULL)

  values <- ncdf4::ncvar_get(
    handle, entry$variable,
    start = c(min(keep_lon), min(keep_lat)),
    count = c(length(keep_lon), length(keep_lat)))

  frame <- expand.grid(x = lon[keep_lon], y = lat[keep_lat])
  frame[[entry$variable]] <- as.numeric(values)
  frame
}

#' Access NASA OB.DAAC ocean colour and sea surface temperature
#'
#' Downloads Level-3 mapped satellite fields from NASA's Ocean Biology DAAC and
#' returns them as an `sf` point object with one row per grid cell and time
#' step — the same shape [accessCopernicus()], [accessFVCOM()],
#' [accessHYCOM()], [accessCCMP()], [accessERDDAP()] and [accessCEFI()] return,
#' so [matchData()] joins it unchanged.
#'
#' @section It needs an Earthdata Login:
#' This is the only source in this package that will not work until you have
#' created an account, and the failure without one is misleading: NASA answers
#' an unauthenticated request with HTTP 200 and the login page. Register once
#' at <https://urs.earthdata.nasa.gov/users/new>, generate an appkey at
#' <https://oceandata.sci.gsfc.nasa.gov/appkey/>, and put it in `~/.Renviron`:
#'
#' ```
#' EARTHDATA_APPKEY=your-key-here
#' ```
#'
#' A `~/.netrc` entry for `urs.earthdata.nasa.gov` works too. See
#' [obdaac_credentials()] for both routes and where they are looked for. A
#' download that comes back as the login page is refused by name rather than
#' being written to disk as a broken file.
#'
#' @section It downloads the whole globe:
#' OB.DAAC serves Level-3 mapped fields as global static files with no
#' server-side subsetting, so **one variable for one day is one global file**
#' however small the bounding box, and the subset is taken locally. At 4 km a
#' daily chlorophyll field is about 15 MB and at 9 km about 5, so `resolution =
#' "9km"` is three times cheaper for a study whose grid is coarser than 4 km
#' anyway.
#'
#' The exact total is reported before anything is transferred, because the file
#' search returns each file's size, and the extracted subsets are cached, so a
#' long record is paid for once.
#'
#' @section Why there is no eight-day option:
#' OB.DAAC publishes eight-day composites and they are the obvious answer to
#' cloud gaps, but this package cannot join them honestly. [matchData()] joins
#' on an hour, a day, a month or a year, and an eight-day bin is none of those:
#' stamped as a day it would demand an observation fall on the bin's first
#' date, and nearly every row would go unmatched. Use `"monthly"`, which is a
#' step the join understands, or [fill_satellite_gaps()] on the daily field,
#' which records what it filled.
#'
#' @section Which sensor, and why it matters:
#' `sensor` defaults to `"MODISA"`, which has the longest current record with
#' both colour and SST. It is a choice you should make deliberately rather than
#' inherit — see the section of [obdaac_sensors()] on why the sensors are not
#' interchangeable — and [source_of()] records which one answered.
#'
#' @param vars <char> variables to read, from [obdaac_variables()]
#' @param years <numeric> years to read. Required unless `dates` is given.
#' @param months <numeric> months to read. Required unless `dates` is given.
#' @param bounding_box <list> named list with `xmin`, `xmax`, `ymin`, `ymax`, or
#'   an `sf`/`sfc` object. Longitudes negative west.
#' @param dates the exact dates to read, as `YYYYMMDD` strings, `YYYY-MM-DD`
#'   strings, or `Date` objects
#' @param frequency <char> `"daily"` (the default) or `"monthly"`
#' @param sensor <char> which mission to read, from [obdaac_sensors()]
#' @param resolution <char> `"4km"` (the default) or `"9km"`. At 9 km a global
#'   file is about a third the size, which is the difference worth knowing for
#'   a long record.
#' @param overwrite <logical> re-read time steps already cached
#' @return <sf object> one row per grid cell per time step, with `YEAR`,
#'   `MONTH`, `DAY` and a column per requested variable
#' @examples
#' \dontrun{
#' bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
#'
#' # The long record: SeaWiFS chlorophyll from the late 1990s
#' early <- accessOBDAAC(vars = "CHL", years = 1998, months = 1:12,
#'                       bounding_box = bb, frequency = "monthly",
#'                       sensor = "SEAWIFS")
#'
#' # Light and clarity alongside chlorophyll, from Aqua
#' light <- accessOBDAAC(vars = c("CHL", "PAR", "KD490"),
#'                       dates = unique(observations$date), bounding_box = bb)
#'
#' matched <- matchData(observations, light)
#' }
#' @seealso [obdaac_sensors()], [obdaac_variables()], [accessERDDAP()] for
#'   satellite fields that need no account, [fill_satellite_gaps()] for cloud
#'   gaps
#' @export
accessOBDAAC <- function(vars, years = NULL, months = NULL, bounding_box,
                         dates = NULL, frequency = c("daily", "monthly"),
                         sensor = "MODISA", resolution = "4km",
                         overwrite = FALSE) {
  if (identical(frequency, "8day")) {
    stop("OB.DAAC publishes eight-day composites, but this package cannot join ",
         "them honestly:\nmatchData() joins on an hour, a day, a month or a ",
         "year, and an eight-day bin is none\nof those. Use frequency = ",
         "\"monthly\", or fill_satellite_gaps() on the daily field.",
         call. = FALSE)
  }

  if (!requireNamespace("ncdf4", quietly = TRUE)) {
    stop("Reading OB.DAAC needs the ncdf4 package, which datamatch suggests ",
         "rather than requires.\nInstall it with:  install.packages(\"ncdf4\")",
         call. = FALSE)
  }

  sensors <- obdaac_sensors()
  if (!sensor %in% names(sensors)) {
    stop("Unknown OB.DAAC sensor '", sensor, "'. Available: ",
         paste(names(sensors), collapse = ", "), call. = FALSE)
  }
  spec <- sensors[[sensor]]

  if (!resolution %in% spec$resolutions) {
    stop(sensor, " is published at ", paste(spec$resolutions, collapse = " and "),
         ", not at '", resolution, "'.", call. = FALSE)
  }

  catalog <- obdaac_variables()
  unknown <- setdiff(vars, names(catalog))
  if (length(unknown) > 0) {
    stop("Not OB.DAAC variables: ", paste(unknown, collapse = ", "),
         "\nAvailable: ", paste(names(catalog), collapse = ", "),
         call. = FALSE)
  }
  entries <- catalog[vars]

  absent <- vars[!vapply(entries, function(e) e$suite %in% spec$suites,
                         logical(1))]
  if (length(absent) > 0) {
    here <- names(catalog)[vapply(catalog, function(e) e$suite %in% spec$suites,
                                  logical(1))]
    stop(sensor, " does not publish: ", paste(absent, collapse = ", "),
         "\n  ", spec$label, " carries: ", paste(here, collapse = ", "),
         if (any(absent %in% c("SST", "SST_NIGHT")) && sensor == "SEAWIFS") {
           "\nSeaWiFS is an ocean colour sensor and measures no temperature."
         }, call. = FALSE)
  }

  frequency <- match.arg(frequency)

  if (!is.null(dates)) {
    if (!is.null(years) || !is.null(months)) {
      stop("`dates` already names which periods to read, so `years` and ",
           "`months` are not used with it.", call. = FALSE)
    }
    wanted <- parse_dates(dates)
  } else {
    if (is.null(years) || is.null(months)) {
      stop("`years` and `months` are required, unless `dates` names the ",
           "periods to read.", call. = FALSE)
    }
    wanted <- do.call(c, lapply(years, function(y) {
      do.call(c, lapply(months, function(m) {
        start <- lubridate::ymd(paste(y, m, 1, sep = "-"))
        if (frequency == "monthly") start else
          seq(start, by = "day", length.out = lubridate::days_in_month(start))
      }))
    }))
    wanted <- sort(unique(wanted))
  }

  stop_if_future(wanted, paste("OB.DAAC", sensor))

  before <- wanted < spec$start
  after <- if (is.na(spec$end)) rep(FALSE, length(wanted)) else wanted > spec$end
  if (all(before | after)) {
    stop(sensor, " ran from ", format(spec$start),
         if (is.na(spec$end)) " onward" else paste(" to", format(spec$end)),
         ", and every requested date is outside that.",
         "\nobdaac_sensors() lists which mission covers which years.",
         call. = FALSE)
  }
  if (any(before | after)) {
    warning(sum(before | after), " requested date(s) are outside ", sensor,
            "'s record (", format(spec$start),
            if (is.na(spec$end)) " onward" else paste(" to", format(spec$end)),
            ") and are skipped.", call. = FALSE)
    wanted <- wanted[!(before | after)]
  }

  # Monthly composites are one file per month, so many dates in a month name
  # the same file.
  keys <- if (frequency == "monthly") {
    as.Date(paste0(unique(format(wanted, "%Y-%m")), "-01"))
  } else {
    unique(wanted)
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
    sensor, resolution, frequency, paste(sort(vars), collapse = ","),
    paste(round(unlist(bounding_box[c("xmin", "xmax", "ymin", "ymax")]), 6),
          collapse = ","), sep = "|"))

  paths <- vapply(keys, function(when) {
    copernicus_cache("obdaac", paste0(key, "_", format(when, "%Y%m%d"), ".rds"))
  }, character(1))

  needed <- if (overwrite) rep(TRUE, length(keys)) else !file.exists(paths)
  if (!any(needed)) {
    return(obdaac_assemble(paths[file.exists(paths)], sensor, resolution,
                           frequency))
  }

  credentials <- obdaac_credentials()

  # Which file supplies which variable on which date, worked out before
  # anything is transferred so the size below is the whole request.
  work <- lapply(which(needed), function(i) {
    vapply(entries, function(e) {
      obdaac_filename(spec, e, keys[i], frequency, resolution)
    }, character(1))
  })
  names(work) <- as.character(which(needed))

  bytes <- length(unlist(work)) * obdaac_typical_bytes(resolution)
  if (bytes > 200e6) {
    message("OB.DAAC has no server-side subsetting, so each variable and date ",
            "is a whole global file.\nThis request needs ",
            length(unlist(work)), " of them, roughly ",
            round(bytes / 1024^3, 1), " GB of transfer, to keep the bounding ",
            "box from each.\nThe subsets are cached, so this is paid once.",
            if (resolution == "4km")
              " resolution = \"9km\" is about three times cheaper.")
  }

  failures <- character()
  for (i in which(needed)) {
    files <- work[[as.character(i)]]
    frame <- NULL
    for (name in vars) {
      raw <- copernicus_cache("obdaac", paste0("raw_", files[[name]]))
      failure <- obdaac_download(files[[name]], raw, credentials)
      if (!is.null(failure)) {
        failures <- c(failures, failure)
        frame <- NULL
        break
      }

      piece <- tryCatch(obdaac_read(raw, entries[[name]], bounding_box),
                        error = function(e) e)
      # The global file is a working file, not a cache entry: keeping every one
      # would fill a disk to save a download nobody repeats.
      unlink(raw)

      if (inherits(piece, "error")) {
        failures <- c(failures, paste0("  ", files[[name]], ": ",
                                       conditionMessage(piece)))
        frame <- NULL
        break
      }
      if (is.null(piece)) {
        stop("The bounding box selects no OB.DAAC cells. These are global ",
             "grids, so this means the\nbox itself is empty or outside -180 ",
             "to 180 and -90 to 90.", call. = FALSE)
      }

      names(piece)[names(piece) == entries[[name]]$variable] <- name
      frame <- if (is.null(frame)) piece else
        dplyr::left_join(frame, piece, by = c("x", "y"))
    }

    if (is.null(frame)) next

    frame$YEAR <- as.integer(format(keys[i], "%Y"))
    frame$MONTH <- as.integer(format(keys[i], "%m"))
    # A monthly composite is stamped on the month rather than on a day nothing
    # was measured on, which is what every monthly source here does.
    frame$DAY <- if (frequency == "monthly") 1L else
      as.integer(format(keys[i], "%d"))

    # Cloud, land and everything else the sensor did not see. A row with no
    # variable present is not a measurement.
    frame <- frame[rowSums(!is.na(frame[vars])) > 0, , drop = FALSE]
    rownames(frame) <- NULL
    saveRDS(frame, paths[i])
  }

  if (length(failures) > 0) {
    warning(length(failures), " time step(s) could not be read:\n",
            paste(utils::head(failures, 5), collapse = "\n"),
            if (length(failures) > 5) "\n  ..." else "",
            "\nThe steps that did succeed are cached, so re-running retries ",
            "only the failures.", call. = FALSE)
  }

  usable <- file.exists(paths)
  if (!any(usable)) {
    stop("No OB.DAAC data could be read for the requested period.",
         call. = FALSE)
  }
  obdaac_assemble(paths[usable], sensor, resolution, frequency)
}

#' Turn cached OB.DAAC subsets into the object a fetch returns
#'
#' Separate from [accessOBDAAC()] because a call that finds everything already
#' cached returns here without touching the network, credentials or the file
#' search - and that path has to build exactly the same object as the one that
#' downloaded it.
#'
#' @param paths <char> cached subset files
#' @param sensor,resolution,frequency <char> what produced them
#' @return <sf object> one row per grid cell per time step, stamped with its
#'   step and its source
#' @keywords internal
obdaac_assemble <- function(paths, sensor, resolution, frequency) {
  out <- sf::st_as_sf(dplyr::bind_rows(lapply(paths, readRDS)),
                      coords = c("x", "y"), crs = sf::st_crs(4326))
  attr(out, "datamatch_step") <- if (frequency == "monthly") "month" else "day"
  stamp_source(out, "obdaac", paste0(sensor, "-", resolution))
}

#' Printable dictionary of OB.DAAC variables
#'
#' @return a data frame of class `datamatch_dictionary`
#' @examples
#' obdaac_dictionary()
#' @seealso [obdaac_variables()], [obdaac_sensors()]
#' @export
obdaac_dictionary <- function() {
  catalog <- obdaac_variables()
  sensors <- obdaac_sensors()

  dictionary <- do.call(rbind, lapply(names(catalog), function(name) {
    entry <- catalog[[name]]
    carries <- names(sensors)[vapply(sensors, function(s) {
      entry$suite %in% s$suites
    }, logical(1))]
    data.frame(name = name, variable = entry$variable, label = entry$label,
               units = entry$units, source = entry$suite,
               layer = paste(carries, collapse = " "),
               description = entry$description, stringsAsFactors = FALSE)
  }))

  class(dictionary) <- c("datamatch_dictionary", "data.frame")
  # Named so print() describes this dictionary rather than guessing at it.
  attr(dictionary, "datamatch_family") <- "obdaac"
  dictionary
}
