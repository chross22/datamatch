# Null-coalescing operator. Defined here rather than relying on base R's, which
# only exists from R 4.4 onward.
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Catalog of Copernicus variables under familiar names
#'
#' Maps short names people actually use (`SST`, `CHL`, ...) onto the Copernicus
#' Marine product, dataset, and variable code that supply them. Copernicus codes
#' are terse and easy to misremember — `thetao` for temperature, `mlotst` for
#' mixed layer depth, `zos` for sea surface height — and getting one wrong
#' produces a failed download rather than an obvious mistake.
#'
#' All entries are monthly means from the global reanalyses: physical variables
#' from `GLOBAL_MULTIYEAR_PHY_001_030` (GLORYS12V1) and biogeochemical ones from
#' `GLOBAL_MULTIYEAR_BGC_001_029`.
#'
#' Copernicus revises dataset identifiers periodically. If a fetch fails with an
#' unknown-dataset error, check the current identifier on the Copernicus Marine
#' Data Store and pass `dataset_id` explicitly.
#'
#' @return a named list, one entry per variable, each with `variable`, `label`,
#'   `units`, `product_id`, `dataset_id`, and `description`
#' @examples
#' names(copernicus_variables())
#' copernicus_variables()$SST$variable
#' @seealso [variable_dictionary()] for a printable table
#' @export
copernicus_variables <- function() {
  phy_product <- "GLOBAL_MULTIYEAR_PHY_001_030"
  phy_dataset <- "cmems_mod_glo_phy_my_0.083deg_P1M-m"
  bgc_product <- "GLOBAL_MULTIYEAR_BGC_001_029"
  bgc_dataset <- "cmems_mod_glo_bgc_my_0.25deg_P1M-m"
  # Copernicus-GlobColour: satellite ocean colour rather than a model. Higher
  # resolution (4 km vs 0.25 degrees) and observed rather than simulated, but
  # surface-only and gappy under cloud.
  oc_product <- "OCEANCOLOUR_GLO_BGC_L4_MY_009_104"
  oc_plankton <- "cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M"
  oc_pp <- "cmems_obs-oc_glo_bgc-pp_my_l4-multi-4km_P1M"

  physical <- function(variable, label, units, description) {
    list(variable = variable, label = label, units = units,
         product_id = phy_product, dataset_id = phy_dataset,
         description = description)
  }
  biogeochemical <- function(variable, label, units, description) {
    list(variable = variable, label = label, units = units,
         product_id = bgc_product, dataset_id = bgc_dataset,
         description = description)
  }
  satellite <- function(variable, label, units, description,
                        dataset_id = oc_plankton) {
    list(variable = variable, label = label, units = units,
         product_id = oc_product, dataset_id = dataset_id,
         description = description)
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
                          "gappy under persistent cloud.")),
    PP = satellite("PP", "Primary production (satellite)", "mg/m2/day",
                   paste("Primary productivity of biomass expressed as carbon,",
                         "from Copernicus-GlobColour. A rate rather than the",
                         "standing stock chlorophyll reports. Note the areal",
                         "units: this is depth-integrated, unlike the",
                         "volumetric model NPP."),
                   dataset_id = oc_pp),
    DIATO = satellite("DIATO", "Diatom chlorophyll", "mg/m3",
                      paste("Mass concentration of diatoms expressed as",
                            "chlorophyll. Large, fast-growing cells that",
                            "dominate the spring bloom and are the preferred",
                            "prey of large copepods.")),
    DINO = satellite("DINO", "Dinophyte chlorophyll", "mg/m3",
                     paste("Mass concentration of dinophytes",
                           "(dinoflagellates) expressed as chlorophyll.",
                           "Typically later in the season than diatoms and",
                           "favoured by stratified, low-nutrient water.")),
    NO3 = biogeochemical("no3", "Nitrate concentration", "mmol/m3",
                         "Mole concentration of nitrate, a limiting nutrient."),
    PO4 = biogeochemical("po4", "Phosphate concentration", "mmol/m3",
                         "Mole concentration of phosphate."),
    O2 = biogeochemical("o2", "Dissolved oxygen", "mmol/m3",
                        "Mole concentration of dissolved molecular oxygen."),
    PH = biogeochemical("ph", "pH", "1", "Sea water pH reported on total scale."),
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
#' @return a list with `codes` (Copernicus codes, in the given order) and
#'   `names` (what each should be called in the result)
#' @keywords internal
resolve_variables <- function(vars) {
  catalog <- copernicus_variables()
  known_codes <- vapply(catalog, function(entry) entry$variable, character(1))

  codes <- character(length(vars))
  for (i in seq_along(vars)) {
    if (vars[i] %in% names(catalog)) {
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
#' @return `list(product_id =, dataset_id =)`
#' @keywords internal
infer_dataset <- function(vars) {
  datasets <- variable_dataset(vars)

  unknown <- vars[is.na(datasets)]
  if (length(unknown) > 0) {
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
         "\nCall accessEnvDat() once per dataset.", call. = FALSE)
  }

  entry <- catalog_entry(vars[1])
  list(product_id = entry$product_id, dataset_id = entry$dataset_id)
}

#' Look up the dataset a set of variables comes from
#'
#' Variables in one Copernicus dataset can be fetched together; variables from
#' different datasets cannot. This reports which dataset each name belongs to so
#' a caller can group them.
#'
#' @param vars variable names from the catalog
#' @return a named character vector of dataset identifiers, `NA` for names not in
#'   the catalog
#' @examples
#' variable_dataset(c("SST", "SSS", "CHL"))
#' @export
variable_dataset <- function(vars) {
  stats::setNames(
    vapply(vars, function(v) {
      entry <- catalog_entry(v)
      if (is.null(entry)) NA_character_ else entry$dataset_id
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
#' @return the catalog entry, or `NULL` if the variable is not in the catalog
#' @keywords internal
catalog_entry <- function(var) {
  catalog <- copernicus_variables()
  if (var %in% names(catalog)) return(catalog[[var]])

  codes <- vapply(catalog, function(entry) entry$variable, character(1))
  match <- which(codes == var)
  if (length(match) == 1) catalog[[match]] else NULL
}
