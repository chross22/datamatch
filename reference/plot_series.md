# Plot a variable through time

Reduces each time step to one number over the study area and plots the
series, which is how a seasonal cycle, a trend, or a step change at a
product boundary becomes visible.

## Usage

``` r
plot_series(env_dat, vars = NULL, fun = mean, spread = TRUE, ...)
```

## Arguments

- env_dat:

  an `sf` POINT object from
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)

- vars:

  which variables to plot; `NULL` uses all covariate columns. Each gets
  its own panel, since covariates rarely share units.

- fun:

  the summary applied across cells within each time step

- spread:

  draw the interquartile range across cells as a band

- ...:

  passed to
  [`graphics::plot()`](https://rdrr.io/r/graphics/plot.default.html)

## Value

a data frame of the plotted series, invisibly

## Details

The spatial spread is drawn behind the line as a shaded band, because a
mean alone hides the difference between a uniformly warm month and one
that is warm inshore and cold offshore.

## See also

[`plot_env()`](https://chross22.github.io/datamatch/reference/plot_env.md)
for one step in space,
[`plot_coverage()`](https://chross22.github.io/datamatch/reference/plot_coverage.md)

## Examples

``` r
if (FALSE) { # \dontrun{
env <- accessEnvDat(vars = c("SST", "MLD"), years = 2003:2017, months = 1:12,
                    bounding_box = bb)

plot_series(env)
plot_series(env, "SST", fun = max)   # the warmest cell each month
} # }
```
