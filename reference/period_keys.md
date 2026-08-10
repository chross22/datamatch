# Period a row belongs to, and how it is stamped in the result

Monthly output carries `DAY = 1` and annual output `MONTH = 1, DAY = 1`.
That is not cosmetic:
[`detect_temporal_resolution()`](https://chross22.github.io/datamatch/reference/detect_temporal_resolution.md)
infers annual data from several years all stamped on one month, so
aggregating to years and then passing the result to
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
only works if the two agree on the convention.

## Usage

``` r
period_keys(flat, to)
```

## Arguments

- flat:

  a data frame with YEAR/MONTH/DAY columns

- to:

  `"month"` or `"year"`

## Value

a list with `YEAR`, `MONTH`, `DAY`, and a `label` identifying the period
