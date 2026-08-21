#' The CEFI regional MOM6 runs this package ships with
#'
#' CEFI is NOAA's Changing Ecosystems and Fisheries Initiative, and the part of
#' it this package reads is the regional MOM6-COBALT output published by the
#' Physical Sciences Laboratory. What is built in here is the **Northwest
#' Atlantic** domain (NWA12) — the US east coast, the Gulf of Mexico and the
#' Caribbean, at a twelfth of a degree.
#'
#' @section Why reach for it:
#' Every other model in this package is global, run once for the whole ocean and
#' sampled wherever you happen to work. NWA12 is the opposite: a regional
#' configuration built for this shelf, with a coupled biogeochemistry (COBALT)
#' that carries nutrients, oxygen, carbonate chemistry and plankton biomass on
#' the same grid as the physics. The Copernicus biogeochemical reanalysis is a
#' quarter degree; this is a twelfth, and it resolves the Gulf of Maine and the
#' Scotian Shelf rather than smoothing across them.
#'
#' It also publishes **sea-floor salinity directly** as `sob`, where GLORYS12V1
#' does not — so `BOTS` from CEFI is the model's own diagnostic rather than the
#' deepest-wet-level derivation [accessCopernicus()] has to fall back on.
#'
#' @section The regridded product is what is read:
#' MOM6 runs on a curvilinear grid, and CEFI publishes both that (`raw`) and a
#' regular latitude-longitude interpolation of it (`regrid`). This package reads
#' the regridded files, because a regular grid is what everything downstream
#' here expects and what makes an NWA12 field overlay a Copernicus one.
#'
#' That is a real choice and not a free one: the regridding is bilinear, so
#' values near the coast and near the ice edge have been interpolated across
#' cells the model treated separately. Where that matters, read the `raw` files
#' yourself rather than through this.
#'
#' The velocities are the exception worth naming. CEFI publishes `uo_rotate` and
#' `vo_rotate`, already rotated onto true east and north, so `UO` and `VO` here
#' are in the same frame as every other source rather than in the model's own
#' grid directions.
#'
#' @section Hindcast and forecast are different products:
#' `hindcast` is a reconstruction forced by reanalysis and is the entry to reach
#' for. `decadal_forecast` is a ten-year prediction initialised each January,
#' with ten ensemble members, and is a fundamentally different kind of number —
#' see the Forecasts are experimental section of [accessCEFI()].
#'
#' @return a named list, one entry per archive, each with `path`, `domain`,
#'   `experiment`, `frequency`, `grid`, `release`, `kind`, `start`, `end`,
#'   `variables`, `label` and `reference`
#' @examples
#' names(cefi_archives())
#' cefi_archives()$NWA12$path
#' @seealso [accessCEFI()], [cefi_archive()] for any other CEFI path
#' @export
cefi_archives <- function() {
  list(
    NWA12 = list(
      path = paste0("Projects/CEFI/regional_mom6/cefi_portal/",
                    "northwest_atlantic/full_domain/hindcast"),
      domain = "northwest_atlantic",
      label_tag = "NWA12",
      experiment = "hindcast",
      grid = "regrid",
      release = "latest",
      kind = "hindcast",
      start = as.Date("1993-01-01"),
      end = as.Date("2023-12-31"),
      label = paste("CEFI regional MOM6-COBALT, Northwest Atlantic (NWA12),",
                    "hindcast, regridded"),
      reference = cefi_reference()
    ),

    # The decadal prediction. Listed so it can be named, but read only with an
    # `init` and a `member`, because neither has a defensible default - see the
    # Forecasts are experimental section of accessCEFI().
    NWA12_DECADAL = list(
      path = paste0("Projects/CEFI/regional_mom6/cefi_portal/",
                    "northwest_atlantic/full_domain/decadal_forecast"),
      domain = "northwest_atlantic",
      label_tag = "NWA12",
      experiment = "decadal_forecast",
      grid = "regrid",
      release = "latest",
      kind = "decadal forecast",
      # Bounded by the initialisations published rather than by a continuous
      # record: each file is ten years from its own January.
      start = as.Date("1965-01-01"),
      end = NA,
      experimental = TRUE,
      label = paste("CEFI regional MOM6-COBALT, Northwest Atlantic (NWA12),",
                    "decadal forecast, regridded"),
      reference = cefi_reference()
    )
  )
}

#' The CEFI citation, which is one reference for every run
#'
#' @return <char> the reference
#' @keywords internal
cefi_reference <- function() {
  paste("Ross AC, Stock CA, Adcroft A, et al. (2023). A high-resolution",
        "physical-biogeochemical model for marine resource applications in",
        "the northwest Atlantic (MOM6-COBALT-NWA12 v1.0).",
        "Geoscientific Model Development 16:6943-6985.",
        "doi:10.5194/gmd-16-6943-2023")
}

#' The THREDDS server CEFI is published on
#'
#' Held in one place because it appears in three: the catalog walk that finds
#' filenames, the OPeNDAP endpoint that reads them, and the error messages that
#' say where a failed request went.
#'
#' @return <char> the server root, with no trailing slash
#' @keywords internal
cefi_server <- function() {
  getOption("datamatch.cefi_server", "https://psl.noaa.gov/thredds")
}

