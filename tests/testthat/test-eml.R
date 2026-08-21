# EML is a schema-validated standard, so the tests that matter are the ones that
# check a real document against the schema rather than checking our own strings.

matched_example <- function() {
  sf::st_as_sf(
    data.frame(LON = c(-69, -68.5), LAT = c(43, 43.4),
               YEAR = 2010L, MONTH = 6L, DAY = 15L,
               SST = c(12.1, 12.8), SSS = c(31.9, 32.1), TAUX = c(0.01, 0.02),
               SST_source = "hycom:GLBv53X", SSS_source = "fvcom:GOM3",
               TAUX_source = "copernicus:cmems_obs-wind_glo_phy_my_l4_P1M",
               stringsAsFactors = FALSE),
    coords = c("LON", "LAT"), crs = 4326, remove = FALSE)
}

test_that("the unit table maps every unit the catalogs use", {
  # A unit in a catalog with no EML mapping would silently become
  # "dimensionless", which is wrong for a temperature or a stress.
  used <- unique(unlist(lapply(known_variables(), function(v) v$units)))
  mapped <- eml_unit_table()$units

  expect_true(all(used %in% mapped),
              info = paste("unmapped:", paste(setdiff(used, mapped),
                                              collapse = ", ")))
})

test_that("every source catalog reaches known_variables()", {
  # Nothing enforces this in the code: a source added without being listed in
  # known_variables() still fetches and still joins, and then writes EML in
  # which its columns have no definition and no units. So the catalogs are
  # checked here instead.
  known <- names(known_variables())

  catalogs <- list(copernicus = copernicus_variables(),
                   fvcom = fvcom_variables(), hycom = hycom_variables(),
                   cefi = cefi_variables(), ccmp = ccmp_variables(),
                   obdaac = obdaac_variables())
  for (source in names(catalogs)) {
    expect_setequal(setdiff(names(catalogs[[source]]), known), character(0))
  }
  for (spec in erddap_datasets()) {
    expect_setequal(setdiff(names(spec$variables), known), character(0))
  }
})

test_that("PSU and wind stress are declared rather than assumed standard", {
  units <- eml_unit_table()

  # These two are the reason the custom-unit machinery exists: EML's vocabulary
  # has neither, and emitting them as standard units produces a document that
  # fails validation at submission.
  expect_false(units$standard[units$units == "PSU"])
  expect_false(units$standard[units$units == "N/m2"])
  expect_true(units$standard[units$units == "degrees C"])
  expect_equal(units$eml[units$units == "degrees C"], "celsius")

  # Every custom unit needs a type and a description, or the unitList is invalid.
  custom <- units[!units$standard, ]
  expect_true(all(nzchar(custom$type)))
  expect_true(all(nzchar(custom$description)))
})

test_that("the units CEFI and OB.DAAC brought are mapped the way they validate", {
  units <- eml_unit_table()
  lookup <- function(u) units[units$units == u, ]

  # mol/m3 was the only one of the new units with a standard EML spelling, and
  # the vocabulary is not self-consistent about it: milligramsPerCubicMeter is
  # plural on both words, molePerCubicMeter singular on both, and both are
  # standard. Established by validating, not by reading a list.
  expect_true(lookup("mol/m3")$standard)
  expect_equal(lookup("mol/m3")$eml, "molePerCubicMeter")

  # The rest have to be declared, or the document fails at submission.
  for (u in c("umol/kg", "uatm", "mol/m2", "1/m", "einstein/m2/day",
              "W/m2/um/sr")) {
    expect_false(lookup(u)$standard, info = u)
    expect_true(nzchar(lookup(u)$type), info = u)
    expect_true(nzchar(lookup(u)$description), info = u)
  }
})

test_that("an attribute is built for each kind of column", {
  # A known covariate: label and units from whichever catalog defines it.
  sst <- eml_attribute("SST", c(12.1, 12.8))
  expect_equal(sst$attributeName, "SST")
  expect_equal(sst$measurementScale$ratio$unit$standardUnit, "celsius")

  # Salinity takes the custom unit.
  expect_equal(eml_attribute("SSS", 32)$measurementScale$ratio$unit$customUnit,
               "practicalSalinityUnit")

  # A provenance column is text, so it is nominal rather than a ratio.
  provenance <- eml_attribute("SST_source", "hycom:GLBv53X")
  expect_null(provenance$measurementScale$ratio)
  expect_false(is.null(provenance$measurementScale$nominal))
  expect_match(provenance$attributeDefinition, "Which data source")

  # A time column is a count, not a measurement with physical units.
  expect_equal(eml_attribute("YEAR", 2010L)$measurementScale$ratio$unit$standardUnit,
               "number")
  # And a derived bottom variable's depth column is metres.
  expect_equal(eml_attribute("BOTS_depth", 120)$measurementScale$ratio$unit$standardUnit,
               "meter")
})

