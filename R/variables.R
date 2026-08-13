# Null-coalescing operator. Defined here rather than relying on base R's, which
# only exists from R 4.4 onward.
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Column names that mean day-of-year, not year or day-of-month
#'
#' `standardize_time_columns()` finds a table's time columns by prefix, which
#' sweeps in names that look right and mean something else: `yearday` begins with
#' `year`, `dayofyear` with `day`. Both hold an ordinal day, so accepting either
#' would put every row in a period no `source` covers - an all-NA join behind a
#' vague warning rather than an error.
#'
#' Names here are never candidates for any time column. They are still reported
#' as near misses when nothing else matches, so a caller who did mean one of them
#' is told to rename it rather than left guessing.
#'
#' Compared lower-case, so casing in the data does not matter. Extend it when
#' another convention turns up; the only effect of a name being listed is that
#' `matchData()` declines to guess.
#'
#' @return <char> lower-case day-of-year column names
#' @keywords internal
day_of_year_names <- c(
  "yearday", "year_day", "yday",
  "dayofyear", "day_of_year", "doy",
  "jday", "j_day", "julian", "julianday", "julian_day"
)

#' Catalog of Copernicus variables under familiar names
#'
#' Maps short names people actually use (`SST`, `CHL`, ...) onto the Copernicus
#' Marine product, dataset, and variable code that supply them. Copernicus codes
#' are terse and easy to misremember — `thetao` for temperature, `mlotst` for
#' mixed layer depth, `zos` for sea surface height — and getting one wrong
#' produces a failed download rather than an obvious mistake.
#'
#' Entries come from the global reanalyses: physical variables from
#' `GLOBAL_MULTIYEAR_PHY_001_030` (GLORYS12V1) and biogeochemical ones from
#' `GLOBAL_MULTIYEAR_BGC_001_029`.
#'
#' @section Monthly and daily:
#' `dataset_id` is the monthly mean; `daily_dataset_id` is the daily one, which
#' [accessEnvDat()] uses when given `frequency = "daily"`. It is `NA` where no
#' daily equivalent exists, and those gaps are not incidental:
#'
#' \itemize{
#'   \item **`PH`** — the daily biogeochemical reanalysis carries `chl`, `no3`,
#'     `nppv`, `o2`, `po4` and `si`, but not `ph`. Only the monthly mean has it.
#'   \item **`PP`** — Copernicus-GlobColour serves primary production as a
#'     monthly composite only.
#'   \item **`DIATO`, `DINO`** — the daily ocean colour dataset carries total
#'     chlorophyll alone. The phytoplankton functional types are monthly.
#' }
#'
#' `CHL` is the case worth reading twice. Daily ocean colour is not the monthly
#' product at a finer step: it is `l4-gapfree`, the space-time interpolated
#' field, because a single day of a single sensor is mostly cloud. The daily
#' values are therefore already gap-filled by Copernicus, and running
#' [fill_satellite_gaps()] over them fills nothing. [accessEnvDat()] says so
#' when it makes the substitution.
#'
#' Copernicus revises dataset identifiers periodically. If a fetch fails with an
#' unknown-dataset error, check the current identifier on the Copernicus Marine
#' Data Store and pass `dataset_id` explicitly.
#'
#' @return a named list, one entry per variable, each with `variable`, `label`,
#'   `units`, `product_id`, `dataset_id`, `daily_dataset_id`, and `description`
#' @examples
#' names(copernicus_variables())
#' copernicus_variables()$SST$variable
#' @seealso [variable_dictionary()] for a printable table
#' @export
copernicus_variables <- function() {
  phy_product <- "GLOBAL_MULTIYEAR_PHY_001_030"
  phy_dataset <- "cmems_mod_glo_phy_my_0.083deg_P1M-m"
  phy_daily <- "cmems_mod_glo_phy_my_0.083deg_P1D-m"
  bgc_product <- "GLOBAL_MULTIYEAR_BGC_001_029"
  bgc_dataset <- "cmems_mod_glo_bgc_my_0.25deg_P1M-m"
  bgc_daily <- "cmems_mod_glo_bgc_my_0.25deg_P1D-m"
  # Copernicus-GlobColour: satellite ocean colour rather than a model. Higher
  # resolution (4 km vs 0.25 degrees) and observed rather than simulated, but
  # surface-only and gappy under cloud.
  oc_product <- "OCEANCOLOUR_GLO_BGC_L4_MY_009_104"
  oc_plankton <- "cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M"
  oc_pp <- "cmems_obs-oc_glo_bgc-pp_my_l4-multi-4km_P1M"
  # Daily ocean colour is the gap-free interpolated field, not the monthly
  # composite at a finer step. See the Monthly and daily section.
  oc_plankton_daily <- "cmems_obs-oc_glo_bgc-plankton_my_l4-gapfree-multi-4km_P1D"

  physical <- function(variable, label, units, description) {
    list(variable = variable, label = label, units = units,
         product_id = phy_product, dataset_id = phy_dataset,
         daily_dataset_id = phy_daily, description = description)
  }
  # `daily` is an argument rather than a constant because the daily reanalysis
  # does not serve every variable the monthly mean does.
  biogeochemical <- function(variable, label, units, description,
                             daily = bgc_daily) {
    list(variable = variable, label = label, units = units,
         product_id = bgc_product, dataset_id = bgc_dataset,
         daily_dataset_id = daily, description = description)
  }
  satellite <- function(variable, label, units, description,
                        dataset_id = oc_plankton, daily = NA_character_) {
    list(variable = variable, label = label, units = units,
         product_id = oc_product, dataset_id = dataset_id,
         daily_dataset_id = daily, description = description)
  }

  list(
    SST = physical("thetao", "Sea surface temperature", "degrees C",
                   "Sea water potential temperature at the surface."),
    SSS = physical("so", "Sea surface salinity", "PSU",
                   "Sea water salinity at the surface."),
    BOTT = physical("bottomT", "Bottom temperature", "degrees C",
                    paste("Sea water potential temperature at the sea floor.",
                          "Relevant to overwintering copepod stages.")),
    UO = physical("uo", "Eastward current velocity", "m/s",
                  "Eastward component of sea water velocity."),
    VO = physical("vo", "Northward current velocity", "m/s",
                  "Northward component of sea water velocity."),
    SSH = physical("zos", "Sea surface height", "m",
                   paste("Sea surface height above geoid. A proxy for",
                         "mesoscale circulation features.")),
    MLD = physical("mlotst", "Mixed layer depth", "m",
                   paste("Ocean mixed layer thickness by a sigma-theta",
                         "criterion. Controls how deeply plankton are mixed.")),
    SIC = physical("siconc", "Sea ice concentration", "fraction",
                   "Fraction of the cell covered by sea ice."),
    # Satellite ocean colour is the default for chlorophyll and primary
    # production: observed rather than simulated, and 4 km rather than 0.25
    # degrees. The model equivalents remain available as CHL_MODEL and
    # NPP_MODEL, which are gap-free and depth-resolved where these are neither.
    CHL = satellite("CHL", "Chlorophyll-a concentration (satellite)", "mg/m3",
                    paste("Mass concentration of chlorophyll-a from",
                          "Copernicus-GlobColour. A food-availability proxy;",
                          "usually worth log-transforming. Surface only, and",
                          "gappy under persistent cloud - though the daily",
                          "field is the gap-free interpolated one."),
                    daily = oc_plankton_daily),
    PP = satellite("PP", "Primary production (satellite)", "mg/m2/day",
                   paste("Primary productivity of biomass expressed as carbon,",
                         "from Copernicus-GlobColour. A rate rather than the",
                         "standing stock chlorophyll reports. Note the areal",
                         "units: this is depth-integrated, unlike the",
                         "volumetric model NPP."),
                   dataset_id = oc_pp),
    DIATO = satellite("DIATO", "Diatom chlorophyll-a concentration", "mg/m3",
                      paste("Mass concentration of diatoms expressed as",
                            "chlorophyll in sea water. Large, fast-growing",
                            "cells that dominate the spring bloom and are the",
                            "preferred prey of large copepods.")),
    DINO = satellite("DINO", "Dinophyte chlorophyll-a concentration", "mg/m3",
                     paste("Mass concentration of dinophytes",
                           "(dinoflagellates) expressed as chlorophyll in sea",
                           "water. Typically later in the season than diatoms",
                           "and favoured by stratified, low-nutrient water.")),
    NO3 = biogeochemical("no3", "Nitrate concentration", "mmol/m3",
                         "Mole concentration of nitrate, a limiting nutrient."),
    PO4 = biogeochemical("po4", "Phosphate concentration", "mmol/m3",
                         "Mole concentration of phosphate."),
    O2 = biogeochemical("o2", "Dissolved oxygen", "mmol/m3",
                        "Mole concentration of dissolved molecular oxygen."),
    # The daily biogeochemical reanalysis omits ph; only the monthly mean has it.
    PH = biogeochemical("ph", "pH", "unitless",
                        paste("Sea water pH on the total scale. A logarithmic",
                              "ratio, so it has no units - and for the same",
                              "reason should not be averaged directly.",
                              "Monthly only."),
                        daily = NA_character_),
    CHL_MODEL = biogeochemical("chl", "Chlorophyll-a concentration (model)",
                               "mg/m3",
                               paste("Chlorophyll-a from the biogeochemistry",
                                     "reanalysis. Coarser than the satellite",
                                     "CHL but gap-free, so preferable where",
                                     "cloud cover would leave holes.")),
    NPP_MODEL = biogeochemical("nppv", "Net primary production (model)",
                               "mg/m3/day",
                               paste("Net primary production from the",
                                     "biogeochemistry reanalysis. Volumetric,",
                                     "unlike the depth-integrated satellite PP,",
                                     "so the two are not interchangeable."))
  )
}

