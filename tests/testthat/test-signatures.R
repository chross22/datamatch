# The seven access functions are meant to be interchangeable at the call site:
# swapping accessHYCOM() for accessCopernicus() should be a rename, not a
# rewrite. That only holds if they agree on argument order, and nothing else
# enforces it - accessCopernicus() had drifted to leading with product_id and
# dataset_id, so a reader who learned one signature had learned the wrong one.

access_functions <- c("accessCopernicus", "accessFVCOM", "accessHYCOM",
                      "accessCCMP", "accessERDDAP", "accessCEFI",
                      "accessOBDAAC")

test_that("every access function is there to be checked", {
  for (fn in access_functions) {
    expect_true(is.function(get(fn)), info = fn)
  }
})

test_that("the access functions open with the same arguments in the same order", {
  # Every source needs these, and they mean the same thing in each.
  common <- c("vars", "years", "months", "bounding_box", "dates")

  for (fn in access_functions) {
    args <- names(formals(get(fn)))
    expect_identical(args[seq_along(common)], common,
                     info = paste0(fn, "() starts with: ",
                                   paste(args[seq_along(common)], collapse = ", ")))
  }
})

test_that("frequency follows dates wherever a source has more than one step", {
  # accessERDDAP() is daily only, so it has no frequency to place.
  for (fn in setdiff(access_functions, "accessERDDAP")) {
    args <- names(formals(get(fn)))
    expect_identical(args[6], "frequency", info = fn)
  }
})

test_that("overwrite is last everywhere", {
  # It is the argument least often passed, so it belongs furthest from the call.
  for (fn in access_functions) {
    args <- names(formals(get(fn)))
    expect_identical(args[length(args)], "overwrite", info = fn)
  }
})

test_that("the pre-0.2.0 argument order is refused rather than misread", {
  # product_id and dataset_id used to come first. A script calling positionally
  # against that order now puts an identifier into `vars`, which would fetch
  # nothing rather than fail, so it is caught at the call.
  expect_error(
    accessCopernicus("GLOBAL_MULTIYEAR_PHY_001_030",
                     "cmems_mod_glo_phy_my_0.083deg_P1M-m", "SST"),
    "looks like a product or dataset identifier"
  )
  expect_error(
    accessCopernicus("cmems_mod_glo_phy_my_0.083deg_P1M-m"),
    "looks like a product or dataset identifier"
  )
})

test_that("ordinary variable names are not mistaken for identifiers", {
  # The guard must not fire on anything the dictionary actually holds, nor on a
  # raw Copernicus code.
  for (v in c(names(copernicus_variables()), "thetao", "so", "bottomT",
              "SST_ERROR", "CHL_MODEL", "NPP_MODEL")) {
    expect_null(stop_if_legacy_positional(v), info = v)
  }
  expect_null(stop_if_legacy_positional(c("SST", "SSS")))
})
