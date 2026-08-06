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

test_that("the dictionary can be filtered by product", {
  physical <- variable_dictionary("physical")
  biogeochemical <- variable_dictionary("biogeochemical")

  expect_true("SST" %in% physical$name)
  expect_false("CHL" %in% physical$name)
  expect_true("CHL" %in% biogeochemical$name)
  expect_false("SST" %in% biogeochemical$name)

  expect_equal(nrow(physical) + nrow(biogeochemical),
               nrow(variable_dictionary("all")))
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
  resolved <- resolve_variables(c("SST", "CHL"))

  expect_equal(resolved$codes, c("thetao", "chl"))
  # The names are what the result columns should be called.
  expect_equal(resolved$names, c("SST", "CHL"))
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
  datasets <- variable_dataset(c("SST", "CHL", "nonsense"))

  expect_true(grepl("_phy_", datasets[["SST"]]))
  expect_true(grepl("_bgc_", datasets[["CHL"]]))
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
