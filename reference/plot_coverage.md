# Plot how much data each time step actually has

Satellite ocean colour is missing wherever cloud, ice, or low sun angle
blocked the view, and those gaps are not spread evenly — they cluster in
particular seasons and latitudes. A series can look complete in a table
and be mostly empty in winter.

## Usage

``` r
plot_coverage(env_dat, vars = NULL, main = "Data coverage by time step", ...)
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

- vars:

  which variables to show; `NULL` uses all covariate columns

- main:

  plot title

- ...:

  passed to
  [`graphics::plot()`](https://rdrr.io/r/graphics/plot.default.html)

## Value

a data frame of the plotted coverage, invisibly, with one row per time
step per variable

## Details

This plots the fraction of cells carrying a value in each time step,
which is the thing to look at before trusting a monthly mean or deciding
whether
[`fill_satellite_gaps()`](https://camilleross.org/datamatch/reference/fill_satellite_gaps.md)
is worth the seam it introduces.

## See also

[`fill_satellite_gaps()`](https://camilleross.org/datamatch/reference/fill_satellite_gaps.md),
[`upscale_time()`](https://camilleross.org/datamatch/reference/upscale_time.md),
whose `min_coverage` argument acts on the same quantity

## Examples

``` r
if (FALSE) { # \dontrun{
chl <- accessCopernicus(vars = "CHL", years = 2010, months = 1:12, bounding_box = bb)

plot_coverage(chl)
# The winter months are the ones to be careful with.
} # }
```
