# How many source steps a target period should contain

The denominator for `min_coverage`. Deliberately the number of steps the
period *has* rather than the number downloaded, so that a partly-fetched
month is caught instead of scoring full coverage on its own handful of
days.

## Usage

``` r
expected_steps(keys, from, to)
```

## Arguments

- keys:

  output of
  [`period_keys()`](https://chross22.github.io/datamatch/reference/period_keys.md)

- from:

  source resolution

- to:

  target period

## Value

numeric vector, one per row