test_that("source tags resolve to the right citations", {
  expect_match(source_reference("hycom:GLBv53X"), "Chassignet")
  expect_match(source_reference("fvcom:GOM3"), "Chen C")
  expect_match(source_reference("ccmp:v03.1"), "Mears")
  expect_match(source_reference("erddap:MUR"), "Chin TM")
  expect_match(source_reference("copernicus:anything"), "Copernicus Marine Service")

  # A tag from nowhere must not invent a citation.
  expect_true(is.na(source_reference("nonsense")))
  expect_true(is.na(source_reference("no-colon")))
})

test_that("the methods section names every source that contributed", {
  methods <- eml_methods(sf::st_drop_geometry(matched_example()),
                         matched_example())
  text <- paste(unlist(methods), collapse = " ")

  # All three sources, and a citation for each - which is the part that is
  # tedious and error-prone to assemble by hand once several are chained.
  expect_match(text, "hycom:GLBv53X")
  expect_match(text, "fvcom:GOM3")
  expect_match(text, "Chassignet")
  expect_match(text, "Chen C")
  # And the caution that a shared column name is not a shared quantity.
  expect_match(text, "not interchangeable")

  # No angle brackets in the prose: it becomes XML text, and a literal <var>
  # would be read as an opening tag and fail to serialise.
  expect_false(grepl("<", text, fixed = TRUE))
})

test_that("coverage comes from the data rather than the caller", {
  coverage <- eml_coverage(matched_example(),
                           sf::st_drop_geometry(matched_example()))

  expect_equal(coverage$geographicCoverage$boundingCoordinates$westBoundingCoordinate,
               -69)
  expect_equal(coverage$geographicCoverage$boundingCoordinates$northBoundingCoordinate,
               43.4)
  expect_equal(coverage$temporalCoverage$rangeOfDates$beginDate$calendarDate,
               "2010-06-15")
})

test_that("title and creator are required, because they cannot be inferred", {
  skip_if_not_installed("emld")
  path <- tempfile(fileext = ".xml")

  expect_error(write_eml(matched_example(), path), "`title` and `creator`")
})

test_that("the document written validates against the EML schema", {
  skip_if_not_installed("emld")

  path <- tempfile(fileext = ".xml")
  on.exit(unlink(path), add = TRUE)

  # validate = TRUE, so this errors rather than returning if it is invalid.
  expect_silent(
    write_eml(matched_example(), path,
              title = "Bottom conditions at trawl stations",
              creator = list(individualName = list(givenName = "Camille",
                                                   surName = "Ross")),
              abstract = "Stations with covariates matched by datamatch.",
              keywords = c("Gulf of Maine", "salinity")))

  expect_true(file.exists(path))
  expect_true(isTRUE(emld::eml_validate(path)))

  xml <- paste(readLines(path), collapse = "\n")
  # The custom units actually used must be declared, or the document is invalid.
  expect_match(xml, "practicalSalinityUnit")
  expect_match(xml, "<unitList>")
  # And one that is not used must not be declared.
  expect_false(grepl("sverdrup", xml))
})

test_that("a character creator is accepted as shorthand", {
  skip_if_not_installed("emld")

  path <- tempfile(fileext = ".xml")
  on.exit(unlink(path), add = TRUE)

  expect_silent(write_eml(matched_example(), path, title = "T",
                          creator = "Ross"))
  expect_true(isTRUE(emld::eml_validate(path)))
})

test_that("a table straight from an access function is described too", {
  skip_if_not_installed("emld")

  # No _source columns, but the object carries its own stamp - which the methods
  # section should use rather than saying nothing about provenance.
  env <- matched_example()[, c("YEAR", "MONTH", "DAY", "SST")]
  env <- stamp_source(env, "hycom", "GLBv53X")

  methods <- eml_methods(sf::st_drop_geometry(env), env)
  expect_match(paste(unlist(methods), collapse = " "), "hycom:GLBv53X")
})

test_that("a table of the newest covariates still validates", {
  skip_if_not_installed("emld")

  # Every unit CEFI and OB.DAAC added at once, which is what exercises the
  # custom unitList: six of the seven are declared rather than standard, and a
  # unitList that is wrong makes the whole document invalid rather than the one
  # column.
  x <- sf::st_as_sf(
    data.frame(LON = c(-69, -68.5), LAT = c(43, 43.4), YEAR = 2015L,
               MONTH = 6L, DAY = 1L,
               BOTO2 = c(240, 251), PCO2 = c(380, 392),
               MESOZOO = c(0.4, 0.5), PHYC = c(0.002, 0.003),
               KD490 = c(0.09, 0.11), PAR = c(45, 48), POC = c(120, 133),
               PIC = c(0.001, 0.002), NFLH = c(0.02, 0.03),
               SST_NIGHT = c(11.8, 12.2), CHL = c(1.2, 1.4),
               CHL_source = "cefi:NWA12-hindcast-r20250715",
               SST_NIGHT_source = "obdaac:MODISA-4km",
               stringsAsFactors = FALSE),
    coords = c("LON", "LAT"), crs = 4326, remove = FALSE)

  path <- withr::local_tempfile(fileext = ".xml")
  write_eml(x, path, title = "Newest covariates",
            creator = list(individualName = list(surName = "Ross")),
            contact = list(individualName = list(surName = "Ross")))

  expect_true(isTRUE(emld::eml_validate(path)))

  written <- paste(readLines(path, warn = FALSE), collapse = "\n")
  # Declared, and referenced by the attributes that need them.
  for (unit in c("micromolesPerKilogram", "microatmosphere",
                 "molesPerSquareMeter", "perMeter",
                 "einsteinPerSquareMeterPerDay",
                 "wattPerSquareMeterPerMicrometerPerSteradian")) {
    expect_match(written, paste0("<customUnit>", unit, "</customUnit>"))
    expect_match(written, paste0("<unit id=\"", unit, "\""))
  }
  # The one that did have a standard spelling is emitted as one.
  expect_match(written, "<standardUnit>molePerCubicMeter</standardUnit>",
               fixed = TRUE)

  # And the covariates are described rather than falling through to the
  # "Column 'X'." default that an unlisted catalog would produce.
  expect_match(written, "Mesozooplankton biomass", fixed = TRUE)
  expect_match(written, "Diffuse attenuation at 490 nm", fixed = TRUE)
})

