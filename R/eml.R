#' Units this package uses, mapped onto the EML vocabulary
#'
#' EML validates units against a fixed list, and rejects a document using a name
#' that is not on it. Several of this package's units are not: **`PSU` and
#' `N/m2` are both invalid as standard units**, which matters because salinity
#' and wind stress are core variables here. Those are emitted as *custom* units
#' instead, declared in the document's own `unitList`, which is the mechanism EML
#' provides for exactly this and is what data repositories expect.
#'
#' Which names are valid was established by validating documents against the
#' schema rather than by reading a list — `milligramsPerCubicMeter` is accepted
#' and `milligramPerCubicMeter` is not, and there is no way to tell from the
#' outside which spelling a vocabulary chose. The vocabulary is not even
#' self-consistent about it: `milligramsPerCubicMeter` is plural on both words
#' and `molePerCubicMeter` singular on both, and both are standard.
#'
#' @section The unit type is not checked:
#' EML validates a *unit* name against its vocabulary but accepts any string as
#' a custom unit's `unitType` — a deliberately nonsensical one passes the
#' schema. So the types below are not kept honest by anything except being
#' written honestly, which is worth knowing before copying one.
#'
#' @return a data frame with `units` (as this package writes them), `eml`, and
#'   `standard` (whether it is a standard EML unit or needs declaring)
#' @keywords internal
eml_unit_table <- function() {
  standard <- function(units, eml) {
    data.frame(units = units, eml = eml, standard = TRUE, type = NA_character_,
               description = NA_character_, stringsAsFactors = FALSE)
  }
  custom <- function(units, eml, type, description) {
    data.frame(units = units, eml = eml, standard = FALSE, type = type,
               description = description, stringsAsFactors = FALSE)
  }

  rbind(
    standard("degrees C", "celsius"),
    standard("m", "meter"),
    standard("m/s", "metersPerSecond"),
    standard("mg/m3", "milligramsPerCubicMeter"),
    standard("mol/m3", "molePerCubicMeter"),
    standard("W/m2", "wattPerMeterSquared"),
    standard("fraction", "dimensionless"),
    standard("unitless", "dimensionless"),
    standard("standardized anomaly", "dimensionless"),
    standard("count", "number"),

    custom("PSU", "practicalSalinityUnit", "dimensionless",
           paste("Practical salinity on the Practical Salinity Scale 1978,",
                 "which is a ratio and therefore dimensionless.")),
    custom("N/m2", "newtonPerSquareMeter", "pressure",
           "Newtons per square metre, the SI unit of surface stress."),
    custom("mg/m2/day", "milligramsPerSquareMeterPerDay", "arealMassDensityRate",
           paste("Milligrams per square metre per day: a depth-integrated",
                 "production rate.")),
    custom("mg/m3/day", "milligramsPerCubicMeterPerDay", "massDensityRate",
           "Milligrams per cubic metre per day: a volumetric production rate."),
    custom("mmol/m3", "millimolesPerCubicMeter", "amountOfSubstanceConcentration",
           "Millimoles per cubic metre, a molar concentration."),
    custom("Sv", "sverdrup", "volumetricRate",
           "Sverdrup: one million cubic metres per second of volume transport."),
    custom("degrees", "degree", "angle",
           "Degrees of arc, for a direction such as slope aspect."),

    # CEFI and OB.DAAC brought these. Only mol/m3 turned out to have a standard
    # spelling; the rest are declared.
    custom("umol/kg", "micromolesPerKilogram",
           "amountOfSubstancePerUnitMass",
           paste("Micromoles per kilogram of seawater. Dissolved oxygen is",
                 "conventionally reported per unit mass rather than per unit",
                 "volume, and converting between the two needs a density.")),
    custom("uatm", "microatmosphere", "pressure",
           paste("Microatmospheres: the conventional unit for the partial",
                 "pressure of carbon dioxide in seawater.")),
    custom("mol/m2", "molesPerSquareMeter", "arealAmountOfSubstanceDensity",
           paste("Moles per square metre: an amount integrated over the water",
                 "column rather than a concentration in it.")),
    custom("1/m", "perMeter", "lengthReciprocal",
           paste("Reciprocal metres, as a diffuse attenuation coefficient:",
                 "the rate at which light is extinguished with depth.")),
    custom("einstein/m2/day", "einsteinPerSquareMeterPerDay",
           "arealAmountOfSubstanceRate",
           paste("Einsteins per square metre per day: a mole of photons",
                 "reaching a square metre of sea surface over a day.")),
    custom("W/m2/um/sr", "wattPerSquareMeterPerMicrometerPerSteradian",
           "spectralRadiance",
           paste("Watts per square metre per micrometre per steradian: a",
                 "spectral radiance, as fluorescence line height is."))
  )
}

