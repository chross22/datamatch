# Interpolate environmental data onto a finer time step

Puts a coarse series onto a finer one, so a monthly product can be
matched to observations on their actual dates rather than by month.

## Usage

``` r
downscale_time(
  env_dat,
  to = c("day", "month"),
  vars = NULL,
  method = "step",
  extrapolate = TRUE
)
```

## Arguments

- env_dat:

  an `sf` POINT object from any access function -
  [`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md),
  [`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md),
  [`accessHYCOM()`](https://chross22.github.io/datamatch/reference/accessHYCOM.md),
  [`accessCCMP()`](https://chross22.github.io/datamatch/reference/accessCCMP.md)
  or
  [`accessERDDAP()`](https://chross22.github.io/datamatch/reference/accessERDDAP.md)

- to:

  the target step: `"day"` or `"month"`

- vars:

  columns to aggregate; `NULL` uses all covariate columns

- method:

  one of `"step"`, `"linear"`, `"spline"`; length one for all variables,
  or a named vector per variable

- extrapolate:

  hold the first and last values constant beyond the outermost period
  midpoints. With `FALSE` those half-periods are `NA`, since there is no
  second point to interpolate between.

## Value

an `sf` POINT object with one row per cell per target step

## What this does and does not do

As with
[`downscale_grid()`](https://chross22.github.io/datamatch/reference/downscale_grid.md),
this adds time steps rather than information. A monthly mean rendered
daily still resolves nothing within the month.

There is a further trap specific to the time axis, which is why `step`
is the default:

**`linear` and `spline` do not preserve the period mean.** Interpolate
twelve monthly means to daily values and average those days back up, and
you will not recover the months you started from. The interpolated
series is a plausible smooth curve through the monthly values, not a
disaggregation of them, and any budget or total computed from it will be
off. `step` does preserve the mean, because every day in the month
carries the month's own value.

- `step` — every fine step takes its containing period's value.
  Preserves the period mean; discontinuous at period boundaries.
  Required for categorical columns, and applied to them automatically.

- `linear` — straight lines between period midpoints. Continuous, and
  the usual choice when a series is going into a model as a smooth
  covariate.

- `spline` — a natural cubic spline through the midpoints. Smoother than
  linear, and can overshoot past the source range between points, which
  for a bounded quantity like chlorophyll can produce negatives.

## Where a period's value sits

`linear` and `spline` need each source value placed at a point in time,
and a monthly mean is placed at the **middle** of its month rather than
the first. Placing it at day 1 would shift the whole interpolated series
half a month early, which is a systematic bias rather than a rounding
difference.

## See also

[`upscale_time()`](https://chross22.github.io/datamatch/reference/upscale_time.md)
for the other direction,
[`downscale_grid()`](https://chross22.github.io/datamatch/reference/downscale_grid.md)

## Examples

``` r
if (FALSE) { # \dontrun{
monthly <- accessCopernicus(vars = "SST", years = 2010, months = 1:12, bounding_box = bb)

# Daily steps, each carrying its month's value
daily <- downscale_time(monthly, to = "day")

# A smooth seasonal cycle instead, for a covariate going into a model
smooth <- downscale_time(monthly, to = "day", method = "spline")
} # }
```
