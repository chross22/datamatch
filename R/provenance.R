#' Which source and archive produced a fetched object
#'
#' Every access function stamps its result with where the values came from, and
#' this reads it back. The tag is short and stable — `"copernicus:..."`,
#' `"fvcom:GOM3"`, `"hycom:GLBv53X"`, `"ccmp:v03.1"`, `"erddap:MUR"` — naming the
#' source and the particular archive or dataset within it.
#'
#' @section Why this exists:
#' The five sources deliberately share variable names, so an `SST` column means
#' the same *quantity* whichever produced it and everything downstream works
#' unchanged. That is the point of the design and also its hazard: the column
#' name alone cannot say whether a value came from a global reanalysis, a
#' regional coastal model, or an independent global model, and those are not the
#' same number.
#'
#' The package already records provenance where a value's origin is ambiguous —
#' [fill_satellite_gaps()] writes a `<var>_source` column, and a derived `BOTS`
#' returns `BOTS_depth`. This extends the same habit to the thing that varies
#' most: which model the value came from at all.
#'
#' @param x an object from [accessCopernicus()], [accessFVCOM()], [accessHYCOM()],
#'   [accessCCMP()] or [accessERDDAP()]
#' @return <char> the source tag, or `NA` if the object carries none — which is
#'   the case for anything built by hand or produced before this was recorded
#' @examples
#' \dontrun{
#' env <- accessHYCOM(vars = "BOTS", dates = "2010-06-15", bounding_box = bb)
#' source_of(env)
#' #> [1] "hycom:GLBv53X"
#' }
#' @seealso [matchData()], which carries this into `<var>_source` columns
#' @export
source_of <- function(x) {
  attr(x, "datamatch_source") %||% NA_character_
}

#' Stamp a fetched object with its source
#'
#' @param x the object to stamp
#' @param source <char> the source family, e.g. `"hycom"`
#' @param detail <char> the archive, dataset or version within it
#' @return `x`, stamped
#' @keywords internal
stamp_source <- function(x, source, detail) {
  attr(x, "datamatch_source") <- paste0(source, ":", detail)
  x
}

#' Columns that record where a value came from rather than what it is
#'
#' `<var>_source` columns written by [matchData()] and [fill_satellite_gaps()],
#' and the `<var>_depth` column a derived bottom variable returns. They describe
#' the data rather than measuring anything, so aggregating or interpolating them
#' is meaningless — a mean of two source tags is not a source, and the mean of
#' two depths is not the depth any value came from.
#'
#' @param names <char> column names to inspect
#' @return <logical> one per name
#' @keywords internal
is_provenance_column <- function(names) {
  grepl("_source$", names) | grepl("_depth$", names)
}
