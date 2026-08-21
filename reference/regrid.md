# Resample environmental data onto another grid

The shared implementation of
[`upscale_grid()`](https://camilleross.org/datamatch/reference/upscale_grid.md)
and
[`downscale_grid()`](https://camilleross.org/datamatch/reference/downscale_grid.md).
Both directions are the same operation on a different set of methods, so
they differ only in what they validate and which terra call they end up
in.

## Usage

``` r
regrid(
  env_dat,
  to,
  vars = NULL,
  method,
  direction,
  min_coverage = 0,
  keep_counts = FALSE,
  idw_radius = NULL,
  idw_power = 2
)
```

## Arguments

- env_dat:

  an `sf` POINT object on a regular grid

- to:

  target resolution or `sf` object

- vars:

  columns to resample, or `NULL` for all covariates

- method:

  method name(s), validated against `direction`

- direction:

  `"up"` or `"down"`

- min_coverage:

  minimum non-missing fraction (upscaling only)

- keep_counts:

  add coverage columns (upscaling only)

- idw_radius, idw_power:

  inverse distance weighting parameters

## Value

an `sf` POINT object on the target grid

## Details

Time steps are handled one at a time, as
[`fill_satellite_gaps()`](https://camilleross.org/datamatch/reference/fill_satellite_gaps.md)
does: each step is a complete grid of its own, and stacking them into
one raster would make a variable's layers indistinguishable from its
time steps.