#' Copernicus Marine product page for a product identifier
#'
#' Where to check a product's coverage, resolution, revision history, and
#' citation. Dataset identifiers change from time to time, and this is the page
#' that says what the current one is.
#'
#' @param product_id a Copernicus product identifier
#' @return the product page URL
#' @examples
#' product_url("GLOBAL_MULTIYEAR_PHY_001_030")
#' @export
product_url <- function(product_id) {
  paste0("https://data.marine.copernicus.eu/product/", product_id, "/description")
}

#' Forecast equivalents of the catalog variables
#'
#' Where the reanalysis has a hindcast, the analysis-and-forecast products have a
#' near-real-time equivalent running to about ten days ahead. This maps each
#' catalog name onto the forecast product, dataset, and code that supply it.
#'
#' Two things make this a real mapping rather than a substitution of one
#' identifier for another:
#'
#' \itemize{
#'   \item **The forecast products split variables across datasets.** The
#'     reanalysis serves all its physics from one dataset; the forecast has
#'     separate ones for temperature, salinity, and currents. So a forecast fetch
#'     of SST and SSS is two requests where the reanalysis is one.
#'   \item **Some codes differ.** Bottom temperature is `bottomT` in the
#'     reanalysis and `tob` in the forecast. Reusing the reanalysis code would
#'     produce a failed download.
#' }
#'
#' Satellite variables have no forecast: ocean colour is observation, and an
#' observation of the future does not exist. `CHL`, `PP`, `DIATO`, and `DINO` are
#' therefore absent here, and asking for them in forecast mode says so.
#'
#' @return a named list keyed by catalog name, each with `variable`,
#'   `product_id`, `dataset_id`, and `daily_dataset_id`
#' @examples
#' names(forecast_variables())
#' forecast_variables()$BOTT$variable   # "tob", not "bottomT"
#' @seealso [accessEnvDat()], which takes `mode = "forecast"`
#' @export
forecast_variables <- function() {
  phy <- "GLOBAL_ANALYSISFORECAST_PHY_001_024"
  bgc <- "GLOBAL_ANALYSISFORECAST_BGC_001_028"

  # Unlike the reanalysis, every analysis-and-forecast dataset here is published
  # at both steps under the same name, so the daily identifier is the monthly one
  # with its frequency token swapped rather than a separate entry.
  entry <- function(variable, product_id, dataset_id) {
    list(variable = variable, product_id = product_id, dataset_id = dataset_id,
         daily_dataset_id = sub("_P1M-m$", "_P1D-m", dataset_id))
  }
  physics <- function(variable, dataset) {
    entry(variable, phy, paste0("cmems_mod_glo_phy", dataset, "_anfc_0.083deg_P1M-m"))
  }
  biogeochemistry <- function(variable, dataset) {
    entry(variable, bgc, paste0("cmems_mod_glo_bgc-", dataset, "_anfc_0.25deg_P1M-m"))
  }

  list(
    SST  = physics("thetao", "-thetao"),
    SSS  = physics("so", "-so"),
    UO   = physics("uo", "-cur"),
    VO   = physics("vo", "-cur"),
    # The merged physics dataset, which carries the surface and sea-floor fields.
    SSH  = physics("zos", ""),
    MLD  = physics("mlotst", ""),
    SIC  = physics("siconc", ""),
    BOTT = physics("tob", ""),

    NO3       = biogeochemistry("no3", "nut"),
    PO4       = biogeochemistry("po4", "nut"),
    O2        = biogeochemistry("o2", "bio"),
    NPP_MODEL = biogeochemistry("nppv", "bio"),
    CHL_MODEL = biogeochemistry("chl", "pft"),
    PH        = biogeochemistry("ph", "car")
  )
}

