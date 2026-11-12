# Every target time step within the periods the source covers

Built from the year-month combinations actually present, not from every
year crossed with every month. A crossing turned a November-to-February
series into one also covering January and February of the first year and
November and December of the second - four months nobody fetched, filled
by extrapolation or left `NA`. Annual input covers all twelve months of
each year present, since that is the period an annual value describes.

## Usage

``` r
target_time_steps(flat, from, to)
```

## Arguments

- flat:

  a data frame with YEAR/MONTH/DAY columns

- from:

  source resolution

- to:

  target resolution

## Value

a Date vector of the steps to produce
