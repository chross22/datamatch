#' Covariate column names in an environmental data object
#'
#' Everything that is not a time column, the geometry, or bookkeeping.
#'
#' `<var>_source` columns are included. They are provenance, but they travel
#' with the variable they describe: [upscale_grid()] and [upscale_time()] carry
#' a non-numeric column as a categorical, so a resampled object keeps the record
#' of which source each value came from. `<var>_depth` is excluded, because the
#' mean of two depths is not the depth any value came from.
#'
#' @param env_dat an `sf` POINT object from any access function -
#'   [accessCopernicus()], [accessFVCOM()], [accessHYCOM()], [accessCCMP()] or
#'   [accessERDDAP()]
#' @return character vector of covariate column names
#' @examples
#' \dontrun{
#' covariate_columns(env)
#' }
#' @export
covariate_columns <- function(env_dat) {
  candidates <- setdiff(names(env_dat),
                        c(time_columns(), attr(env_dat, "sf_column")))
  candidates[!is_bookkeeping_column(candidates)]
}

#' Fill satellite gaps with the model equivalent
#'
#' Satellite ocean colour is missing wherever cloud, ice, or low sun angle blocked
#' the view, and those gaps are not random — they cluster in exactly the seasons
#' and latitudes that are often most interesting. This substitutes the model value
#' at each missing cell, giving a gap-free series without discarding the observed
#' values where they exist.
#'
#' @section What this does and does not do:
#' The two sources are different measurements of the same quantity, not
#' interchangeable ones. Satellite chlorophyll is an optical retrieval at 4 km;
#' model chlorophyll is simulated at 0.25 degrees. Splicing them produces a series
#' whose statistical properties change wherever the source changes — usually a
#' step in both variance and bias at the seam.
#'
#' So this is offered with two safeguards rather than as a silent default:
#'
#' \itemize{
#'   \item Nothing is rescaled by default. The model values go in as they are, so
#'     a discontinuity at the seam is visible rather than smoothed over. Set
#'     `rescale = TRUE` to match the model's mean and variance to the satellite's
#'     over the cells where both exist, which reduces the step at the cost of
#'     changing the model values.
#'   \item A companion `<var>_source` column records which source each value came
#'     from, so a model can include it, and an analysis can check whether a result
#'     rests on observed or simulated cells.
#' }
#'
#' @param satellite an `sf` POINT object of satellite data from
#'   [accessCopernicus()]
#' @param model an `sf` POINT object of the model equivalent, over the same
#'   period. It need not be on the same grid: values are taken from the nearest
#'   model cell within each time step.
#' @param vars named character vector mapping satellite columns to model columns,
#'   e.g. `c(CHL = "CHL_MODEL")`. When unnamed, the same name is assumed in both.
#' @param rescale match the model's mean and variance to the satellite's before
#'   filling, computed per time step over the cells where both exist
#' @return `satellite` with gaps filled, plus a `<var>_source` factor column per
#'   variable recording `"satellite"` or `"model"`
#' @examples
#' \dontrun{
#' chl_sat <- accessCopernicus(vars = "CHL", years = 2010, months = 1:12, bounding_box = bb)
#' chl_mod <- accessCopernicus(vars = "CHL_MODEL", years = 2010, months = 1:12,
#'                         bounding_box = bb)
#'
#' filled <- fill_satellite_gaps(chl_sat, chl_mod, c(CHL = "CHL_MODEL"))
#' table(filled$CHL_source)
#' }
#' @export
fill_satellite_gaps <- function(satellite, model, vars, rescale = FALSE) {
  if (is.null(names(vars))) names(vars) <- vars

  missing_sat <- setdiff(names(vars), names(satellite))
  missing_mod <- setdiff(unname(vars), names(model))
  if (length(missing_sat) > 0 || length(missing_mod) > 0) {
    stop("Column(s) not found: ",
         paste(c(missing_sat, missing_mod), collapse = ", "),
         "\nSatellite has: ", paste(covariate_columns(satellite), collapse = ", "),
         "\nModel has: ", paste(covariate_columns(model), collapse = ", "),
         call. = FALSE)
  }

  steps <- unique(sf::st_drop_geometry(satellite)[c("YEAR", "MONTH", "DAY")])
  model_time <- sf::st_drop_geometry(model)[c("YEAR", "MONTH", "DAY")]

  for (satellite_var in names(vars)) {
    model_var <- vars[[satellite_var]]
    source <- rep("satellite", nrow(satellite))

    for (i in seq_len(nrow(steps))) {
      step <- steps[i, ]
      sat_rows <- which(satellite$YEAR == step$YEAR & satellite$MONTH == step$MONTH &
                          satellite$DAY == step$DAY)
      gaps <- sat_rows[is.na(satellite[[satellite_var]][sat_rows])]
      if (length(gaps) == 0) next

      mod_rows <- which(model_time$YEAR == step$YEAR & model_time$MONTH == step$MONTH &
                          model_time$DAY == step$DAY)
      if (length(mod_rows) == 0) next

      model_step <- model[mod_rows, ]
      # Nearest model cell, since the grids differ. Matching within the time
      # step rather than across the whole stack, or every gap would be filled
      # from whichever step the tie happened to resolve to.
      nearest <- sf::st_nearest_feature(sf::st_geometry(satellite)[gaps],
                                        sf::st_geometry(model_step))
      values <- model_step[[model_var]][nearest]

      if (rescale) {
        values <- rescale_to(values, model_step, model_var,
                             satellite[sat_rows, ], satellite_var)
      }

      satellite[[satellite_var]][gaps] <- values
      source[gaps] <- ifelse(is.na(values), "missing", "model")
    }

    satellite[[paste0(satellite_var, "_source")]] <-
      factor(source, levels = c("satellite", "model", "missing"))
  }
  satellite
}

#' Match a model series' mean and variance to the satellite's
#'
#' Computed over the cells where both sources have a value in this time step, so
#' the correction reflects conditions at the time rather than a global average.
#' Falls back to the uncorrected values when too few overlapping cells exist to
#' estimate a spread.
#'
#' @param values model values to correct
#' @param model_step model data for this time step
#' @param model_var model column name
#' @param satellite_step satellite data for this time step
#' @param satellite_var satellite column name
#' @return the corrected values
#' @keywords internal
rescale_to <- function(values, model_step, model_var, satellite_step, satellite_var) {
  overlap <- sf::st_nearest_feature(sf::st_geometry(satellite_step),
                                    sf::st_geometry(model_step))
  observed <- satellite_step[[satellite_var]]
  simulated <- model_step[[model_var]][overlap]
  both <- !is.na(observed) & !is.na(simulated)

  if (sum(both) < 10) return(values)

  observed_sd <- stats::sd(observed[both])
  simulated_sd <- stats::sd(simulated[both])
  if (!is.finite(simulated_sd) || simulated_sd == 0) return(values)

  (values - mean(simulated[both])) * (observed_sd / simulated_sd) +
    mean(observed[both])
}