#' Printable dictionary of variable names
#'
#' The catalog as a data frame: what each short name means, its units, and the
#' Copernicus code and dataset behind it. Print it to see what is available
#' without leaving the console.
#'
#' @param product filter to `"physical"`, `"biogeochemical"`, or `"all"`
#' @return a data frame of class `datamatch_dictionary` with columns `name`,
#'   `variable`, `label`, `units`, `product`, `dataset`, `url`, and `description`
#' @examples
#' variable_dictionary()
#' variable_dictionary("biogeochemical")
#'
#' # As a plain data frame, for programmatic use
#' as.data.frame(variable_dictionary())
#'
#' # The product page for a variable, to check its coverage and revisions
#' as.data.frame(variable_dictionary())[c("name", "url")]
#' @export
variable_dictionary <- function(product = c("all", "physical", "biogeochemical",
                                            "satellite")) {
  product <- match.arg(product)
  catalog <- copernicus_variables()

  dictionary <- do.call(rbind, lapply(names(catalog), function(name) {
    entry <- catalog[[name]]
    data.frame(
      name = name, variable = entry$variable, label = entry$label,
      units = entry$units, product = entry$product_id, dataset = entry$dataset_id,
      url = product_url(entry$product_id),
      description = entry$description, stringsAsFactors = FALSE
    )
  }))

  if (product != "all") {
    family <- ifelse(grepl("obs-oc", dictionary$dataset, fixed = TRUE), "satellite",
                     ifelse(grepl("_phy_", dictionary$dataset, fixed = TRUE),
                            "physical", "biogeochemical"))
    dictionary <- dictionary[family == product, ]
    rownames(dictionary) <- NULL
  }

  class(dictionary) <- c("datamatch_dictionary", "data.frame")
  dictionary
}

