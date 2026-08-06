test_that("every catalog entry is fully specified", {
  catalog <- copernicus_variables()

  expect_gt(length(catalog), 0)
  for (name in names(catalog)) {
    entry <- catalog[[name]]
    for (field in c("variable", "label", "units", "product_id", "dataset_id",
                     "description")) {
      expect_true(nzchar(entry[[field]] %||% ""),
                  info = paste(name, "is missing", field))
    }
  }
})

test_that("catalog names and Copernicus codes are each unique", {
  catalog <- copernicus_variables()
  codes <- vapply(catalog, function(entry) entry$variable, character(1))

  # A duplicated name would shadow an entry; a duplicated code would make two
  # names resolve to the same column and collide on rename.
  expect_equal(anyDuplicated(names(catalog)), 0)
  expect_equal(anyDuplicated(codes), 0)
})

test_that("variable_dictionary tabulates the catalog", {
  dictionary <- variable_dictionary()

  expect_s3_class(dictionary, "datamatch_dictionary")
  expect_s3_class(dictionary, "data.frame")
  expect_setequal(dictionary$name, names(copernicus_variables()))
  expect_true(all(c("name", "variable", "label", "units", "dataset")
                  %in% names(dictionary)))
})

test_that("the dictionary can be filtered by product family", {
  physical <- variable_dictionary("physical")
  biogeochemical <- variable_dictionary("biogeochemical")
  satellite <- variable_dictionary("satellite")

  expect_true("SST" %in% physical$name)
  expect_true("CHL_MODEL" %in% biogeochemical$name)
  expect_true("CHL" %in% satellite$name)
  expect_false("SST" %in% satellite$name)

  # The three families must partition the catalog.
  expect_equal(nrow(physical) + nrow(biogeochemical) + nrow(satellite),
               nrow(variable_dictionary("all")))
})

test_that("chlorophyll and primary production default to satellite", {
  # Observed rather than simulated, and 4 km rather than 0.25 degrees, so the
  # plain names point at ocean colour and the model versions are suffixed.
  expect_true(grepl("obs-oc", variable_dataset("CHL")[["CHL"]]))
  expect_true(grepl("obs-oc", variable_dataset("PP")[["PP"]]))
  expect_true(grepl("_bgc_", variable_dataset("CHL_MODEL")[["CHL_MODEL"]]))
  expect_true(grepl("_bgc_", variable_dataset("NPP_MODEL")[["NPP_MODEL"]]))
})

test_that("diatoms and dinophytes come from the plankton dataset", {
  catalog <- copernicus_variables()

  expect_equal(catalog$DIATO$variable, "DIATO")
  expect_equal(catalog$DINO$variable, "DINO")
  # Same dataset as satellite CHL, so the three can be fetched together.
  expect_equal(catalog$DIATO$dataset_id, catalog$CHL$dataset_id)
  expect_equal(infer_dataset(c("CHL", "DIATO", "DINO"))$dataset_id,
               catalog$CHL$dataset_id)
})

test_that("satellite PP is a different dataset from the plankton variables", {
  # Same product, different dataset - so they cannot be fetched in one request,
  # and saying so up front is better than a rejected download.
  expect_error(infer_dataset(c("CHL", "PP")), "different Copernicus datasets")
})

test_that("satellite and model productivity are not interchangeable", {
  catalog <- copernicus_variables()

  # Depth-integrated vs volumetric: mg/m2/day against mg/m3/day. Treating them
  # as the same quantity would be a units error, not a resolution difference.
  expect_equal(catalog$PP$units, "mg/m2/day")
  expect_equal(catalog$NPP_MODEL$units, "mg/m3/day")
})

test_that("printing the dictionary is readable and returns invisibly", {
  dictionary <- variable_dictionary()

  output <- capture.output(result <- withVisible(print(dictionary)))

  expect_false(result$visible)
  expect_true(any(grepl("SST", output)))
  expect_true(any(grepl("thetao", output)))
  # The description is too wide to print and is dropped from the console view.
  expect_false(any(grepl("Sea water potential temperature at the surface",
                          output)))
})

