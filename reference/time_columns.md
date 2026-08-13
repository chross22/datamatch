# The columns that stamp a row in time rather than describe conditions

Everything else in an
[`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
result is a covariate, so this is what separates the two. Named in one
place because getting it wrong is quiet: anything omitted here is
aggregated, regridded, and plotted as though it were data, and `HOUR`
averaged across a day gives 11.5 in a column that looks like a
measurement.

## Usage

``` r
time_columns()
```

## Value

the reserved time column names, coarsest first

## Details

`HOUR` is present only on hourly downloads. Everything that uses this
intersects against the columns actually present rather than assuming all
four.
