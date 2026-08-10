# Refuse a resampling that runs the wrong way

Calling the wrong one of the pair is easy — the target is often another
dataset, whose resolution is not on screen at the call site — and the
result is quietly poor rather than obviously broken: aggregation methods
applied to a finer target reduce to picking one source cell, and
interpolation applied to a coarser one throws away most of the data
without saying so.

## Usage

``` r
check_direction(source_res, target_res, direction)
```

## Arguments

- source_res, target_res:

  resolutions to compare

- direction:

  `"up"` or `"down"`

## Value

`NULL`, invisibly; called for the error
