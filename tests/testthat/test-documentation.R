# Guards against the failure these tests exist because of: code lands, the
# documentation describing it does not, and nothing notices. Seven exported
# functions - fetch_bathymetry(), attach_climate_index() and their companions -
# were once implemented, tested, and absent from the README entirely.
#
# The source tree is preferred over the installed copy, so a run from the working
# directory checks what is about to be committed rather than what was installed
# last. R CMD check has no source tree, and falls through to the installed files,
# which came from the tarball being checked and are therefore current too.

package_file <- function(name) {
  local <- file.path(c("../..", "../../..", "."), name)
  hit <- local[file.exists(local)]
  if (length(hit) > 0) return(hit[1])

  installed <- system.file(name, package = "datamatch")
  if (nzchar(installed)) installed else NULL
}

readme_text <- function() {
  path <- package_file("README.md")
  if (is.null(path)) return(NULL)
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

test_that("every exported function is mentioned in the README", {
  readme <- readme_text()
  skip_if(is.null(readme), "README.md not reachable from the test directory")

  exported <- getNamespaceExports("datamatch")
  # S3 methods are an implementation detail of printing, not something a reader
  # calls by name.
  exported <- grep("^print\\.", exported, value = TRUE, invert = TRUE)

  undocumented <- exported[!vapply(exported, function(fn) {
    grepl(fn, readme, fixed = TRUE)
  }, logical(1))]

  expect_equal(undocumented, character(0),
               info = paste("Exported but absent from the README:",
                            paste(undocumented, collapse = ", ")))
})

test_that("every climate index is named in the README", {
  readme <- readme_text()
  skip_if(is.null(readme), "README.md not reachable from the test directory")

  missing <- setdiff(names(climate_indices()),
                     regmatches(readme, gregexpr("\\b[A-Z]{2,4}\\b", readme))[[1]])

  expect_equal(missing, character(0),
               info = paste("Index in the catalog but not the README:",
                            paste(missing, collapse = ", ")))
})

test_that("every catalog variable and bathymetry layer is named in the README", {
  readme <- readme_text()
  skip_if(is.null(readme), "README.md not reachable from the test directory")

  named <- regmatches(readme, gregexpr("\\b[A-Z][A-Z0-9_]{1,11}\\b", readme))[[1]]
  wanted <- c(names(copernicus_variables()), names(bathymetry_variables()))

  expect_equal(setdiff(wanted, named), character(0),
               info = "A variable in the catalog is not mentioned in the README")
})

test_that("DESCRIPTION describes the package as it is now", {
  # The specific way this went stale: matchData() stopped being about species
  # observations, and the Title still said it was. A claim that is wrong is
  # worse than one that is merely incomplete, because a reader acts on it.
  path <- package_file("DESCRIPTION")
  skip_if(is.null(path), "DESCRIPTION not reachable")
  description <- read.dcf(path)

  expect_false(grepl("Species Observations", description[1, "Title"], fixed = TRUE))
  # The things the package grew that the Description once omitted.
  for (topic in c("resampling", "climate", "daily")) {
    expect_match(description[1, "Description"], topic, ignore.case = TRUE)
  }
})

test_that("NEWS.md is in the shape R can parse", {
  news <- package_file("NEWS.md")
  skip_if(is.null(news), "NEWS.md not reachable")

  # "# datamatch (development version)", the usethis convention, yields a
  # "No news entries found" NOTE from R CMD check. The version heading has to be
  # something R can parse as a version.
  #
  # Checked by pattern rather than by parsing, because R's own NEWS.md reader
  # needs commonmark, which is not on the CI runners. Depending on it here would
  # make this test fail for a reason that has nothing to do with NEWS.md.
  headings <- grep("^#+ ", readLines(news, warn = FALSE), value = TRUE)
  expect_gt(length(headings), 0)

  version_heading <- headings[1]
  expect_match(version_heading, "^# datamatch [0-9]+\\.[0-9]+")
  expect_false(grepl("development version", version_heading, fixed = TRUE))

  # Where commonmark is available, confirm R really does read entries from it.
  skip_if_not_installed("commonmark")
  db <- tools:::.build_news_db_from_package_NEWS_md(news)
  expect_gt(nrow(db), 0)
  expect_false(anyNA(db$Version))
})

test_that("cited DOIs are the ones that resolve", {
  # A dead DOI is worse than a missing one: it looks like a citation and sends
  # the reader nowhere. BODC retires the old DOI on each RAPID release, and the
  # one this package first shipped (223b34a3-...) now 404s. Pinned here so a
  # revert to it is caught without the tests needing a network.
  amoc <- climate_indices()$AMOC$reference

  expect_match(amoc, "10.5285/48d0bf43-0598-ceb2-e063-7086abc062f1", fixed = TRUE)
  expect_false(grepl("223b34a3-2dc5-c945-e063-6c86abc0f5b3", amoc, fixed = TRUE))

  readme <- readme_text()
  skip_if(is.null(readme), "README.md not reachable")
  expect_false(grepl("223b34a3-2dc5-c945-e063-6c86abc0f5b3", readme, fixed = TRUE))
})

test_that("every data source the package uses is cited in the README", {
  readme <- readme_text()
  skip_if(is.null(readme), "README.md not reachable")

  # Everything datamatch returns comes from someone else's data, so each source
  # needs a DOI or a named provider in the reference list.
  for (doi in c("10.48670/moi-00021",   # physics reanalysis
                "10.48670/moi-00019",   # biogeochemistry hindcast
                "10.48670/moi-00281",   # ocean colour
                "10.48670/moi-00016",   # physics forecast
                "10.48670/moi-00015",   # biogeochemistry forecast
                "10.25921/fd45-gt74",   # ETOPO 2022
                "10.1038/s41467-023-38321-y")) {   # LCR
    expect_true(grepl(doi, readme, fixed = TRUE),
                info = paste("DOI missing from the README:", doi))
  }

  # The operational indices have no paper, so the provider is the credit.
  expect_match(readme, "Climate Prediction Center")
  expect_match(readme, "Physical Sciences Laboratory")
})