#' @param x a `datamatch_dictionary`
#' @param ... ignored
#' @rdname variable_dictionary
#' @export
print.datamatch_dictionary <- function(x, ...) {
  flat <- as.data.frame(x)
  cat("Copernicus variables available by name\n")
  cat(strrep("-", 66), "\n", sep = "")

  # Descriptions, dataset identifiers and URLs are all far too wide to tabulate
  # and would wrap unreadably. Provenance is listed per product underneath
  # instead, so it stays visible without destroying the table.
  visible <- flat[c("name", "variable", "label", "units")]
  print(visible, row.names = FALSE, right = FALSE)

  for (product in unique(flat$product)) {
    rows <- flat$product == product
    cat("\n", product, "\n", sep = "")
    cat("  variables: ", paste(flat$name[rows], collapse = ", "), "\n", sep = "")
    # The dataset identifier is what accessEnvDat() actually requests, and what
    # has to be corrected by hand when Copernicus revises one.
    cat("  dataset:   ", unique(flat$dataset[rows]), "\n", sep = "")
    cat("  docs:      ", product_url(product), "\n", sep = "")
  }

  cat("\nPass a name to accessEnvDat(vars = ...), or the Copernicus code.\n")
  cat("With every variable from one product, product_id and dataset_id can be\n")
  cat("omitted - they are inferred from the names.\n")
  cat("Full descriptions: as.data.frame(variable_dictionary())$description\n")
  invisible(x)
}

