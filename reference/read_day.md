# Read one day's cached file into a data frame

Reads stay in the calling session. They are local file reads, and
running them in workers would mean serialising every day's data frame
back over a socket — for a large bounding box that costs more than the
read itself.

## Usage

``` r
read_day(item, vars)
```

## Arguments

- item:

  one work item, as built by
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)

- vars:

  variable codes, in the order they were requested

## Value

a data frame of one grid, with `YEAR`, `MONTH` and `DAY`

## The calendar warning

Some Copernicus files declare their time calendar as `Gregorian`, which
is not one of the spellings the CF conventions list, so terra warns and
assumes the standard calendar. That assumption is correct — `Gregorian`
is the standard calendar, spelled with a capital — and the warning says
nothing a caller can act on. One per file makes fifty on a fifty-day
fetch, which buries the warnings that do matter.

Only that one message is muffled, matched on its text. Every other
warning from the read is left alone, since a file that is genuinely
unreadable should still say so.