#' Everything the catalogs know about a variable name
#'
#' Each source catalog holds a label and units for the names it offers, and EML
#' wants both for every column. Gathered here so a matched table can be
#' described without the caller repeating what the package already knows.
#'
#' Every catalog has to be listed here, and nothing enforces that: a source
#' added without being added here still fetches, still joins, and then writes
#' EML in which its columns have no definition and no units. The unit table test
#' catches a unit with no mapping, not a catalog with no entry.
#'
#' Where two sources define the same name — which is the whole point of the
#' shared vocabulary — the first found wins. They agree on units by construction;
#' a test checks that.
#'
#' @return a named list, one entry per known variable, each with `label` and
#'   `units`
#' @keywords internal
known_variables <- function() {
  out <- list()

  add <- function(name, label, units) {
    if (is.null(out[[name]])) out[[name]] <<- list(label = label, units = units)
  }

  for (name in names(copernicus_variables())) {
    entry <- copernicus_variables()[[name]]
    add(name, entry$label, entry$units)
  }
  for (name in names(fvcom_variables())) {
    entry <- fvcom_variables()[[name]]
    add(name, entry$label, entry$units)
  }
  for (name in names(hycom_variables())) {
    entry <- hycom_variables()[[name]]
    add(name, entry$label, entry$units)
  }
  for (name in names(ccmp_variables())) {
    entry <- ccmp_variables()[[name]]
    add(name, entry$label, entry$units)
  }
  for (name in names(cefi_variables())) {
    entry <- cefi_variables()[[name]]
    add(name, entry$label, entry$units)
  }
  for (spec in erddap_datasets()) {
    for (name in names(spec$variables)) {
      add(name, spec$label, unname(spec$units[name]))
    }
  }
  for (name in names(obdaac_variables())) {
    entry <- obdaac_variables()[[name]]
    add(name, entry$label, entry$units)
  }
  for (name in names(bathymetry_variables())) {
    entry <- bathymetry_variables()[[name]]
    add(name, entry$label %||% name, entry$units %||% "unitless")
  }
  for (name in names(climate_indices())) {
    entry <- climate_indices()[[name]]
    add(name, entry$label %||% name, entry$units %||% "standardized anomaly")
  }

  out
}

#' Describe one column as an EML attribute
#'
#' @param name <char> the column name
#' @param values the column itself, which decides the measurement scale
#' @return a list in EML `attribute` shape
#' @keywords internal
eml_attribute <- function(name, values) {
  known <- known_variables()[[name]]
  units <- eml_unit_table()

  # The time columns and the provenance columns are described here rather than
  # left to the caller, because they are this package's own convention and it
  # knows what they mean.
  definition <- if (!is.null(known)) {
    known$label
  } else if (name %in% time_columns()) {
    paste0("Calendar ", tolower(name), " of the observation, UTC.")
  } else if (grepl("_source$", name)) {
    paste0("Which data source and archive supplied ",
           sub("_source$", "", name), ", written as source:archive.")
  } else if (grepl("_depth$", name)) {
    paste0("Depth in metres the ", sub("_depth$", "", name),
           " value was taken from.")
  } else if (name %in% c("LON", "LAT")) {
    paste0(if (name == "LON") "Longitude" else "Latitude",
           " of the feature, decimal degrees. For a line or polygon this is a ",
           "representative point on it rather than the geometry.")
  } else {
    paste0("Column '", name, "'.")
  }

  # A source or any other text column is nominal; everything else is a ratio
  # with a unit, which is what EML needs to interpret the numbers.
  if (is.character(values) || is.factor(values)) {
    return(list(attributeName = name, attributeDefinition = definition,
                measurementScale = list(nominal = list(nonNumericDomain = list(
                  textDomain = list(definition = definition))))))
  }

  unit_label <- if (!is.null(known)) known$units else {
    if (name %in% c("LON", "LAT")) "degrees" else "unitless"
  }
  if (name %in% time_columns()) unit_label <- "count"
  if (grepl("_depth$", name)) unit_label <- "m"

  row <- units[units$units == unit_label, ]
  unit <- if (nrow(row) == 0) {
    list(standardUnit = "dimensionless")
  } else if (row$standard[1]) {
    list(standardUnit = row$eml[1])
  } else {
    list(customUnit = row$eml[1])
  }

  list(attributeName = name, attributeDefinition = definition,
       measurementScale = list(ratio = list(
         unit = unit,
         numericDomain = list(
           numberType = if (is.integer(values)) "integer" else "real"))))
}

