# Resample one time step

Resample one time step

## Usage

``` r
regrid_step(
  coords,
  values,
  vars,
  methods,
  target,
  crs,
  direction,
  min_coverage,
  keep_counts,
  idw_radius,
  idw_power,
  source_res,
  cat_levels = list()
)
```

## Arguments

- coords:

  matrix of source cell centres for this step

- values:

  data frame of source values for this step

- vars:

  columns to resample

- methods:

  named vector of resolved terra method names

- target:

  a `SpatRaster` template defining the target grid

- crs:

  the CRS to restore on the way out

- direction:

  `"up"` or `"down"`

- min_coverage:

  minimum non-missing fraction

- keep_counts:

  add coverage columns

- idw_radius, idw_power:

  inverse distance weighting parameters

- source_res:

  source grid resolution, for the IDW radius default

- cat_levels:

  named list of factor levels for non-numeric columns

## Value

an `sf` POINT object for this step
