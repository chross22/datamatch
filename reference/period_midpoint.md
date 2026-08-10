# The point in time a period's value represents

The middle of the period, not its start. A monthly mean placed at day 1
would shift an interpolated series half a month early.

## Usage

``` r
period_midpoint(flat, from)
```

## Arguments

- flat:

  a data frame with YEAR/MONTH/DAY columns

- from:

  source resolution

## Value

a Date vector