#' Write EML metadata for a matched table
#'
#' Produces an [Ecological Metadata
#' Language](https://eml.ecoinformatics.org/) document describing a table
#' [matchData()] produced: what each column is, where and when it covers, which
#' data sources went into it, and what to cite. EML is what repositories such as
#' EDI and the LTER network expect alongside a deposited dataset.
#'
#' @section What is filled in for you:
#' Nearly all of it, because the package already knows:
#'
#' \itemize{
#'   \item **Geographic coverage** from the object's own bounding box.
#'   \item **Temporal coverage** from its `YEAR`/`MONTH`/`DAY` columns.
#'   \item **An attribute for every column** — definition, units, and
#'     measurement scale — with labels and units taken from whichever source
#'     catalog defines that name, and this package's own conventions used for
#'     the time, `LON`/`LAT`, `<var>_source` and `<var>_depth` columns.
#'   \item **Methods and citations** from the `<var>_source` columns
#'     [matchData()] writes. This is the part worth having: a table with four
#'     sources chained onto it produces a methods section naming all four and a
#'     reference for each, rather than leaving you to reconstruct which fetch
#'     produced which column.
#' }
#'
#' What it cannot know is who you are and what the dataset is *for*, so `title`,
#' `creator` and `abstract` are yours to give.
#'
#' @section Units, and why some are declared:
#' EML validates units against a fixed vocabulary and rejects anything not on
#' it. **`PSU` and `N/m2` are both absent from it** — salinity and wind stress,
#' two of this package's core variables — so they are written as *custom* units
#' and declared in the document's own `unitList`. That is the mechanism EML
#' provides for it, and the resulting document validates.
#'
#' @param x an `sf` object from [matchData()], or any of the access functions
#' @param file <char> where to write the XML
#' @param title <char> the dataset's title
#' @param creator a list in EML `creator` shape, or a character name. An ORCID
#'   is worth including; see the examples.
#' @param abstract <char> a paragraph on what the dataset is and why it exists
#' @param contact the contact party; defaults to `creator`
#' @param keywords <char> optional keywords
#' @param entity_name <char> what the data file is called, for the `dataTable`
#' @param validate <logical> validate against the EML schema before returning.
#'   Requires the `emld` package, and is worth leaving on: an invalid document
#'   is rejected at submission rather than at write time.
#' @return the path, invisibly
#' @examples
#' \dontrun{
#' matched <- matchData(observations, accessHYCOM(vars = "BOTS", ...))
#'
#' write_eml(
#'   matched, "matched.xml",
#'   title = "Bottom salinity matched to trawl stations, Gulf of Maine",
#'   creator = list(individualName = list(givenName = "Camille",
#'                                        surName = "Ross"),
#'                  electronicMailAddress = "camille.ross@maine.edu",
#'                  userId = list(directory = "https://orcid.org",
#'                                userId = "0000-0002-1428-2294")),
#'   abstract = "Stations from the spring survey with HYCOM bottom salinity.")
#' }
#' @seealso [matchData()], which writes the `<var>_source` columns this reads,
#'   and [source_of()]
#' @export
write_eml <- function(x, file, title, creator, abstract = NULL,
                      contact = creator, keywords = NULL,
                      entity_name = basename(file), validate = TRUE) {
  if (!requireNamespace("emld", quietly = TRUE)) {
    stop("Writing EML needs the emld package, which datamatch suggests rather ",
         "than requires.\nInstall it with:  install.packages(\"emld\")",
         call. = FALSE)
  }
  if (missing(title) || missing(creator)) {
    stop("`title` and `creator` are required: they are the parts of the ",
         "metadata this package\ncannot infer from the data.", call. = FALSE)
  }

  if (is.character(creator)) {
    creator <- list(individualName = list(surName = creator))
  }
  if (is.character(contact)) {
    contact <- list(individualName = list(surName = contact))
  }

  flat <- if (inherits(x, "sf")) sf::st_drop_geometry(x) else as.data.frame(x)

  attributes <- lapply(names(flat), function(name) {
    eml_attribute(name, flat[[name]])
  })

  # Only the custom units actually used are declared, so the document does not
  # carry a vocabulary it does not need.
  used <- vapply(attributes, function(a) {
    a$measurementScale$ratio$unit$customUnit %||% NA_character_
  }, character(1))
  used <- unique(stats::na.omit(used))
  units <- eml_unit_table()
  declared <- units[!units$standard & units$eml %in% used, ]

  document <- list(
    packageId = paste0("datamatch.", format(Sys.Date(), "%Y%m%d"), ".1"),
    system = "datamatch",
    dataset = c(
      list(title = title, creator = creator, contact = contact,
           pubDate = format(Sys.Date())),
      if (!is.null(abstract)) list(abstract = abstract),
      if (!is.null(keywords)) {
        list(keywordSet = list(keyword = as.list(keywords)))
      },
      list(coverage = eml_coverage(x, flat)),
      list(methods = eml_methods(flat, x)),
      list(dataTable = list(
        entityName = entity_name,
        entityDescription = paste("Point data with environmental covariates",
                                  "matched in space and time by datamatch."),
        physical = list(
          objectName = entity_name,
          dataFormat = list(textFormat = list(
            recordDelimiter = "\\n", attributeOrientation = "column",
            simpleDelimited = list(fieldDelimiter = ",")))),
        attributeList = list(attribute = attributes),
        numberOfRecords = as.character(nrow(flat))))
    )
  )

  if (nrow(declared) > 0) {
    document$additionalMetadata <- list(metadata = list(unitList = list(
      unit = lapply(seq_len(nrow(declared)), function(i) {
        list(id = declared$eml[i], name = declared$eml[i],
             unitType = declared$type[i], description = declared$description[i])
      }))))
  }

  emld::as_xml(emld::as_emld(document), file)

  if (validate) {
    result <- emld::eml_validate(file)
    if (!isTRUE(result)) {
      stop("The EML document written to ", file, " does not validate:\n",
           paste(utils::head(attr(result, "errors"), 5), collapse = "\n"),
           call. = FALSE)
    }
  }

  invisible(file)
}

