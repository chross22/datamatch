# Decode a CEFI time axis into dates

The hindcast calls its axis `time` and the forecasts call theirs `lead`,
but both are CF time in days since an epoch — a forecast's epoch being
its own initialisation, which is what makes a lead time placeable on a
calendar at all. So both decode the same way, and the reader does not
need to know which it is looking at.

## Usage

``` r
cefi_axis(handle)
```

## Arguments

- handle:

  an open `ncdf4` handle

## Value

a list with `name`, the axis it found, and `dates`
