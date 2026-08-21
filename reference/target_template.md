# Work out the target grid

Work out the target grid

## Usage

``` r
target_template(env_dat, to, source_res, direction)
```

## Arguments

- env_dat:

  the source object

- to:

  target resolution or `sf` object

- source_res:

  the source resolution from
  [`grid_resolution()`](https://camilleross.org/datamatch/reference/grid_resolution.md)

- direction:

  `"up"` or `"down"`, for the direction check

## Value

a `SpatRaster` template with no values

## Why a stated resolution is anchored

When `to` is a number, the cell centres are placed on a grid anchored at
the origin rather than at the data's own corner. Two products upscaled
to 0.25 degrees therefore land on the *same* cells and can be joined;
anchored to their own extents they would sit half a cell apart and
silently fail to line up.