#' Render a dictionary as a markdown table
#'
#' The console view is a fixed-width table, which turns to mush when pasted into
#' a README or a notebook. This emits a pipe table instead, so a dictionary can
#' be dropped straight into documentation.
#'
#' @param x a dictionary from [variable_dictionary()] or [index_dictionary()]
#' @param columns which columns to include; defaults to the readable subset
#' @return a character vector of markdown lines, invisibly; printed as a
#'   side effect
#' @examples
#' as_markdown(variable_dictionary())
#'
#' # Include the dataset identifiers as well
#' as_markdown(variable_dictionary(), columns = c("name", "variable", "dataset"))
#' @export
as_markdown <- function(x, columns = NULL) {
  flat <- as.data.frame(x)
  columns <- columns %||% intersect(
    c("name", "variable", "label", "units", "source"), names(flat)
  )
  missing <- setdiff(columns, names(flat))
  if (length(missing) > 0) {
    stop("Column(s) not in the dictionary: ", paste(missing, collapse = ", "),
         "\nAvailable: ", paste(names(flat), collapse = ", "), call. = FALSE)
  }
  flat <- flat[columns]

  # Pipe characters would split a cell into two columns.
  cells <- lapply(flat, function(column) gsub("|", "\\|", as.character(column),
                                               fixed = TRUE))
  widths <- vapply(seq_along(cells), function(i) {
    max(nchar(c(columns[i], cells[[i]])))
  }, integer(1))

  # Padded so the raw markdown lines up in a text editor too, not only once
  # rendered. formatC takes a scalar width, hence the elementwise mapply.
  pad <- function(values, width) {
    mapply(function(value, w) formatC(value, width = -w, flag = " "),
           values, width, USE.NAMES = FALSE)
  }
  row <- function(values) paste0("| ", paste(values, collapse = " | "), " |")

  lines <- c(
    row(pad(columns, widths)),
    row(vapply(widths, function(w) strrep("-", w), character(1))),
    vapply(seq_len(nrow(flat)), function(i) {
      row(vapply(seq_along(cells), function(j) pad(cells[[j]][i], widths[j]),
                 character(1)))
    }, character(1))
  )

  # writeLines rather than cat(sep = "\n"), which leaves a trailing blank line.
  writeLines(lines)
  invisible(lines)
}