#' Catalog of CEFI variables under familiar names
#'
#' Maps the names this package uses everywhere else onto the MOM6-COBALT
#' variable each comes from. The model's own names are terse and easy to
#' confuse — `tos` is the surface temperature and `tob` the sea-floor one,
#' `sos` and `sob` the salinities beside them — and a wrong one fetches a real
#' field of the wrong quantity rather than failing.
#'
#' @section Units are converted, and that is the point:
#' A covariate is only interchangeable across sources if it arrives in the same
#' units, so four of these are converted on the way out rather than passed
#' through:
#'
#' \itemize{
#'   \item **`CHL`** — COBALT writes `chlos` in kg m-3. Multiplied by 1e6 to
#'     give mg/m3, which is what Copernicus and the satellite products use.
#'   \item **`NO3`, `PO4`, `O2`** — written in mol m-3, multiplied by 1000 to
#'     give mmol/m3.
#'   \item **`BOTO2`** — `btm_o2` is mol kg-1, multiplied by 1e6 to give
#'     umol/kg, which is what oxygen per unit mass is conventionally reported
#'     in and puts it on the same scale as `O2`'s mmol/m3. Note the basis:
#'     this is **per kilogram of seawater**, where `O2` is per cubic metre.
#'     Seawater is about 1025 kg/m3, so the two are close but not equal, and
#'     converting between them needs a density. That is why they are
#'     deliberately not given the same name.
#' }
#'
#' The conversion factor is in each entry's `scale`, so what was done to a
#' value is readable rather than buried in the reader.
#'
#' @section What is monthly and what is also daily:
#' The NWA12 hindcast saves everything monthly. Its **daily** output is
#' biogeochemistry only — `CHL`, `NO3`, `PH`, `PCO2`, `PHYC`, `MESOZOO` and
#' `BOTO2` — and carries no temperature, salinity, sea surface height, mixed
#' layer depth, ice or velocity at all. `daily` in each entry records that, and
#' [accessCEFI()] refuses a daily request for a monthly-only variable rather
#' than returning an empty join.
#'
#' @section Primary production is not here:
#' COBALT writes `intpp`, which is production integrated over the water column
#' in mol m-2 s-1. The package's `PP` is the satellite product's volumetric
#' rate in mg/m2/day. They are different quantities measured on different
#' bases, and giving them one name would make a nonsense of any comparison, so
#' CEFI simply has no `PP`. `MESOZOO` has the same shape of caveat — it is a
#' 200 m integral, in mol m-2 — and is given its own name for that reason.
#'
#' @return a named list, one entry per variable, each with `variable`, `label`,
#'   `units`, `scale`, `daily`, `surface_of` and `description`
#' @examples
#' names(cefi_variables())
#' cefi_variables()$BOTS$variable
#' @seealso [accessCEFI()], [cefi_dictionary()] for a printable table
#' @export
cefi_variables <- function() {
  entry <- function(variable, label, units, description, scale = 1,
                    daily = FALSE, surface_of = FALSE) {
    list(variable = variable, label = label, units = units, scale = scale,
         daily = daily, surface_of = surface_of, description = description)
  }

  list(
    SST = entry("tos", "Sea surface temperature", "degrees C",
                paste("Sea surface temperature from the topmost model level.",
                      "A model temperature rather than a satellite foundation",
                      "temperature; see accessERDDAP() for the difference.")),
    SSS = entry("sos", "Sea surface salinity", "PSU",
                "Sea surface salinity from the topmost model level."),
    BOTT = entry("tob", "Bottom temperature", "degrees C",
                 paste("Sea water potential temperature at the sea floor.",
                       "Relevant to overwintering copepod stages.")),
    # The one CEFI publishes and GLORYS12V1 does not. No derivation, no
    # BOTS_depth column, and not the same number as the derived Copernicus one.
    BOTS = entry("sob", "Bottom salinity", "PSU",
                 paste("Sea water salinity at the sea floor, as the model's",
                       "own diagnostic. Unlike the Copernicus reanalysis, CEFI",
                       "publishes this directly, so it is not derived from the",
                       "three-dimensional field.")),
    SSH = entry("ssh", "Sea surface height", "m",
                "Sea surface height. A proxy for mesoscale circulation."),
    MLD = entry("MLD_003", "Mixed layer depth", "m",
                paste("Mixed layer thickness by a 0.03 kg/m3 density",
                      "criterion. CEFI also publishes an energetic-mixing",
                      "definition as MLD_EN1, which is a different number;",
                      "this is the density one, to match Copernicus MLD.")),
    SIC = entry("siconc", "Sea ice concentration", "fraction",
                "Fraction of the cell covered by sea ice."),
    # Three-dimensional in the file. The topmost level is taken, which is what
    # every other surface field here is, and surface_of records that it was a
    # choice rather than the whole variable.
    UO = entry("uo_rotate", "Eastward current velocity", "m/s",
               paste("Eastward component of sea water velocity in the topmost",
                     "model level, rotated onto true east from the model's",
                     "curvilinear grid."),
               surface_of = TRUE),
    VO = entry("vo_rotate", "Northward current velocity", "m/s",
               paste("Northward component of sea water velocity in the topmost",
                     "model level, rotated onto true north from the model's",
                     "curvilinear grid."),
               surface_of = TRUE),
    CHL = entry("chlos", "Chlorophyll-a concentration (model)", "mg/m3",
                paste("Surface chlorophyll simulated by COBALT. A model field,",
                      "not a satellite retrieval: it has no cloud gaps and",
                      "needs no gap filling, and it is not the same number as",
                      "the CHL from accessERDDAP() or accessCopernicus()."),
                scale = 1e6, daily = TRUE),
    NO3 = entry("no3os", "Nitrate concentration", "mmol/m3",
                "Surface dissolved nitrate.", scale = 1000, daily = TRUE),
    PO4 = entry("po4os", "Phosphate concentration", "mmol/m3",
                "Surface dissolved inorganic phosphorus.", scale = 1000),
    O2 = entry("o2os", "Dissolved oxygen", "mmol/m3",
               "Surface dissolved oxygen.", scale = 1000),
    PH = entry("phos", "pH", "unitless", "Surface pH.", daily = TRUE),
    BOTO2 = entry("btm_o2", "Bottom dissolved oxygen", "umol/kg",
                  paste("Dissolved oxygen at the sea floor, per kilogram of",
                        "seawater rather than per cubic metre. Hypoxia near",
                        "the bottom is what this is for. Not comparable to O2",
                        "without a density."),
                  scale = 1e6, daily = TRUE),
    PCO2 = entry("pco2surf", "Surface partial pressure of CO2", "uatm",
                 paste("Oceanic pCO2 at the surface. With PH, what an",
                       "acidification question needs."),
                 daily = TRUE),
    PHYC = entry("phycos", "Phytoplankton carbon", "mol/m3",
                 paste("Surface phytoplankton carbon concentration, summed",
                       "over COBALT's functional types."),
                 daily = TRUE),
    MESOZOO = entry("mesozoo_200", "Mesozooplankton biomass", "mol/m2",
                    paste("Mesozooplankton biomass integrated over the top",
                          "200 m. An areal integral rather than a",
                          "concentration, which is why it has its own name."),
                    daily = TRUE)
  )
}

