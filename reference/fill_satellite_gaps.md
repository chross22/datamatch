# Fill satellite gaps with the model equivalent

Satellite ocean colour is missing wherever cloud, ice, or low sun angle
blocked the view, and those gaps are not random — they cluster in
exactly the seasons and latitudes that are often most interesting. This
substitutes the model value at each missing cell, giving a gap-free
series without discarding the observed values where they exist.

## Usage

``` r
fill_satellite_gaps(satellite, model, vars, rescale = FALSE)
```

## Arguments

- satellite:

  an `sf` POINT object of satellite data from
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)

- model:

  an `sf` POINT object of the model equivalent, over the same period. It
  need not be on the same grid: values are taken from the nearest model
  cell within each time step.

- vars:

  named character vector mapping satellite columns to model columns,
  e.g. `c(CHL = "CHL_MODEL")`. When unnamed, the same name is assumed in
  both.

- rescale:

  match the model's mean and variance to the satellite's before filling,
  computed per time step over the cells where both exist

## Value

`satellite` with gaps filled, plus a `<var>_source` factor column per
variable recording `"satellite"` or `"model"`

## What this does and does not do

The two sources are different measurements of the same quantity, not
interchangeable ones. Satellite chlorophyll is an optical retrieval at 4
km; model chlorophyll is simulated at 0.25 degrees. Splicing them
produces a series whose statistical properties change wherever the
source changes — usually a step in both variance and bias at the seam.

So this is offered with two safeguards rather than as a silent default:

- Nothing is rescaled by default. The model values go in as they are, so
  a discontinuity at the seam is visible rather than smoothed over. Set
  `rescale = TRUE` to match the model's mean and variance to the
  satellite's over the cells where both exist, which reduces the step at
  the cost of changing the model values.

- A companion `<var>_source` column records which source each value came
  from, so a model can include it, and an analysis can check whether a
  result rests on observed or simulated cells.

## Examples

``` r
if (FALSE) { # \dontrun{
chl_sat <- accessEnvDat(vars = "CHL", years = 2010, months = 1:12, bounding_box = bb)
chl_mod <- accessEnvDat(vars = "CHL_MODEL", years = 2010, months = 1:12,
                        bounding_box = bb)

filled <- fill_satellite_gaps(chl_sat, chl_mod, c(CHL = "CHL_MODEL"))
table(filled$CHL_source)
} # }
```
