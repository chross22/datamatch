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
  # A fetch that spans archives records the source per row rather than once for
  # the object, because "one of these two runs" is not what any single row came
  # from. The object-level tag then names every run present, in date order.
  if (!is.null(x[[".datamatch_source"]])) {
    return(paste(unique(x[[".datamatch_source"]]), collapse = "+"))
  }
  attr(x, "datamatch_source") %||% NA_character_
}

#' The per-row source tags of a fetch, where it has them
#'
#' `NULL` for the usual case of a fetch from a single archive, whose source is
#' one value for the whole object and is held as an attribute instead.
#'
#' @param x a fetched object
#' @return <char> one tag per row, or `NULL`
#' @keywords internal
row_sources <- function(x) {
  x[[".datamatch_source"]]
}

#' Stamp a fetched object with its source
#'
#' @param x the object to stamp
#' @param source <char> the source family, e.g. `"hycom"`
#' @param detail <char> the archive, dataset or version within it
#' @return `x`, stamped
#' @keywords internal
stamp_source <- function(x, source, detail) {
  tags <- paste0(source, ":", detail)

  # `detail` is one value for the usual single-archive fetch, and one per row
  # for a continuous one. In the second case the tag has to travel with the row,
  # since the whole object no longer has a single answer.
  # Only a fetch that genuinely mixed archives needs the per-row column. A
  # continuous read that never left the reanalysis has one answer like any
  # other, and should not carry a column saying so on every row.
  if (length(unique(tags)) > 1) {
    stopifnot(length(tags) == nrow(x))
    x[[".datamatch_source"]] <- tags
    attr(x, "datamatch_source") <- paste(unique(tags), collapse = "+")
  } else {
    attr(x, "datamatch_source") <- unique(tags)
  }
  x
}

#' Columns that are bookkeeping rather than data
#'
#' `<var>_depth` records which model level a derived bottom value was taken
#' from, and `.datamatch_source` is the per-row source tag a fetch spanning
#' several archives carries. Neither measures anything: the mean of two depths
#' is not the depth any value came from, and the internal tag is consumed by
#' [matchData()] rather than kept. So [covariate_columns()] leaves both out, and
#' nothing resamples or plots them as though they were covariates.
#'
#' @section Why `<var>_source` is not here:
#' It is provenance too, but it travels with the variable it describes rather
#' than being left behind by it. [upscale_grid()] and [upscale_time()] carry a
#' non-numeric column as a categorical - the commonest value when aggregating,
#' the nearest when interpolating - which is exactly what a source tag needs,
#' and both were written expecting one to ride along. Excluding it here meant it
#' never did, so the record of which source a value came from was lost at the
#' first resample, which is the point at which it matters most.
#'
#' @param names <char> column names to inspect
#' @return <logical> one per name
#' @keywords internal
is_bookkeeping_column <- function(names) {
  grepl("_depth$", names) | names == ".datamatch_source"
}
