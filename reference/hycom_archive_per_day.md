# Choose one archive per day, for a continuous read

Prefers the reanalysis wherever it reaches, because it is one internally
consistent run; falls back to the operational archive that starts
earliest among those covering the day, so the result crosses as few
seams as it can.

## Usage

``` r
hycom_archive_per_day(days, archives)
```

## Arguments

- days:

  the days to place

- archives:

  [`hycom_archives()`](https://chross22.github.io/datamatch/reference/hycom_archives.md)

## Value

one archive name per day, `NA` where none covers it