#' Resolve variable names to Copernicus codes
#'
#' Accepts either a catalog name (`"SST"`) or a raw Copernicus code
#' (`"thetao"`), so existing calls that pass codes keep working unchanged.
#'
#' @param vars variable names or codes
#' @param mode `"reanalysis"` or `"forecast"`
#' @return a list with `codes` (Copernicus codes, in the given order) and
#'   `names` (what each should be called in the result)
#' @keywords internal
resolve_variables <- function(vars, mode = c("reanalysis", "forecast")) {
  mode <- match.arg(mode)
  catalog <- copernicus_variables()
  known_codes <- vapply(catalog, function(entry) entry$variable, character(1))

  codes <- character(length(vars))
  for (i in seq_along(vars)) {
    entry <- catalog_entry(vars[i], mode = mode)
    if (!is.null(entry)) {
      # In forecast mode this is the forecast code, which is not always the
      # reanalysis one - bottom temperature is bottomT then tob.
      codes[i] <- entry$variable
    } else if (vars[i] %in% names(catalog)) {
      codes[i] <- catalog[[vars[i]]]$variable
    } else if (vars[i] %in% known_codes) {
      # Already a Copernicus code.
      codes[i] <- vars[i]
    } else {
      # Not in the catalog at all. Copernicus serves far more than this catalog
      # covers, so an unrecognized string is passed through as a code rather
      # than rejected - but say so, since a typo looks identical.
      warning("'", vars[i], "' is not in the variable dictionary; passing it to ",
              "Copernicus as a variable code. See variable_dictionary() for ",
              "known names.", call. = FALSE)
      codes[i] <- vars[i]
    }
  }

  list(codes = unname(codes), names = vars)
}

#' Infer the product and dataset from a set of variable names
#'
#' When every requested variable is in the catalog, the product and dataset are
#' implied, so a call need not repeat identifiers that are already known.
#'
#' Variables from different datasets cannot be fetched in one request, so mixing
#' them is an error here rather than a confusing failure at the API.
#'
#' @param vars variable names
#' @param mode `"reanalysis"` or `"forecast"`
#' @param frequency `"monthly"` or `"daily"`
#' @return `list(product_id =, dataset_id =)`
#' @keywords internal
infer_dataset <- function(vars, mode = c("reanalysis", "forecast"),
                          frequency = c("monthly", "daily")) {
  mode <- match.arg(mode)
  frequency <- match.arg(frequency)

  # A variable can be in the catalog and still have no daily dataset. That is a
  # different problem from not being in the catalog at all, and saying so - with
  # what to do instead - beats an unknown-dataset error from the client.
  if (frequency == "daily") {
    in_catalog <- vars[!is.na(variable_dataset(vars, mode = mode))]
    no_daily <- in_catalog[is.na(variable_dataset(in_catalog, mode = mode,
                                                  frequency = "daily"))]
    if (length(no_daily) > 0) {
      stop("Copernicus publishes no daily dataset for: ",
           paste(no_daily, collapse = ", "),
           "\nThese variables are monthly composites only. Fetch them with ",
           "frequency = \"monthly\", in a separate call from any daily ones.",
           call. = FALSE)
    }
  }

  datasets <- variable_dataset(vars, mode = mode, frequency = frequency)

  unknown <- vars[is.na(datasets)]
  if (length(unknown) > 0) {
    # Satellite variables are the common case in forecast mode, and "not in the
    # catalog" would be misleading: they exist, but only as observations.
    satellite <- intersect(unknown, names(copernicus_variables()))
    if (mode == "forecast" && length(satellite) > 0) {
      stop("No forecast exists for: ", paste(satellite, collapse = ", "),
           "\nThese are satellite observations, and there is no observation of ",
           "the future. Use the model equivalents (CHL_MODEL, NPP_MODEL) in ",
           "forecast mode.", call. = FALSE)
    }
    stop("Cannot infer the dataset for: ", paste(unknown, collapse = ", "),
         "\nEither use a name from variable_dictionary(), or pass product_id ",
         "and dataset_id explicitly.", call. = FALSE)
  }

  distinct <- unique(unname(datasets))
  if (length(distinct) > 1) {
    grouped <- vapply(distinct, function(d) {
      paste(vars[datasets == d], collapse = ", ")
    }, character(1))
    stop("These variables come from different Copernicus datasets and cannot ",
         "be fetched together:\n  ",
         paste(paste0(grouped, "  ->  ", distinct), collapse = "\n  "),
         if (mode == "forecast") {
           paste0("\nThe forecast products split variables across datasets more ",
                  "than the reanalysis does, so a set that fetches in one ",
                  "request as reanalysis may need several as forecast.")
         },
         "\nCall accessEnvDat() once per dataset.", call. = FALSE)
  }

  entry <- catalog_entry(vars[1], mode = mode)
  dataset_id <- if (frequency == "daily") entry$daily_dataset_id else entry$dataset_id

  # Daily ocean colour is a different product from the monthly composite, not
  # the same one at a finer step. Substituting it silently would leave a caller
  # to discover from the interpolation that their "observations" are modelled.
  if (frequency == "daily" && grepl("l4-gapfree", dataset_id, fixed = TRUE)) {
    message("Daily ocean colour comes from the gap-free interpolated dataset (",
            dataset_id, "),\nwhere cloud gaps are filled by Copernicus rather ",
            "than left as NA. fill_satellite_gaps()\nhas nothing to do on it.")
  }

  list(product_id = entry$product_id, dataset_id = dataset_id)
}

