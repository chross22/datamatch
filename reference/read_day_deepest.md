# Read one time step's full depth column, keeping the deepest wet level

The reanalysis publishes temperature at the sea floor but not salinity,
so a sea-floor salinity has to be taken from the three-dimensional
field: fetch the whole column and keep, in each cell, the deepest level
that holds a value.

## Usage

``` r
read_day_deepest(item, code, name)
```

## Arguments

- item:

  one work item, as built by
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)

- code:

  the Copernicus code fetched, e.g. `so`

- name:

  what to call the result column, e.g. `BOTS`

## Value

a data frame with the value, the depth it came from, `YEAR`, `MONTH` and
`DAY`

## What "deepest wet level" means

A model cell is `NA` below the sea floor, so the last level carrying a
value is the bottom-most one the model resolves there. That is the same
convention Copernicus's own `bottomT` follows, which is why the two
pair.

It is not the sea floor itself. Level spacing coarsens with depth — from
a metre near the surface to several hundred at abyssal depths — so in
deep water the value can sit a long way above the real bottom. The depth
actually used is returned alongside the value rather than left to be
assumed, in a `<name>_depth` column.
