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
    CHL = biogeochemical("chl", "Chlorophyll-a concentration", "mg/m3",
                         paste("Mass concentration of chlorophyll-a. A food",
                               "availability proxy; usually worth",
                               "log-transforming.")),
    NO3 = biogeochemical("no3", "Nitrate concentration", "mmol/m3",
                         "Mole concentration of nitrate, a limiting nutrient."),
    PO4 = biogeochemical("po4", "Phosphate concentration", "mmol/m3",
                         "Mole concentration of phosphate."),
    O2 = biogeochemical("o2", "Dissolved oxygen", "mmol/m3",
                        "Mole concentration of dissolved molecular oxygen."),
    NPP = biogeochemical("nppv", "Net primary production", "mg/m3/day",
                         paste("Net primary production of biomass expressed as",
                               "carbon. A direct productivity measure rather",
                               "than the standing stock chlorophyll reports.")),
    PH = biogeochemical("ph", "pH", "1", "Sea water pH reported on total scale.")
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
#'   `variable`, `label`, `units`, and `dataset`
#' @examples
#' variable_dictionary()
#' variable_dictionary("biogeochemical")
#'
#' # As a plain data frame, for programmatic use
#' as.data.frame(variable_dictionary())
#' @export
variable_dictionary <- function(product = c("all", "physical", "biogeochemical")) {
  product <- match.arg(product)
  catalog <- copernicus_variables()

  dictionary <- do.call(rbind, lapply(names(catalog), function(name) {
    entry <- catalog[[name]]
    data.frame(
      name = name, variable = entry$variable, label = entry$label,
      units = entry$units, dataset = entry$dataset_id,
      description = entry$description, stringsAsFactors = FALSE
    )
  }))

  if (product != "all") {
    is_physical <- grepl("_phy_", dictionary$dataset, fixed = TRUE)
    dictionary <- dictionary[if (product == "physical") is_physical else !is_physical, ]
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
  cat("Copernicus variables available by name\n")
  cat(strrep("-", 62), "\n", sep = "")

  # The description is the widest column by far and would wrap unreadably, so
  # the printed view drops it; it remains in the returned object.
  visible <- as.data.frame(x)[c("name", "variable", "label", "units")]
  print(visible, row.names = FALSE, right = FALSE)

  cat("\nPass a name to accessEnvDat(vars = ...), or the Copernicus code.\n")
  cat("Full descriptions: as.data.frame(variable_dictionary())$description\n")
  invisible(x)
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
    catalog <- copernicus_variables()
    grouped <- vapply(distinct, function(d) {
      paste(vars[datasets == d], collapse = ", ")
    }, character(1))
    stop("These variables come from different Copernicus datasets and cannot ",
         "be fetched together:\n  ",
         paste(paste0(grouped, "  ->  ", distinct), collapse = "\n  "),
         "\nCall accessEnvDat() once per dataset.", call. = FALSE)
  }

  catalog <- copernicus_variables()
  entry <- catalog[[vars[1]]]
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
  catalog <- copernicus_variables()
  stats::setNames(
    vapply(vars, function(v) {
      if (v %in% names(catalog)) catalog[[v]]$dataset_id else NA_character_
    }, character(1)),
    vars
  )
}