#' The filenames one CEFI directory publishes
#'
#' @section Why the server is asked rather than the name constructed:
#' A CEFI filename carries the release and the period it covers —
#' `tos.nwa.full.hcast.monthly.regrid.r20250715.199301-202312.nc` — so
#' constructing one means hard-coding both. Both move: the hindcast has been
#' released twice already, and each release extends the record, so a name built
#' from last year's constants fetches nothing the moment CEFI publishes again.
#'
#' The directory listing is read instead, which costs one request and is right
#' by construction. It is memoised for the session, because a fetch of eight
#' variables would otherwise read the same listing eight times.
#'
#' @param path <char> the catalog path, as in a [cefi_archives()] entry
#' @param frequency <char> `"monthly"` or `"daily"`
#' @param grid <char> `"regrid"` or `"raw"`
#' @param release <char> a release directory, or `"latest"`
#' @return <char> the `.nc` filenames in that directory, possibly empty
#' @keywords internal
cefi_catalog_files <- function(path, frequency, grid, release) {
  url <- paste(cefi_server(), "catalog", path, frequency, grid, release,
               "catalog.xml", sep = "/")

  cached <- cefi_listings[[url]]
  if (!is.null(cached)) return(cached)

  xml <- tryCatch(readLines(url, warn = FALSE),
                  error = function(e) conditionMessage(e),
                  warning = function(w) conditionMessage(w))

  if (!is.character(xml) || length(xml) < 2) {
    stop("Could not read the CEFI catalog at\n  ", url,
         "\nThe PSL THREDDS server may be down, or this combination of ",
         "experiment, frequency,\ngrid and release may not exist.",
         call. = FALSE)
  }

  text <- paste(xml, collapse = "")
  found <- regmatches(text, gregexpr('name="[^"]+\\.nc"', text))[[1]]
  files <- unique(sub('^name="(.*)"$', "\\1", found))

  cefi_listings[[url]] <- files
  files
}

# Directory listings already read this session, so a fetch of eight variables
# reads one catalog rather than eight identical ones.
cefi_listings <- new.env(parent = emptyenv())

#' The file in a CEFI directory that holds one variable
#'
#' Matched on the leading segment of the name, which is the variable, so `tos`
#' does not also match `tossq` — the squared field beside it, which is a
#' different quantity and would read without complaint.
#'
#' @param files <char> filenames, as [cefi_catalog_files()] returns
#' @param variable <char> the MOM6 variable name
#' @param init <char> an initialisation tag such as `"i198001"`, for the
#'   forecast archives that publish one file per initialisation; `NULL` for the
#'   hindcast, which publishes one file per variable
#' @return <char> one filename, or `NA` if the variable is not published here
#' @keywords internal
cefi_file_for <- function(files, variable, init = NULL) {
  hit <- files[startsWith(files, paste0(variable, "."))]
  if (!is.null(init)) hit <- hit[grepl(paste0("\\.", init, "\\."), hit)]

  if (length(hit) == 0) return(NA_character_)
  # More than one is possible where a directory holds several periods. The last
  # in sort order is the most recent, which is the one to read.
  sort(hit)[length(hit)]
}

#' Group indices into contiguous runs
#'
#' A fetch usually wants a scattered handful of time steps — survey dates, or a
#' month from each of ten years. Reading each with its own DAP request is one
#' round trip per step; reading the whole span between the first and the last
#' transfers everything in between. Runs are the middle: contiguous stretches
#' become one request each, and a gap ends a run rather than being read across.
#'
#' @param i <integer> indices, in any order
#' @return a list of integer vectors, each contiguous and increasing
#' @keywords internal
contiguous_runs <- function(i) {
  i <- sort(unique(as.integer(i)))
  if (length(i) == 0) return(list())
  split(i, cumsum(c(1L, diff(i) != 1L)))
}

#' Open a CEFI OPeNDAP endpoint, with a readable failure
#'
#' @param url <char> the `dodsC` URL
#' @return an open `ncdf4` handle; the caller closes it
#' @keywords internal
cefi_open <- function(url) {
  if (!requireNamespace("ncdf4", quietly = TRUE)) {
    stop("Reading CEFI needs the ncdf4 package, which datamatch suggests ",
         "rather than requires.\nInstall it with:  install.packages(\"ncdf4\")",
         call. = FALSE)
  }

  handle <- tryCatch(ncdf4::nc_open(url), error = function(e) e)
  if (inherits(handle, "error")) {
    stop("Could not open the CEFI endpoint\n  ", url, "\n",
         conditionMessage(handle),
         "\nThe PSL THREDDS server is sometimes down, and a request that ",
         "spans too much\nof a file can exceed its 500 MB limit. Try a ",
         "smaller bounding box or fewer dates.",
         call. = FALSE)
  }
  handle
}