#' Geographic and temporal coverage of a matched table
#'
#' @param x the object, for its bounding box
#' @param flat the same without geometry, for its time columns
#' @return a list in EML `coverage` shape
#' @keywords internal
eml_coverage <- function(x, flat) {
  coverage <- list()

  if (inherits(x, "sf")) {
    box <- sf::st_bbox(x)
    coverage$geographicCoverage <- list(
      geographicDescription = paste0(
        "Bounding box of the matched features: ",
        round(box[["xmin"]], 3), " to ", round(box[["xmax"]], 3), " E, ",
        round(box[["ymin"]], 3), " to ", round(box[["ymax"]], 3), " N."),
      boundingCoordinates = list(
        westBoundingCoordinate = box[["xmin"]],
        eastBoundingCoordinate = box[["xmax"]],
        northBoundingCoordinate = box[["ymax"]],
        southBoundingCoordinate = box[["ymin"]]))
  }

  if (all(c("YEAR", "MONTH") %in% names(flat))) {
    day <- if ("DAY" %in% names(flat)) flat$DAY else rep(1L, nrow(flat))
    dates <- as.Date(sprintf("%04d-%02d-%02d", flat$YEAR, flat$MONTH, day))
    dates <- dates[!is.na(dates)]
    if (length(dates) > 0) {
      coverage$temporalCoverage <- list(rangeOfDates = list(
        beginDate = list(calendarDate = format(min(dates))),
        endDate = list(calendarDate = format(max(dates)))))
    }
  }

  coverage
}

