# Read one day's cached hourly file into a data frame

An hourly download covers a whole day, so its file holds 24 fields per
variable rather than one. Each becomes its own block of rows, stamped
with the hour it belongs to, so the result is one row per grid cell per
hour.

## Usage

``` r
read_day_hourly(item, vars)
```

## Arguments

- item:

  one work item, as built by
  [`accessCopernicus()`](https://camilleross.org/datamatch/reference/accessCopernicus.md)

- vars:

  variable codes, in the order they were requested

## Value

a data frame of 24 grids, with `YEAR`, `MONTH`, `DAY` and `HOUR`

## Which hour a layer belongs to

Taken from the file's own time axis rather than from layer order. The
layers arrive grouped by variable — all 24 hours of `eastward_wind`,
then all 24 of `northward_wind` — so position within the file says
nothing about the hour on its own, and a variable that happened to be
served at fewer steps would shift every one that followed it.

Times are formatted in UTC explicitly. Copernicus publishes on UTC and
terra tags the axis as such, but
[`format()`](https://rdrr.io/r/base/format.html) would otherwise render
in the session's local zone, which silently relabels every hour by the
local offset and moves some of them onto the neighbouring day.