#' Describe any CEFI directory, so it can be read like a built-in one
#'
#' [cefi_archives()] ships the Northwest Atlantic hindcast and its decadal
#' forecast, because that is the domain this package was written for. CEFI also
#' publishes the Northeast Pacific, the Arctic, the Pacific Islands and the
#' Great Lakes, on the same server in the same layout, and this is how to reach
#' them: give it a catalog path and it reads the directory to work out the rest.
#'
#' @section What it checks:
#' The catalog is read once, so a path that is wrong, a release that does not
#' exist, or a server that is down fails here — with the reason — rather than
#' part-way through a fetch. The variables actually published in that directory
#' come back in the returned spec, so `str()` on it says what is there.
#'
#' @param path <char> the catalog path under the THREDDS root, as in a
#'   [cefi_archives()] entry's `path`
#' @param frequency <char> `"monthly"` or `"daily"`
#' @param grid <char> `"regrid"` for the regular latitude-longitude
#'   interpolation, or `"raw"` for the model's own curvilinear grid. This
#'   package reads `"regrid"`; `"raw"` will open but not read, because the
#'   reader assumes a regular grid.
#' @param release <char> a release directory such as `"r20250715"`, or
#'   `"latest"`
#' @param label <char> a human-readable name; defaults to the path
#' @return a list in the shape [cefi_archives()] entries take, ready to pass to
#'   [accessCEFI()] as `archive`
#' @examples
#' \dontrun{
#' pacific <- cefi_archive(paste0("Projects/CEFI/regional_mom6/cefi_portal/",
#'                                "northeast_pacific/full_domain/hindcast"))
#' str(pacific)
#' }
#' @seealso [accessCEFI()], [cefi_archives()]
#' @export
cefi_archive <- function(path, frequency = c("monthly", "daily"),
                         grid = c("regrid", "raw"), release = "latest",
                         label = NULL) {
  frequency <- match.arg(frequency)
  grid <- match.arg(grid)

  files <- cefi_catalog_files(path, frequency, grid, release)
  if (length(files) == 0) {
    stop("The CEFI directory exists but publishes no files:\n  ",
         paste(cefi_server(), "catalog", path, frequency, grid, release,
               sep = "/"),
         "\nSome experiments are announced on the portal before any output is ",
         "posted.", call. = FALSE)
  }

  published <- unique(sub("\\..*$", "", files))
  catalog <- cefi_variables()

  spec <- list(
    path = path, domain = basename(dirname(dirname(path))),
    label_tag = toupper(substr(gsub("[^a-z]", "", basename(dirname(dirname(path)))), 1, 6)),
    experiment = basename(path),
    frequency = frequency, grid = grid, release = release,
    kind = basename(path), start = NA, end = NA,
    files = files,
    # Which of this package's names that directory can actually supply.
    variables = names(catalog)[vapply(catalog, function(e) {
      e$variable %in% published
    }, logical(1))],
    label = label %||% path, reference = cefi_reference())

  if (length(spec$variables) == 0) {
    warning("No variable this package knows is published in that directory. ",
            "It holds ", length(published), " field(s), the first few being: ",
            paste(utils::head(sort(published), 5), collapse = ", "),
            call. = FALSE)
  }
  spec
}

#' The CEFI experiments this package can and cannot read
#'
#' The portal publishes seven experiments for the Northwest Atlantic. Two are
#' readable, and the other five are refused here rather than being attempted —
#' each for a reason that has nothing to do with the caller and would otherwise
#' surface as an obscure failure a long way from its cause.
#'
#' @section Why the seasonal forecast is not among them:
#' Its files carry a 64-bit integer coordinate, which DAP2 has no type for, so
#' the PSL server answers `NcDDS Variable data type = long` with an HTTP 500 to
#' every classic OPeNDAP request for one. The DAP4 endpoint does describe them —
#' and then reads them wrongly: `ncdf4` transposes the start and count vectors
#' against the dimension order it reported, and the read segfaults R rather
#' than returning anything. A reader that crashes the session is worse than no
#' reader, so this refuses instead.
#'
#' The files are downloadable whole from the THREDDS `fileServer` endpoint and
#' open correctly once local, at roughly 260 MB per variable per
#' initialisation. That is the route if you need them.
#'
#' @section Why the projections are not among them:
#' `long_term_projection` and `multi_decadal_outlook` have directories on the
#' server and no files in them. The portal announces an experiment before its
#' output is posted, so this may simply be early; [cefi_archive()] will read
#' them the moment they appear.
#'
#' @return a named list, one entry per experiment, each with `readable` and
#'   `why`
#' @keywords internal
cefi_experiments <- function() {
  list(
    hindcast = list(readable = TRUE, why = NA_character_),
    decadal_forecast = list(readable = TRUE, why = NA_character_),
    seasonal_forecast = list(readable = FALSE, why = paste(
      "The seasonal forecast files carry a 64-bit integer coordinate. DAP2",
      "has no type for it, so\n  the server returns HTTP 500 for every",
      "OPeNDAP request; the DAP4 endpoint reads them\n  incorrectly and",
      "crashes R. Download them whole from the THREDDS fileServer endpoint",
      "instead\n  (about 260 MB per variable per initialisation) and open the",
      "local file.")),
    seasonal_reforecast = list(readable = FALSE, why = paste(
      "The seasonal reforecast has the same 64-bit coordinate as the seasonal",
      "forecast, and the same\n  consequence: unreadable over OPeNDAP, and",
      "downloadable whole from the fileServer endpoint.")),
    long_term_projection = list(readable = FALSE, why = paste(
      "CEFI has a directory for the long-term projection but has posted no",
      "files in it yet.")),
    multi_decadal_outlook = list(readable = FALSE, why = paste(
      "CEFI has a directory for the multi-decadal outlook but has posted no",
      "files in it yet.")),
    seasonal_forecast_initialization = list(readable = FALSE, why = paste(
      "These are the states the seasonal forecast was started from rather than",
      "output to join to\n  observations."))
  )
}