#' A methods section naming the sources that went into a table
#'
#' The point of recording `<var>_source` on every join is that a table can say
#' where it came from afterwards. This turns that record into prose, with the
#' citation for each source that actually contributed — which is otherwise the
#' most tedious part of depositing a derived dataset, and the easiest to get
#' wrong once several fetches are chained.
#'
#' @param flat the table without geometry
#' @param x the original, for its own source stamp when no columns carry one
#' @return a list in EML `methods` shape
#' @keywords internal
eml_methods <- function(flat, x) {
  tags <- unique(unlist(lapply(
    names(flat)[grepl("_source$", names(flat))],
    function(column) unique(stats::na.omit(as.character(flat[[column]]))))))

  # A table straight from an access function has no _source columns, but does
  # carry the stamp itself.
  if (length(tags) == 0 && !is.na(source_of(x))) tags <- source_of(x)

  steps <- list(list(description = list(para = paste(
    "Environmental covariates were matched to each feature by a spatiotemporal",
    "nearest-feature join at the source data's own temporal resolution, using",
    "the datamatch R package. Each covariate takes the value of the nearest",
    "cell of its source within the same time period; features falling in a",
    "period a source does not cover are returned with missing values rather",
    "than dropped."))))

  if (length(tags) > 0) {
    steps[[length(steps) + 1]] <- list(description = list(para = paste0(
      # No angle brackets: this becomes XML text, and a literal <var> would be
      # read as an opening tag and fail to serialise.
      "Covariates were drawn from the following sources, recorded per column ",
      "in the accompanying _source fields: ", paste(sort(tags), collapse = "; "),
      ". ",
      "Values sharing a column name across sources are not interchangeable: ",
      "they are different models or analyses of the same quantity.")))

    references <- unique(stats::na.omit(vapply(tags, source_reference,
                                               character(1))))
    for (reference in references) {
      steps[[length(steps) + 1]] <- list(description = list(para = reference))
    }
  }

  list(methodStep = steps)
}

#' The citation for a source tag such as `"hycom:GLBv53X"`
#'
#' @section Every source family needs a branch here:
#' A family with none returns `NA`, and [eml_methods()] then writes a methods
#' section that names the source and cites nothing — which is the failure the
#' methods section exists to prevent, arriving silently. A test walks the
#' families rather than trusting this list to stay complete.
#'
#' @section Where the citation is a pointer rather than a reference:
#' Copernicus and OB.DAAC both mint a DOI per dataset per reprocessing, and
#' those move: OB.DAAC's version token differs by suite and by mission, so a
#' `PAR` DOI ending 2022 resolves where the matching `SST` one ending 2019 does
#' not.
#' A table of them hard-coded here would be wrong at the next reprocessing and
#' wrong silently, so both name the dataset precisely and say where its DOI
#' lives instead. The mission or model paper is given alongside, because it is
#' stable and is a different obligation from the data citation.
#'
#' @param tag <char> a tag as [source_of()] returns
#' @return <char> the reference, or `NA` when the source carries none
#' @keywords internal
source_reference <- function(tag) {
  parts <- strsplit(tag, ":", fixed = TRUE)[[1]]
  if (length(parts) < 2) return(NA_character_)
  source <- parts[1]
  archive <- paste(parts[-1], collapse = ":")

  switch(source,
    fvcom = fvcom_archives()[[archive]]$reference %||% fvcom_reference(),
    hycom = hycom_archives()[[archive]]$reference %||% NA_character_,
    ccmp = ccmp_versions()[[archive]]$reference %||% NA_character_,
    erddap = erddap_datasets()[[archive]]$reference %||% NA_character_,
    # "NWA12-hindcast-r20250715", or that with an initialisation and a member
    # appended. The release is the part that has to reach the citation: CEFI
    # revises the record with each one.
    cefi = {
      release <- regmatches(archive, regexpr("r[0-9]{8}", archive))
      paste0(
        cefi_reference(),
        " Data provided by the NOAA Physical Sciences Laboratory, Boulder,",
        " Colorado, USA, from https://psl.noaa.gov/cefi_portal/. Run: ",
        archive,
        if (length(release) > 0) {
          paste0(" (release ", release, "; releases revise the record, so say",
                 " which one)")
        } else "",
        ".")
    },
    # "MODISA-4km": the sensor, then the grid it was read at.
    obdaac = {
      sensor <- sub("-[^-]+$", "", archive)
      spec <- obdaac_sensors()[[sensor]]
      if (is.null(spec)) NA_character_ else paste0(
        spec$reference,
        " Data: NASA Ocean Biology Processing Group. ", spec$label,
        " Level-3 mapped products, distributed by the NASA Ocean Biology",
        " DAAC (", archive, ").",
        " OB.DAAC mints a DOI under the 10.5067 prefix per mission, suite and",
        " reprocessing - see https://www.earthdata.nasa.gov/centers/ob-daac",
        " for the one covering the products used, which is a separate",
        " obligation from the mission paper above.")
    },
    copernicus = paste(
      "E.U. Copernicus Marine Service Information (CMEMS). Marine Data Store",
      "(MDS). Dataset:", archive,
      "- see https://data.marine.copernicus.eu for the product DOI and the",
      "citation form Copernicus asks for, which includes the access date."),
    NA_character_)
}
