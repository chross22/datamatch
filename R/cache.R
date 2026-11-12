#' Write an object to the cache so that a reader never sees half a file
#'
#' `saveRDS()` writes straight to its destination, so an interrupted run (a
#' killed worker, Ctrl-C) or two sessions fetching the same day at once can
#' leave a truncated file that every later run trusts. The object is written to
#' a uniquely named file in the same directory and renamed into place, which is
#' atomic on one filesystem: a reader sees either no file or the whole of one.
#'
#' @param object the object to save
#' @param path the cache file to write
#' @return `path`, invisibly
#' @keywords internal
save_rds_atomic <- function(object, path) {
  partial <- partial_path(path)
  on.exit(unlink(partial), add = TRUE)
  saveRDS(object, partial)
  finish_partial(partial, path)
}

#' A uniquely named working file beside a cache file
#'
#' The name carries the process id and a random suffix so that two processes
#' writing the same cache entry do not write into each other's working file.
#' It sits in the same directory as `path` so that the final rename stays on
#' one filesystem.
#'
#' @param path the cache file the working file will become
#' @return a path
#' @keywords internal
partial_path <- function(path) {
  tempfile(pattern = paste0(basename(path), ".", Sys.getpid(), "."),
           tmpdir = dirname(path), fileext = ".part")
}

#' Move a completed working file into its place in the cache
#'
#' @param partial the completed working file
#' @param path the cache file
#' @return `path`, invisibly
#' @keywords internal
finish_partial <- function(partial, path) {
  if (!file.rename(partial, path)) {
    stop("Could not move ", partial, " into place at ", path, call. = FALSE)
  }
  invisible(path)
}
