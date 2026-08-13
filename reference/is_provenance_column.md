# Columns that record where a value came from rather than what it is

`<var>_source` columns written by
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
and
[`fill_satellite_gaps()`](https://chross22.github.io/datamatch/reference/fill_satellite_gaps.md),
and the `<var>_depth` column a derived bottom variable returns. They
describe the data rather than measuring anything, so aggregating or
interpolating them is meaningless — a mean of two source tags is not a
source, and the mean of two depths is not the depth any value came from.

## Usage

``` r
is_provenance_column(names)
```

## Arguments

- names:

  column names to inspect

## Value

one per name