test_that("every source family a fetch can stamp yields a citation", {
  # source_reference() switches on the family, and a family with no branch
  # returns NA - at which point eml_methods() writes a methods section naming
  # the source and citing nothing. That is the failure the methods section
  # exists to prevent, and it arrives silently, so the families are walked here
  # rather than the list being trusted to stay complete.
  #
  # One representative tag per family, in the shape each access function
  # actually stamps.
  tags <- c(
    "copernicus:cmems_mod_glo_phy_my_0.083deg_P1M-m",
    "fvcom:GOM3",
    "hycom:GLBv53X",
    "cefi:NWA12-hindcast-r20250715",
    "ccmp:v03.1",
    "erddap:MUR",
    "obdaac:MODISA-4km")

  for (tag in tags) {
    reference <- source_reference(tag)
    expect_false(is.na(reference), info = paste(tag, "has no citation"))
    expect_true(nzchar(reference), info = tag)
  }
})

test_that("a CEFI citation names the release and an OB.DAAC one the sensor", {
  # The detail after the colon is what distinguishes two fetches that are
  # otherwise identical, so it has to survive into the citation. A CEFI release
  # revises the record; two OB.DAAC sensors disagree where they overlap.
  hindcast <- source_reference("cefi:NWA12-hindcast-r20250715")
  expect_match(hindcast, "r20250715", fixed = TRUE)
  expect_match(hindcast, "Physical Sciences Laboratory", fixed = TRUE)
  expect_match(hindcast, "10.5194/gmd-16-6943-2023", fixed = TRUE)

  forecast <- source_reference("cefi:NWA12-decadal_forecast-r20250925-i198001-m01")
  expect_match(forecast, "r20250925", fixed = TRUE)
  expect_match(forecast, "i198001-m01", fixed = TRUE)

  # Each mission carries its own paper, so two sensors do not cite the same one.
  expect_match(source_reference("obdaac:MODISA-4km"), "MODIS", fixed = TRUE)
  expect_match(source_reference("obdaac:SEAWIFS-9km"), "SeaWiFS", fixed = TRUE)
  expect_false(identical(source_reference("obdaac:MODISA-4km"),
                         source_reference("obdaac:SEAWIFS-9km")))

  # The dataset DOI is a separate obligation from the mission paper, and is
  # pointed at rather than hard-coded because its version token moves.
  expect_match(source_reference("obdaac:MODISA-4km"), "10.5067", fixed = TRUE)

  # An unknown sensor is NA rather than a confident citation of the wrong thing.
  expect_true(is.na(source_reference("obdaac:NOTASENSOR-4km")))
})

test_that("the methods section carries a citation for each source it names", {
  skip_if_not_installed("emld")

  x <- sf::st_as_sf(
    data.frame(LON = c(-69, -68.5), LAT = c(43, 43.4), YEAR = 2015L,
               MONTH = 6L, DAY = 1L, BOTT = c(7.1, 7.4), CHL = c(1.2, 1.4),
               BOTT_source = "cefi:NWA12-hindcast-r20250715",
               CHL_source = "obdaac:MODISA-4km", stringsAsFactors = FALSE),
    coords = c("LON", "LAT"), crs = 4326, remove = FALSE)

  path <- withr::local_tempfile(fileext = ".xml")
  write_eml(x, path, title = "Sourced covariates",
            creator = list(individualName = list(surName = "Ross")),
            contact = list(individualName = list(surName = "Ross")))

  written <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_true(isTRUE(emld::eml_validate(path)))

  # Both sources are named...
  expect_match(written, "cefi:NWA12-hindcast-r20250715", fixed = TRUE)
  expect_match(written, "obdaac:MODISA-4km", fixed = TRUE)
  # ...and both are cited, which is the part that was missing.
  expect_match(written, "Geoscientific Model Development", fixed = TRUE)
  expect_match(written, "Ocean Biology", fixed = TRUE)
})
