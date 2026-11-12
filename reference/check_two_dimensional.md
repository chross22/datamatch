# Refuse a grid with no spacing in one direction

A single row or a single column of points has no cell size across it, so
[`grid_resolution()`](https://camilleross.org/datamatch/reference/grid_resolution.md)
reports `NA` there and no raster can be built. Left to run, that failed
inside terra with "invalid extent", which names neither the object nor
the cause.

## Usage

``` r
check_two_dimensional(res, what)
```

## Arguments

- res:

  a resolution from
  [`grid_resolution()`](https://camilleross.org/datamatch/reference/grid_resolution.md)

- what:

  how to name the object in the error

## Value

`NULL`, invisibly; called for the error
