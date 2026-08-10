# Rename a table's time columns to YEAR/MONTH/DAY

Only the columns needed for the requested match keys are required, so
monthly matching works on data that has no day column at all.

## Usage

``` r
standardize_time_columns(dat, match_keys)
```

## Arguments

- dat:

  the table being matched

- match_keys:

  the standardized time columns needed, e.g. c("YEAR", "MONTH")

## Value

`dat` with its time columns renamed to YEAR/MONTH/DAY
