# Read the requested time steps of one CEFI variable

Read the requested time steps of one CEFI variable

## Usage

``` r
cefi_read_variable(
  handle,
  entry,
  index,
  keep_lon,
  keep_lat,
  member = NA_integer_
)
```

## Arguments

- handle:

  an open `ncdf4` handle

- entry:

  one entry of
  [`cefi_variables()`](https://camilleross.org/datamatch/reference/cefi_variables.md)

- index:

  the axis indices to read

- keep_lon, keep_lat:

  the grid indices the bounding box selects

- member:

  which ensemble member, or `NA` for a single run

## Value

a named list of numeric vectors, one per requested index, each in
`expand.grid(lon, lat)` order

## Why runs rather than steps or spans

Reading each wanted step with its own request is one network round trip
per month, which for a decade is 120 of them. Reading everything between
the first and the last transfers the whole decade to keep ten months of
it. Contiguous runs are neither: a stretch of consecutive months is one
request, and a gap ends the run instead of being read across. See
[`contiguous_runs()`](https://camilleross.org/datamatch/reference/contiguous_runs.md).
