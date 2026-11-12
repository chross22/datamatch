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

## Details

The unit is read rather than assumed: days, hours, minutes and seconds
(and their CF abbreviations) are converted exactly. Months and years are
refused, because their length depends on a calendar that the conversion
would have to guess at, and so is anything unrecognised.
