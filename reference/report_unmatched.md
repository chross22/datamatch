# Say how many points got nothing, and why

A point can come back `NA` for two quite different reasons, and the
remedy differs. Outside the grid means the bounding box was drawn too
small. Inside it means the cell holds no depth — ETOPO calls it land,
which at 4 arc-minutes happens readily to inshore stations, since a cell
roughly 7 km across is land if most of it is.

## Usage

``` r
report_unmatched(positions, values, bathy)
```

## Arguments

- positions:

  the coordinate matrix that was extracted at

- values:

  the extracted values of one layer

- bathy:

  the raster they came from

## Value

`NULL`, invisibly; called for the warning

## Details

Reported rather than left to be discovered, because a covariate that is
`NA` for a subset of observations quietly drops those rows from a model
fit.