#' Look up the dataset a set of variables comes from
#'
#' Variables in one Copernicus dataset can be fetched together; variables from
#' different datasets cannot. This reports which dataset each name belongs to so
#' a caller can group them.
#'
#' @param vars variable names from the catalog
#' @param mode `"reanalysis"` (the default) or `"forecast"`
#' @param frequency `"monthly"` (the default) or `"daily"`
#' @return a named character vector of dataset identifiers, `NA` for names not in
#'   the catalog and, when `frequency = "daily"`, for catalog variables that have
#'   no daily dataset
#' @examples
#' variable_dataset(c("SST", "SSS", "CHL"))
#'
#' # PP and the phytoplankton types are monthly composites only
#' variable_dataset(c("SST", "CHL", "PP"), frequency = "daily")
#' @export
variable_dataset <- function(vars, mode = c("reanalysis", "forecast"),
                             frequency = c("monthly", "daily")) {
  mode <- match.arg(mode)
  frequency <- match.arg(frequency)
  stats::setNames(
    vapply(vars, function(v) {
      entry <- catalog_entry(v, mode = mode)
      if (is.null(entry)) return(NA_character_)
      # %||% covers an entry predating daily_dataset_id rather than one
      # declaring no daily dataset, which is NA and passes through as itself.
      if (frequency == "daily") entry$daily_dataset_id %||% NA_character_
      else entry$dataset_id
    }, character(1)),
    vars
  )
}

#' Catalog entry for a name or a Copernicus code
#'
#' Either identifier resolves, so a call that passes raw codes gets the same
#' dataset inference as one using catalog names.
#'
#' @param var a catalog name (`"SST"`) or a Copernicus code (`"thetao"`)
#' @param mode `"reanalysis"` or `"forecast"`
#' @return the catalog entry, or `NULL` if the variable is not in the catalog
#' @keywords internal
catalog_entry <- function(var, mode = "reanalysis") {
  catalog <- copernicus_variables()

  if (mode == "forecast") {
    forecast <- forecast_variables()
    # A code may be given instead of a name, so map it back to its name first.
    name <- if (var %in% names(catalog)) {
      var
    } else {
      codes <- vapply(catalog, function(entry) entry$variable, character(1))
      match <- which(codes == var)
      if (length(match) == 1) names(catalog)[match] else var
    }
    if (name %in% names(forecast)) {
      # The label, units and description are the same quantity in either mode;
      # only the identifiers differ.
      return(utils::modifyList(catalog[[name]] %||% list(), forecast[[name]]))
    }
    return(NULL)
  }

  if (var %in% names(catalog)) return(catalog[[var]])

  codes <- vapply(catalog, function(entry) entry$variable, character(1))
  match <- which(codes == var)
  if (length(match) == 1) catalog[[match]] else NULL
}
