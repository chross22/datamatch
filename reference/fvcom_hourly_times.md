# Time steps of one sub-daily FVCOM file, as UTC instants

[`fvcom_times()`](https://camilleross.org/datamatch/reference/fvcom_times.md)
returns dates, which is all a monthly aggregation needs. An hourly file
needs the hour as well, so this keeps `Itime2` — the milliseconds within
the day that the date-only reader discards.

## Usage

``` r
fvcom_hourly_times(handle)
```

## Arguments

- handle:

  an open `ncdf4` handle

## Value

a `POSIXct` vector in UTC, one per time step