test_that("catalog names resolve to Copernicus codes", {
  resolved <- resolve_variables(c("SST", "CHL_MODEL"))

  expect_equal(resolved$codes, c("thetao", "chl"))
  # The names are what the result columns should be called, so a request for
  # CHL_MODEL returns a CHL_MODEL column rather than the code `chl`.
  expect_equal(resolved$names, c("SST", "CHL_MODEL"))
})

test_that("raw Copernicus codes still work unchanged", {
  # Existing calls pass codes directly, and must keep working.
  resolved <- expect_silent(resolve_variables(c("thetao", "so")))

  expect_equal(resolved$codes, c("thetao", "so"))
  expect_equal(resolved$names, c("thetao", "so"))
})

test_that("names and codes can be mixed", {
  resolved <- expect_silent(resolve_variables(c("SST", "so")))

  expect_equal(resolved$codes, c("thetao", "so"))
  expect_equal(resolved$names, c("SST", "so"))
})

test_that("an unrecognized variable is passed through with a warning", {
  # Copernicus serves far more than this catalog covers, so an unknown string
  # must still reach the API - but a typo looks identical to a real code, so it
  # cannot pass silently.
  expect_warning(resolved <- resolve_variables("uo_typo"), "not in the variable dictionary")
  expect_equal(resolved$codes, "uo_typo")
})

test_that("variable_dataset reports where each variable comes from", {
  datasets <- variable_dataset(c("SST", "NO3", "CHL", "nonsense"))

  expect_true(grepl("_phy_", datasets[["SST"]]))
  expect_true(grepl("_bgc_", datasets[["NO3"]]))
  # CHL is satellite ocean colour now, not the biogeochemistry reanalysis.
  expect_true(grepl("obs-oc", datasets[["CHL"]]))
  expect_true(is.na(datasets[["nonsense"]]))
})

test_that("the dataset is inferred when every variable is in the catalog", {
  inferred <- infer_dataset(c("SST", "SSS", "MLD"))

  expect_equal(inferred$product_id, "GLOBAL_MULTIYEAR_PHY_001_030")
  expect_true(grepl("_phy_", inferred$dataset_id))
})

test_that("variables from different datasets cannot be fetched together", {
  # SST is physical, CHL biogeochemical. Failing here is much clearer than a
  # rejected download with no explanation.
  expect_error(infer_dataset(c("SST", "CHL")), "different Copernicus datasets")
  expect_error(infer_dataset(c("SST", "CHL")), "once per dataset")
})

test_that("an uninferable variable says how to proceed", {
  expect_error(infer_dataset(c("SST", "mystery")), "mystery")
  expect_error(infer_dataset(c("SST", "mystery")), "variable_dictionary")
})

test_that("as_markdown emits a valid pipe table", {
  lines <- capture.output(as_markdown(variable_dictionary()))

  expect_true(startsWith(lines[1], "| name"))
  # Row two must be the separator, or nothing renders as a table.
  expect_true(grepl("^\\| -+ \\|", lines[2]))
  # Header, separator, and one row per variable.
  expect_equal(length(lines), nrow(variable_dictionary()) + 2)
  expect_true(any(grepl("SST", lines)))

  # Every row must have the same number of cells as the header.
  cells <- vapply(lines, function(line) lengths(regmatches(line, gregexpr("\\|", line))),
                  integer(1))
  expect_equal(length(unique(cells)), 1)
})

test_that("as_markdown can include any column and rejects unknown ones", {
  lines <- capture.output(as_markdown(variable_dictionary(),
                                       columns = c("name", "dataset")))

  expect_true(any(grepl("cmems_mod_glo_phy", lines)))
  expect_false(any(grepl("degrees C", lines)))

  expect_error(as_markdown(variable_dictionary(), columns = "nonexistent"),
               "not in the dictionary")
})

test_that("as_markdown works on the index dictionary too", {
  lines <- capture.output(as_markdown(index_dictionary()))

  expect_true(any(grepl("NAO", lines)))
  expect_true(any(grepl("NOAA", lines)))
})

