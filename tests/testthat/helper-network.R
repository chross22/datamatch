# Tests that reach a real server are opt-in.
#
# They are the only tests that exercise the readers end to end, so they are
# worth having - but they are slow, they depend on four services that are
# sometimes down, and one of them downloads 33 MB. Running them on every push
# would make CI flaky in a way that teaches people to ignore it.
#
# So they run only when DATAMATCH_NETWORK_TESTS is set, which the weekly
# source-check workflow does and an ordinary push does not.
#
# `skip_if_offline()` is deliberately not used: it requires the curl package,
# which is not a dependency here, and throws "package not found" rather than
# skipping when it is absent. That is exactly how these tests broke CI - an
# error where a skip was intended.
skip_if_no_network <- function() {
  testthat::skip_if_not_installed("ncdf4")

  if (!nzchar(Sys.getenv("DATAMATCH_NETWORK_TESTS"))) {
    testthat::skip("network tests are opt-in; set DATAMATCH_NETWORK_TESTS=true")
  }
  invisible(TRUE)
}
