# Match one set of points to another in space and time

Joins each row of `dat` to the nearest feature of `source` within the
same time period, and returns `dat` with `source`'s columns added.

## Usage

``` r
matchData(
  dat,
  source,
  temporal_resolution = c("auto", "hour", "day", "month", "year"),
  record_source = TRUE,
  speciesDat = NULL,
  envDat = NULL
)
```

## Arguments

- dat:

  the points to add columns to: observations, stations, tag positions,
  anything with coordinates and time. Needs year and month columns, plus
  a day column when matching at daily resolution and an hour column at
  hourly. Columns whose names *begin* with those words are recognised,
  whatever their case, so `Year` and `month_utc` work but `obs_month`
  does not — rename it, or pass it as `MONTH`. Day-of-year names
  (`yearday`, `dayofyear`, `jday`, `doy` and the like) are never used,
  even though some of them do begin with `year` or `day`: they hold an
  ordinal day rather than a year or a day of the month. An unrecognised
  name is named in the error, so nothing has to be guessed at.

- source:

  the points to take values from, typically a grid from
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md).
  Must carry `YEAR`/`MONTH`/`DAY`, and `HOUR` as well when matching
  hourly.

- temporal_resolution:

  one of `"auto"` (default), `"hour"`, `"day"`, `"month"`, or `"year"`.
  `"auto"` uses the step
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
  recorded on `source`, or infers it from `source`'s time steps.

- record_source:

  add a `<var>_source` column for each column joined, naming which
  source and archive produced it. On by default, and only has an effect
  when `source` carries the stamp an access function leaves — see
  [`source_of()`](https://chross22.github.io/datamatch/reference/source_of.md).
  Set `FALSE` for the narrower table.

- speciesDat, envDat:

  deprecated names for `dat` and `source`. Still accepted, with a
  warning.

## Value

`dat` with `source`'s columns joined on, one row per input row, plus
`LON`/`LAT` coordinate columns.

## Details

Neither side has to be species observations or environmental data. It is
a spatiotemporal nearest-feature join between two `sf` point objects
that carry `YEAR`/`MONTH`/`DAY` columns, so it works equally for
stations against a covariate grid, tag positions against a model field,
moorings against satellite retrievals, or one gridded product against
another.

## Which geometries can be matched

`dat` may hold **points, lines or polygons** — survey stations, tow
tracks, transects, statistical areas. The join is nearest-feature
against the whole geometry, so a tow matches the nearest grid cell to
the track rather than to any one end of it, and an area matches the
nearest cell to the area.

`LON`/`LAT` are then a *representative point* rather than the geometry:
for a line or polygon they come from
[`sf::st_point_on_surface()`](https://r-spatial.github.io/sf/reference/geos_unary.html),
which is guaranteed to lie on the feature where a centroid need not. The
geometry column itself is untouched, so nothing is lost — but do not
read `LON`/`LAT` as the position of an area.

A caution about extended geometries: a long tow or a large area may lie
nearer one cell while spanning several, and nearest-feature returns
exactly one. Where a track crosses a front, consider splitting it, or
matching its vertices as points and summarising afterwards.

`source` should be points, as every access function returns.

## Matching in time

The time period is `source`'s own resolution: hourly data matches on
year/month/day/hour, daily data on year/month/day, monthly data
(Copernicus `...P1M-m` means, say) on year/month, and annual data on
year alone.

Matching hourly needs `dat` to say which hour each row belongs to, in a
column recognised the same way as the others — `HOUR`, `hour`,
`hour_utc`, but not `obs_hour`, which does not begin with the word. On
UTC, as the environmental data is: an observation timestamped in local
time will match the wrong hour, and nothing in the join can detect that.

That matters because a day-exact join against monthly data matches
nothing. A monthly product carries one time step per month, while
observations fall on arbitrary days. `temporal_resolution` overrides the
inference when the data cannot speak for itself.

## What is preserved

One row out per row of `dat`, in the same order, whatever happens. A
period `source` does not cover gives `NA` for its columns and a warning
naming the periods, rather than dropping those rows — a silent change in
row count is a worse outcome than a visible gap.

`dat` keeps its own columns. One of `source`'s that collides with a name
already in `dat` is suffixed `.matched`, so nothing of `dat`'s is
overwritten or renamed.

## Which source a column came from

The access functions share variable names on purpose, so `SST` from
Copernicus, FVCOM and HYCOM all arrive in a column called `SST` and
everything downstream works unchanged. The cost is that a table with
several sources chained onto it has no record of which produced what.

So each joined column gets a companion `<var>_source` naming the source
and archive — `"hycom:GLBv53X"`, `"fvcom:GOM3"` — in the same spirit as
the `<var>_source` column
[`fill_satellite_gaps()`](https://chross22.github.io/datamatch/reference/fill_satellite_gaps.md)
writes. Pass `record_source = FALSE` to omit them.

These are provenance rather than data:
[`covariate_columns()`](https://chross22.github.io/datamatch/reference/covariate_columns.md)
excludes them, so they are not aggregated, regridded or plotted as
though they were measurements.

## See also

[`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
for the usual `source`,
[`attach_bathymetry()`](https://chross22.github.io/datamatch/reference/attach_bathymetry.md)
and
[`attach_climate_index()`](https://chross22.github.io/datamatch/reference/attach_climate_index.md)
for covariates that are not matched this way

## Examples

``` r
if (FALSE) { # \dontrun{
env <- accessEnvDat(vars = "SST", years = 2010, months = 1:12, bounding_box = bb)

matched <- matchData(observations, env)

# Chains, so several sources land on one table
matched <- matchData(matched, chlorophyll)
} # }
```
