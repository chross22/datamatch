# Infer the temporal resolution of a set of time steps

Reads the resolution off the time steps actually present: more than one
day within any month means daily data, and more than one month within
any year means monthly data.

## Usage

``` r
detect_temporal_resolution(x)
```

## Arguments

- x:

  an object with YEAR/MONTH/DAY columns, typically the `source` side of
  a match

## Value

one of "day", "month", or "year"

## Details

A single time step per year is genuinely ambiguous - it looks the same
whether the data is annual, or monthly but subset to one month. Annual
is inferred only with positive evidence for it: several years present,
each stamped on the same single month, as annual products conventionally
are. Everything else falls back to monthly, because guessing too coarse
is the more damaging error - it silently matches observations to a time
step from a different month, whereas guessing too fine leaves them
unmatched and warns. Pass `temporal_resolution` explicitly to override.