test_that("the dataset is inferred from raw Copernicus codes too", {
  # A call that passes codes rather than names should still get product and
  # dataset inference; otherwise omitting the identifiers only works for one
  # of the two ways of naming a variable.
  inferred <- infer_dataset(c("thetao", "so"))

  expect_equal(inferred$product_id, "GLOBAL_MULTIYEAR_PHY_001_030")
  expect_true(grepl("_phy_", inferred$dataset_id))
})

test_that("names and codes can be mixed when inferring the dataset", {
  inferred <- infer_dataset(c("SST", "so"))

  expect_true(grepl("_phy_", inferred$dataset_id))
})

test_that("mixing datasets is caught whichever way the variables are named", {
  expect_error(infer_dataset(c("thetao", "chl")), "different Copernicus datasets")
})

test_that("variable_dataset resolves codes as well as names", {
  datasets <- variable_dataset(c("SST", "thetao", "chl"))

  expect_equal(unname(datasets[["SST"]]), unname(datasets[["thetao"]]))
  expect_true(grepl("_bgc_", datasets[["chl"]]))
})

test_that("the printed dictionary shows product, dataset, and docs URL", {
  output <- capture.output(print(variable_dictionary()))

  # The dataset identifier is what is actually requested, and what has to be
  # corrected by hand when Copernicus revises one.
  expect_true(any(grepl("GLOBAL_MULTIYEAR_PHY_001_030", output)))
  expect_true(any(grepl("cmems_mod_glo_phy_my", output)))
  expect_true(any(grepl("data.marine.copernicus.eu/product", output)))
  # And it should say that the identifiers can be left out.
  expect_true(any(grepl("can be", output)))
})

test_that("forecast mode resolves to the analysis-and-forecast products", {
  inferred <- infer_dataset(c("SST"), mode = "forecast")

  expect_equal(inferred$product_id, "GLOBAL_ANALYSISFORECAST_PHY_001_024")
  expect_true(grepl("anfc", inferred$dataset_id))
})

test_that("forecast codes differ from reanalysis codes where Copernicus differs", {
  # Bottom temperature is bottomT in the reanalysis and tob in the forecast.
  # Reusing the reanalysis code would produce a failed download, which is why
  # this is a mapping rather than a dataset substitution.
  expect_equal(copernicus_variables()$BOTT$variable, "bottomT")
  expect_equal(forecast_variables()$BOTT$variable, "tob")

  expect_equal(resolve_variables("BOTT", mode = "forecast")$codes, "tob")
  expect_equal(resolve_variables("BOTT")$codes, "bottomT")
})

test_that("forecast column names still follow the requested names", {
  resolved <- resolve_variables(c("SST", "BOTT"), mode = "forecast")

  expect_equal(resolved$codes, c("thetao", "tob"))
  expect_equal(resolved$names, c("SST", "BOTT"))
})

test_that("the forecast products split variables across more datasets", {
  # SST and SSS share a dataset in the reanalysis but not in the forecast, so a
  # set that fetches in one request as reanalysis may need several as forecast.
  expect_silent(infer_dataset(c("SST", "SSS")))
  expect_error(infer_dataset(c("SST", "SSS"), mode = "forecast"),
               "different Copernicus datasets")
  expect_error(infer_dataset(c("SST", "SSS"), mode = "forecast"),
               "split variables across datasets")

  # Currents do share one.
  expect_silent(infer_dataset(c("UO", "VO"), mode = "forecast"))
})

test_that("satellite variables have no forecast, and the error says why", {
  expect_error(infer_dataset("CHL", mode = "forecast"), "No forecast exists")
  expect_error(infer_dataset("CHL", mode = "forecast"),
               "no observation of the future")
  # And it points at the model equivalent, which does have one.
  expect_silent(infer_dataset("CHL_MODEL", mode = "forecast"))
})

test_that("forecast entries keep the label and units of the same quantity", {
  entry <- catalog_entry("SST", mode = "forecast")

  expect_equal(entry$units, copernicus_variables()$SST$units)
  expect_equal(entry$label, copernicus_variables()$SST$label)
  expect_true(grepl("anfc", entry$dataset_id))
})
