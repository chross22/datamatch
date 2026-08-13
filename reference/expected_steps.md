# How many source steps a target period should contain

The denominator for `min_coverage`. Deliberately the number of steps the
period *has* rather than the number downloaded, so that a partly-fetched
month is caught instead of scoring full coverage on its own handful of
days.

## Usage

``` r
expected_steps(keys, from, to, per_day = 24)
```

## Arguments

- keys:

  output of
  [`period_keys()`](https://chross22.github.io/datamatch/reference/period_keys.md)

- from:

  source resolution

- to:

  target period

- per_day:

  how many sub-daily steps a whole day holds, from
  [`sub_daily_steps()`](https://chross22.github.io/datamatch/reference/sub_daily_steps.md).
  24 for an hourly series, 8 for a three-hourly one.

## Value

numeric vector, one per row
