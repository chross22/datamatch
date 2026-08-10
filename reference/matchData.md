# Match one set of points to another in space and time

Joins each row of `dat` to the nearest feature of `source` within the
same time period, and returns `dat` with `source`'s columns added.

## Usage

``` r
matchData(
  dat,
  source,
  temporal_resolution = c("auto", "day", "month", "year"),
  speciesDat = NULL,
  envDat = NULL
)
```

## Arguments

- dat:

  the points to add columns to: observations, stations, tag positions,
  anything with coordinates and time. Needs year and month columns, plus
  a day column when matching at daily resolution. Columns whose names
  begin with those words are recognised, so `Year` or `obs_month` work.

- source:

  the points to take values from, typically a grid from
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md).
  Must carry `YEAR`/`MONTH`/`DAY`.

- temporal_resolution:

  one of `"auto"` (default), `"day"`, `"month"`, or `"year"`. `"auto"`
  uses the step
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
  recorded on `source`, or infers it from `source`'s time steps.

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

## Matching in time

The time period is `source`'s own resolution: daily data matches on
year/month/day, monthly data (Copernicus `...P1M-m` means, say) on
year/month, and annual data on year alone.

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
