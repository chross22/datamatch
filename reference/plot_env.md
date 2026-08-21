# Map an environmental variable

A quick look at what came back from any access function — the first
thing worth doing after a download, and the fastest way to catch a
bounding box that came out somewhere unintended, a variable that is all
`NA`, or a depth range that returned the wrong level.

## Usage

``` r
plot_env(env_dat, var = NULL, time = 1, palette = "viridis", main = NULL, ...)
```

## Arguments

- env_dat:

  an `sf` POINT object from any access function -
  [`accessCopernicus()`](https://camilleross.org/datamatch/reference/accessCopernicus.md),
  [`accessFVCOM()`](https://camilleross.org/datamatch/reference/accessFVCOM.md),
  [`accessHYCOM()`](https://camilleross.org/datamatch/reference/accessHYCOM.md),
  [`accessCCMP()`](https://camilleross.org/datamatch/reference/accessCCMP.md)
  or
  [`accessERDDAP()`](https://camilleross.org/datamatch/reference/accessERDDAP.md)

- var:

  which variable to map; `NULL` uses the first covariate column

- time:

  which time step, as an index or a named vector of `YEAR`/`MONTH`/`DAY`
  values

- palette:

  a
  [`grDevices::hcl.colors()`](https://rdrr.io/r/grDevices/palettes.html)
  palette name. The default is perceptually uniform and readable in
  greyscale, which matters more for a field of continuous values than
  the usual rainbow does.

- main:

  plot title; the default names the variable and the time step

- ...:

  passed to
  [`terra::plot()`](https://rspatial.github.io/terra/reference/plot.html)

## Value

the `SpatRaster` that was plotted, invisibly

## Details

The data are rendered as a raster rather than as points, so gaps read as
holes rather than as absent dots, and cell size is visible.

## Time steps

Environmental data carries many time steps and a map shows one. `time`
picks it: a number is an index into the steps present, and a list or
vector names the step directly (`c(YEAR = 2010, MONTH = 6)`). The
default is the first step, and the step being shown is written into the
title so a map is never ambiguous about which month it is.

## See also

[`plot_coverage()`](https://camilleross.org/datamatch/reference/plot_coverage.md)
for where the gaps are,
[`plot_series()`](https://camilleross.org/datamatch/reference/plot_series.md)
for how a variable moves through time

## Examples

``` r
if (FALSE) { # \dontrun{
env <- accessCopernicus(vars = c("SST", "CHL"), years = 2010, months = 1:12,
                    bounding_box = bb)

plot_env(env)                                  # first variable, first step
plot_env(env, "CHL", time = c(MONTH = 6))      # June chlorophyll
} # }
```