#' Access CEFI regional MOM6 output
#'
#' Reads the NOAA CEFI regional ocean model over OPeNDAP and returns it as an
#' `sf` point object with one row per grid cell and time step — the same shape
#' [accessCopernicus()], [accessFVCOM()], [accessHYCOM()], [accessCCMP()] and
#' [accessERDDAP()] return, so [matchData()] joins it unchanged.
#'
#' @section Why reach for it, and why not:
#' On the Northwest Atlantic shelf this is the highest-resolution coupled
#' physics-and-biogeochemistry field available here: a twelfth of a degree for
#' both, against a quarter degree for the Copernicus biogeochemical reanalysis.
#' It carries nutrients, oxygen, pH, pCO2, phytoplankton carbon and
#' mesozooplankton biomass on the same grid as the temperature and salinity,
#' which no other source in this package does.
#'
#' Against that: **it is one region**. Outside roughly 98W-36W and 5N-58N there
#' is nothing to read, and a bounding box outside the domain is refused rather
#' than returning an empty join. It is also **a model throughout** — its `CHL`
#' is simulated, not retrieved, and is not the satellite `CHL` from
#' [accessERDDAP()] under another name.
#'
#' @section Forecasts are experimental:
#' `experiment = "decadal_forecast"` reads a prediction rather than a
#' reconstruction, and this package treats it as experimental: it warns on
#' every call, and it will not choose for you between the things a forecast
#' makes you choose.
#'
#' A decadal file is ten years from one January, and there are sixty of them,
#' so `init` says which initialisation to read. Each holds **ten ensemble
#' members**, so `member` says which. Neither has a defensible default and
#' neither is guessed:
#'
#' \itemize{
#'   \item The members are not repeats of one number. They are the model's own
#'     estimate of how uncertain it is, and averaging them is a modelling
#'     decision — a reasonable one, often the right one, but not one a fetch
#'     should make silently. Read the members you want and combine them
#'     yourself, so the combination is visible in your code.
#'   \item A year covered by several initialisations is covered by several
#'     different forecasts of it, at different lead times. Which one you mean
#'     is a question about your analysis, not about the archive.
#' }
#'
#' The source tag records both, so [source_of()] on the result says which
#' initialisation and which member produced it.
#'
#' @section What is monthly and what is also daily:
#' The hindcast saves everything monthly. Its **daily** output is
#' biogeochemistry only — see the section of the same name in
#' [cefi_variables()] — and a daily request for `SST` is refused with the list
#' of what is available daily rather than returning nothing.
#'
#' @section Longitude and the domain:
#' The regridded files are already on a -180 to 180 grid, so `bounding_box` is
#' given negative west as everywhere else in this package and needs no
#' conversion in either direction.
#'
#' @param vars <char> variables to read, from [cefi_variables()]
#' @param years <numeric> years to read. Required unless `dates` is given.
#' @param months <numeric> months to read. Required unless `dates` is given.
#' @param bounding_box <list> named list with `xmin`, `xmax`, `ymin`, `ymax`, or
#'   an `sf`/`sfc` object. Longitudes negative west.
#' @param dates the exact dates to read, as `YYYYMMDD` strings, `YYYY-MM-DD`
#'   strings, or `Date` objects
#' @param frequency <char> `"monthly"` (the default) or `"daily"`
#' @param experiment <char> which CEFI experiment to read. `"hindcast"` is the
#'   default; `"decadal_forecast"` is experimental. The rest are refused with
#'   the reason — see [cefi_experiments()].
#' @param init <char> for a forecast, which initialisation to read, as
#'   `"i198001"` or `"198001"`. Required for `"decadal_forecast"`.
#' @param member <integer> for a forecast, which ensemble member or members to
#'   read, from 1 to 10. Required for `"decadal_forecast"`. Several may be
#'   given, and each arrives as its own block of rows carrying its own source
#'   tag.
#' @param release <char> a release directory such as `"r20250715"`, or
#'   `"latest"` (the default), which follows whatever CEFI published last
#' @param archive a spec from [cefi_archive()], to read a domain this package
#'   does not ship. Overrides `experiment`, `frequency` and `release`.
#' @param overwrite <logical> re-read time steps already cached
#' @return <sf object> one row per grid cell per time step, with `YEAR`,
#'   `MONTH`, `DAY` and a column per requested variable
#' @examples
#' \dontrun{
#' bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
#'
#' # The hindcast, monthly
#' env <- accessCEFI(vars = c("SST", "BOTT", "BOTS"), years = 2015,
#'                   months = 1:12, bounding_box = bb)
#' source_of(env)
#' #> [1] "cefi:NWA12-hindcast-r20250715"
#'
#' # Daily biogeochemistry on survey dates
#' bgc <- accessCEFI(vars = c("CHL", "NO3", "PH"), frequency = "daily",
#'                   dates = unique(observations$date), bounding_box = bb)
#'
#' matched <- matchData(observations, bgc)
#' }
#' @seealso [cefi_variables()], [cefi_archives()], [cefi_archive()],
#'   [accessCopernicus()] for a global reanalysis to compare against
#' @export
accessCEFI <- function(vars, years = NULL, months = NULL, bounding_box,
                       dates = NULL, frequency = c("monthly", "daily"),
                       experiment = "hindcast", init = NULL, member = NULL,
                       release = "latest", archive = NULL, overwrite = FALSE) {
  frequency <- match.arg(frequency)

  if (is.null(archive)) {
    known <- cefi_experiments()
    if (!experiment %in% names(known)) {
      stop("Unknown CEFI experiment '", experiment, "'. Available: ",
           paste(names(known), collapse = ", "), call. = FALSE)
    }
    if (!known[[experiment]]$readable) {
      stop("CEFI's '", experiment, "' cannot be read through this package.\n  ",
           known[[experiment]]$why, call. = FALSE)
    }

    built_in <- cefi_archives()
    spec <- if (experiment == "hindcast") built_in$NWA12 else built_in$NWA12_DECADAL
    spec$frequency <- frequency
    spec$release <- release
  } else {
    spec <- archive
    frequency <- spec$frequency
    experiment <- spec$experiment
  }

  is_forecast <- !identical(spec$experiment, "hindcast")

  if (isTRUE(spec$experimental) || is_forecast) {
    warning("CEFI's ", spec$kind, " is a prediction, not a reconstruction, and ",
            "support for it here is\nexperimental: the ensemble and lead-time ",
            "structure is exposed rather than reduced, and\nthe result is one ",
            "member's forecast rather than a best estimate. Treat it as such, ",
            "and\nsay in any write-up which initialisation and member you ",
            "used - source_of() records both.", call. = FALSE)
  }

  catalog <- cefi_variables()
  unknown <- setdiff(vars, names(catalog))
  if (length(unknown) > 0) {
    stop("Not CEFI variables: ", paste(unknown, collapse = ", "),
         "\nAvailable: ", paste(names(catalog), collapse = ", "),
         if (any(unknown == "PP")) {
           paste0("\nCEFI has no PP. It writes intpp, production integrated ",
                  "over the water column in\nmol/m2/s, which is not the ",
                  "satellite PP's volumetric rate in mg/m2/day. See ",
                  "cefi_variables().")
         }, call. = FALSE)
  }
  entries <- catalog[vars]

  if (frequency == "daily") {
    monthly_only <- vars[!vapply(entries, function(e) e$daily, logical(1))]
    if (length(monthly_only) > 0) {
      daily_vars <- names(catalog)[vapply(catalog, function(e) e$daily,
                                          logical(1))]
      stop("The CEFI hindcast saves no daily ",
           paste(monthly_only, collapse = ", "),
           ". Its daily output is biogeochemistry only.",
           "\nAvailable daily: ", paste(daily_vars, collapse = ", "),
           "\nUse frequency = \"monthly\" for the rest.", call. = FALSE)
    }
  }

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

  # A hindcast cannot reach past today. A forecast can and is meant to, so the
  # future check is skipped for one - refusing 2035 would refuse the product.
  if (!is_forecast) stop_if_future(wanted, paste("CEFI", spec$kind))

  # Monthly output has one field per month, so many dates within a month name
  # the same field. Reduced here so the cache is keyed on what is fetched.
  keys <- if (frequency == "monthly") {
    unique(format(wanted, "%Y-%m"))
  } else {
    unique(format(wanted, "%Y-%m-%d"))
  }

  if (is_forecast) {
    if (is.null(init)) {
      stop("`init` is required for CEFI's ", spec$kind, ": each file is a ",
           "forecast from one\ninitialisation, and several cover any given ",
           "year. Give one, as \"i198001\" or \"198001\".",
           "\nWhich to use is a question about your analysis rather than ",
           "about the archive - see\nthe Forecasts are experimental section ",
           "of ?accessCEFI.", call. = FALSE)
    }
    init <- paste0("i", sub("^i", "", init))
    if (is.null(member)) {
      stop("`member` is required for CEFI's ", spec$kind, ": each file holds ",
           "ten ensemble members,\nand averaging them is a modelling decision ",
           "this will not make silently. Give one or\nseveral, as ",
           "member = 1 or member = 1:10, and combine them yourself.",
           call. = FALSE)
    }
    member <- as.integer(member)
  } else {
    if (!is.null(init) || !is.null(member)) {
      stop("`init` and `member` describe an ensemble forecast. The hindcast ",
           "is a single run with\nneither.", call. = FALSE)
    }
    member <- NA_integer_
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

  files <- spec$files %||% cefi_catalog_files(spec$path, frequency,
                                              spec$grid, spec$release)

  key <- short_hash(paste(
    spec$path, spec$grid, spec$release, frequency,
    paste(sort(vars), collapse = ","),
    paste(round(unlist(bounding_box[c("xmin", "xmax", "ymin", "ymax")]), 6),
          collapse = ","),
    init %||% "-", sep = "|"))

  # One cache entry per time step per member, so a second call for an
  # overlapping period reads what it already has and fetches only the rest.
  plan <- expand.grid(key = keys, member = member, stringsAsFactors = FALSE)
  plan$path <- vapply(seq_len(nrow(plan)), function(i) {
    copernicus_cache("cefi", paste0(
      key, "_", gsub("-", "", plan$key[i]),
      if (!is.na(plan$member[i])) paste0("_m", plan$member[i]) else "",
      ".rds"))
  }, character(1))

  needed <- if (overwrite) rep(TRUE, nrow(plan)) else !file.exists(plan$path)

  if (any(needed)) {
    resolved <- cefi_fetch(spec, entries, files, plan[needed, , drop = FALSE],
                           bounding_box, frequency, init)
    for (i in seq_along(resolved)) {
      if (!is.null(resolved[[i]])) saveRDS(resolved[[i]],
                                           plan$path[needed][i])
    }
  }

  usable <- file.exists(plan$path)
  if (!any(usable)) {
    stop("No CEFI data could be read for the requested period. The archive ",
         "runs from ",
         format(spec$start), if (!is.na(spec$end)) paste(" to", format(spec$end)),
         ".", call. = FALSE)
  }
  if (!all(usable)) {
    warning(sum(!usable), " of ", length(usable), " requested time step(s) are ",
            "not in this CEFI archive and were skipped.", call. = FALSE)
  }

  frame <- dplyr::bind_rows(lapply(plan$path[usable], readRDS))
  tags <- frame$.tag
  frame$.tag <- NULL

  out <- sf::st_as_sf(frame, coords = c("x", "y"), crs = sf::st_crs(4326))
  attr(out, "datamatch_step") <- if (frequency == "monthly") "month" else "day"
  stamp_source(out, "cefi", tags)
}

#' Decode a CEFI time axis into dates
#'
#' The hindcast calls its axis `time` and the forecasts call theirs `lead`, but
#' both are CF time in days since an epoch — a forecast's epoch being its own
#' initialisation, which is what makes a lead time placeable on a calendar at
#' all. So both decode the same way, and the reader does not need to know which
#' it is looking at.
#'
#' @param handle an open `ncdf4` handle
#' @return a list with `name`, the axis it found, and `dates`
#' @keywords internal
cefi_axis <- function(handle) {
  name <- intersect(c("time", "lead"), names(handle$dim))[1]
  if (is.na(name)) {
    stop("This CEFI file has neither a 'time' nor a 'lead' axis, so its ",
         "values cannot be placed in time.", call. = FALSE)
  }

  axis <- handle$dim[[name]]
  epoch <- as.Date(trimws(sub("^.*since\\s+", "", axis$units)))
  if (is.na(epoch)) {
    stop("Could not read the epoch from the CEFI axis units '", axis$units,
         "'.", call. = FALSE)
  }

  list(name = name, dates = epoch + axis$vals)
}

#' Read the requested time steps of one CEFI variable
#'
#' @section Why runs rather than steps or spans:
#' Reading each wanted step with its own request is one network round trip per
#' month, which for a decade is 120 of them. Reading everything between the
#' first and the last transfers the whole decade to keep ten months of it.
#' Contiguous runs are neither: a stretch of consecutive months is one request,
#' and a gap ends the run instead of being read across. See
#' [contiguous_runs()].
#'
#' @param handle an open `ncdf4` handle
#' @param entry one entry of [cefi_variables()]
#' @param index <integer> the axis indices to read
#' @param keep_lon,keep_lat <integer> the grid indices the bounding box selects
#' @param member <integer> which ensemble member, or `NA` for a single run
#' @return a named list of numeric vectors, one per requested index, each in
#'   `expand.grid(lon, lat)` order
#' @keywords internal
cefi_read_variable <- function(handle, entry, index, keep_lon, keep_lat,
                               member = NA_integer_) {
  dims <- vapply(handle$var[[entry$variable]]$dim, function(d) d$name,
                 character(1))
  axis <- intersect(c("time", "lead"), dims)[1]

  out <- vector("list", length(index))
  names(out) <- as.character(index)

  for (run in contiguous_runs(index)) {
    start <- count <- integer(length(dims))
    for (j in seq_along(dims)) {
      d <- dims[j]
      slice <- if (d == "lon") {
        c(min(keep_lon), length(keep_lon))
      } else if (d == "lat") {
        c(min(keep_lat), length(keep_lat))
      } else if (d == axis) {
        c(min(run), length(run))
      } else if (d == "member") {
        # An ensemble member is a separate realisation, not a level to average.
        c(member, 1L)
      } else if (isTRUE(entry$surface_of)) {
        # A depth axis on a variable declared surface-only: the topmost level is
        # taken, which is what every other surface field here is.
        c(1L, 1L)
      } else {
        stop("CEFI variable '", entry$variable, "' has an unexpected '", d,
             "' axis, so which slice of it to read is not defined.",
             call. = FALSE)
      }
      start[j] <- slice[1]
      count[j] <- slice[2]
    }

    block <- ncdf4::ncvar_get(handle, entry$variable, start = start,
                              count = count, collapse_degen = FALSE)
    # Degenerate axes are kept above so this shape is known: lon, lat, then the
    # remaining axes in file order, of which only the time one is not length 1.
    dim(block) <- c(length(keep_lon), length(keep_lat), length(run))

    for (k in seq_along(run)) {
      out[[as.character(run[k])]] <- as.numeric(block[, , k]) * entry$scale
    }
  }
  out
}

#' The release a CEFI filename came from
#'
#' `release = "latest"` is how to follow whatever CEFI published most recently,
#' and it is the default because a pinned release goes stale. It is a terrible
#' thing to record, though: a result tagged `latest` says only that it was
#' fetched at some point, and two runs a year apart carry the same tag and
#' different numbers.
#'
#' So the tag is taken from the filename actually read, which names its release
#' outright. What a caller asked for and what they got are different questions,
#' and provenance is the second one.
#'
#' @param file <char> a CEFI filename
#' @param fallback <char> what to report if the name carries no release
#' @return <char> the release, as `"r20250715"`
#' @keywords internal
cefi_release_of <- function(file, fallback = "unknown-release") {
  found <- regmatches(file, regexpr("r[0-9]{8}", file))
  if (length(found) == 0) fallback else found
}

#' A list name for one ensemble member
#'
#' The hindcast is a single run and carries `NA` where a forecast carries a
#' member number. `as.character(NA_integer_)` is `NA_character_`, which cannot
#' name a list element, so the single-run case is named rather than converted.
#'
#' @param m <integer> a member number, or `NA`
#' @return <char> a usable list name
#' @keywords internal
member_key <- function(m) if (is.na(m)) "single" else as.character(m)

#' Fetch the CEFI time steps that are not already cached
#'
#' @param spec an archive spec
#' @param entries the requested entries of [cefi_variables()]
#' @param files <char> the directory listing
#' @param plan a data frame of `key` and `member`, one row per wanted step
#' @param bounding_box <list> the box, negative west
#' @param frequency <char> `"monthly"` or `"daily"`
#' @param init <char> the initialisation tag, or `NULL`
#' @return a list aligned with `plan`'s rows, each a data frame or `NULL` where
#'   the archive does not cover that step
#' @keywords internal
cefi_fetch <- function(spec, entries, files, plan, bounding_box, frequency,
                       init) {
  vars <- names(entries)
  endpoint <- function(file) {
    paste(cefi_server(), "dodsC", spec$path, frequency, spec$grid,
          spec$release, file, sep = "/")
  }

  missing_here <- vapply(entries, function(e) {
    is.na(cefi_file_for(files, e$variable, init))
  }, logical(1))
  if (any(missing_here)) {
    stop("This CEFI directory does not publish: ",
         paste(vars[missing_here], collapse = ", "),
         "\n  ", endpoint(""),
         "\nA different release or frequency may carry them; cefi_archive() ",
         "lists what one holds.", call. = FALSE)
  }

  # The grid and the axis are shared across a directory's files, so they are
  # read once from the first variable rather than once per variable.
  # Recorded before anything is read, so the tag names the release the values
  # came from rather than the alias that was asked for.
  release <- cefi_release_of(cefi_file_for(files, entries[[1]]$variable, init),
                             fallback = spec$release)

  first <- cefi_open(endpoint(cefi_file_for(files, entries[[1]]$variable, init)))
  lon <- as.numeric(first$dim$lon$vals)
  lat <- as.numeric(first$dim$lat$vals)
  axis <- cefi_axis(first)
  ncdf4::nc_close(first)

  keep_lon <- which(lon >= bounding_box[["xmin"]] & lon <= bounding_box[["xmax"]])
  keep_lat <- which(lat >= bounding_box[["ymin"]] & lat <= bounding_box[["ymax"]])
  if (length(keep_lon) == 0 || length(keep_lat) == 0) {
    stop("The bounding box selects no CEFI cells. This is a regional model:\n  ",
         spec$label, "\nIt covers ", sprintf("%.1f", min(lon)), " to ",
         sprintf("%.1f", max(lon)), " degrees east and ",
         sprintf("%.1f", min(lat)), " to ", sprintf("%.1f", max(lat)),
         " north.\nLongitudes are negative west here, and these files are ",
         "already on that convention.", call. = FALSE)
  }

  # Which axis step each wanted key is, or NA where the archive does not reach
  # it. Monthly output is stamped mid-month, so a month is matched rather than
  # a day.
  stamps <- if (frequency == "monthly") format(axis$dates, "%Y-%m") else
    format(axis$dates, "%Y-%m-%d")
  plan$index <- match(plan$key, stamps)

  reachable <- !is.na(plan$index)
  grid <- expand.grid(x = lon[keep_lon], y = lat[keep_lat])

  values <- list()
  for (name in vars) {
    handle <- cefi_open(endpoint(cefi_file_for(files, entries[[name]]$variable,
                                               init)))
    # Closed explicitly below on the happy path; this is what closes it when a
    # read fails part-way and the error propagates out of the loop.
    on.exit(if (!is.null(handle)) try(ncdf4::nc_close(handle), silent = TRUE),
            add = TRUE)

    values[[name]] <- list()
    # Members are read separately because each is its own realisation and they
    # are not contiguous in the way a run of months is.
    for (m in unique(plan$member[reachable])) {
      rows <- reachable & plan$member %in% m
      values[[name]][[member_key(m)]] <- cefi_read_variable(
        handle, entries[[name]], plan$index[rows], keep_lon, keep_lat, m)
    }
    ncdf4::nc_close(handle)
    handle <- NULL
  }

  lapply(seq_len(nrow(plan)), function(i) {
    if (!reachable[i]) return(NULL)

    frame <- grid
    for (name in vars) {
      frame[[name]] <- values[[name]][[member_key(plan$member[i])]][[
        as.character(plan$index[i])]]
    }

    when <- axis$dates[plan$index[i]]
    frame$YEAR <- as.integer(format(when, "%Y"))
    frame$MONTH <- as.integer(format(when, "%m"))
    # Monthly fields are stamped mid-month in the file. The day is set to 1 so
    # the stamp names the month rather than a day nothing was measured on,
    # which is what every monthly source here does.
    frame$DAY <- if (frequency == "monthly") 1L else
      as.integer(format(when, "%d"))

    frame$.tag <- paste0(
      spec$label_tag %||% "NWA12", "-", spec$experiment, "-", release,
      if (!is.null(init)) paste0("-", init) else "",
      if (!is.na(plan$member[i])) sprintf("-m%02d", plan$member[i]) else "")

    # Land and, in the forecasts, cells outside the domain. A row with no
    # variable present is not a measurement of anything.
    frame <- frame[rowSums(!is.na(frame[vars])) > 0, , drop = FALSE]
    rownames(frame) <- NULL
    frame
  })
}

#' Printable dictionary of CEFI variables
#'
#' @return a data frame of class `datamatch_dictionary`
#' @examples
#' cefi_dictionary()
#' @seealso [cefi_variables()]
#' @export
cefi_dictionary <- function() {
  catalog <- cefi_variables()

  dictionary <- do.call(rbind, lapply(names(catalog), function(name) {
    entry <- catalog[[name]]
    data.frame(name = name, variable = entry$variable, label = entry$label,
               units = entry$units, source = "CEFI",
               layer = if (entry$daily) "monthly, daily" else "monthly",
               description = entry$description, stringsAsFactors = FALSE)
  }))

  class(dictionary) <- c("datamatch_dictionary", "data.frame")
  # Named so print() describes this dictionary rather than guessing at it.
  attr(dictionary, "datamatch_family") <- "cefi"
  dictionary
}
