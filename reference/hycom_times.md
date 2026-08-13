# Time steps of an open HYCOM year, as UTC instants

The axis is hours from an epoch named in its own `units` attribute, and
the values are negative for anything before it — the reanalysis counts
from 2000-01-01 and starts in 1994. Read rather than assumed for that
reason.

## Usage

``` r
hycom_times(handle)
```

## Arguments

- handle:

  an open `ncdf4` handle

## Value

a `POSIXct` vector in UTC, one per time step
