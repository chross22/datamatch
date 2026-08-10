# Parse the `dates` argument into a sorted, unique vector of dates

`YYYYMMDD` is what a survey database usually holds, and `YYYY-MM-DD` is
what R prints, so both are accepted, along with `Date` objects and a
mixture of the three. Numbers are taken as `YYYYMMDD` too, since an
unquoted `20150402` is an easy thing to type.

## Usage

``` r
parse_dates(dates)
```

## Arguments

- dates:

  the `dates` argument as the caller wrote it

## Value

a sorted, deduplicated `Date` vector

## Why invalid dates are an error

`"20150230"` parses to `NA` rather than to a date. Dropping it would
fetch fewer days than were asked for and say nothing, leaving the gap to
be found much later as a missing row. The offending values are named
instead.
