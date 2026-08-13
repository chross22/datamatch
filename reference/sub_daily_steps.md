# How many sub-daily steps a whole day of this series holds

The denominator for `min_coverage` when aggregating sub-daily data. Not
every sub-daily product is hourly: the Copernicus wind is, at 24 steps a
day, but HYCOM is three-hourly, at 8. Assuming 24 would score a complete
HYCOM day at a third of its coverage and return `NA` for every one of
them.

## Usage

``` r
sub_daily_steps(flat)
```

## Arguments

- flat:

  a data frame with an `HOUR` column

## Value

steps per day

## Details

Read from the spacing of the hours actually present rather than from a
recorded step, so it is right for any regular sub-daily series without
each source having to declare itself. The smallest gap between distinct
hours is the step; a series carrying one hour only cannot say, and falls
back to hourly, which is the conservative reading — it under-counts
coverage rather than over-counting it.
