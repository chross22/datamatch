# Access HYCOM output from the GOFS 3.1 reanalysis

Reads HYCOM over OPeNDAP and returns it as an `sf` point object with one
row per grid cell and time step — the same shape
[`accessCopernicus()`](https://camilleross.org/datamatch/reference/accessCopernicus.md),
[`accessCCMP()`](https://camilleross.org/datamatch/reference/accessCCMP.md),
[`accessERDDAP()`](https://camilleross.org/datamatch/reference/accessERDDAP.md)
and
[`accessFVCOM()`](https://camilleross.org/datamatch/reference/accessFVCOM.md)
return, so
[`matchData()`](https://camilleross.org/datamatch/reference/matchData.md)
joins it unchanged.

## Usage

``` r
accessHYCOM(
  vars,
  years = NULL,
  months = NULL,
  bounding_box,
  dates = NULL,
  frequency = c("daily", "3hourly"),
  hour = 12L,
  archive = "GLBv53X",
  overwrite = FALSE
)
```

## Arguments

- vars:

  variables to read, from
  [`hycom_variables()`](https://camilleross.org/datamatch/reference/hycom_variables.md)

- years:

  years to read. Required unless `dates` is given.

- months:

  months to read. Required unless `dates` is given.

- bounding_box:

  named list with `xmin`, `xmax`, `ymin`, `ymax`, or an `sf`/`sfc`
  object to take the bounding box of. Longitudes are negative west, as
  elsewhere in this package.

- dates:

  the exact dates to read, as `YYYYMMDD` strings, `YYYY-MM-DD` strings,
  or `Date` objects

- frequency:

  `"daily"` (the default) for one snapshot per day, or `"3hourly"` for
  every step. Neither is a mean; see the Three-hourly section.

- hour:

  which UTC hour to take when `frequency = "daily"`. Must be a multiple
  of 3, since that is the model's step.

- archive:

  which archive to read, from
  [`hycom_archives()`](https://camilleross.org/datamatch/reference/hycom_archives.md),
  or `"continuous"` to read across them. The default is the 1994–2015
  reanalysis; later years live in the operational archives, which
  [`hycom_covering()`](https://camilleross.org/datamatch/reference/hycom_covering.md)
  will name for a given date. `"continuous"` picks an archive per day —
  the reanalysis wherever it reaches, the earliest-starting operational
  archive after that — and warns once, naming the day the run changes.
  Every row records the archive it came from; see
  [`source_of()`](https://camilleross.org/datamatch/reference/source_of.md).

- overwrite:

  re-read time steps already cached

## Value

one row per grid cell per time step, with `YEAR`, `MONTH` and `DAY`, an
`HOUR` column when `frequency = "3hourly"`, and a column per requested
variable

## Why reach for it

Two reasons, both about what the Copernicus reanalysis lacks. HYCOM
publishes **bottom salinity and bottom temperature as fields**, where
GLORYS12V1 has only bottom temperature and `BOTS` has to be derived from
the full depth column. And it is an **independent model**, so agreement
between it and Copernicus is evidence about a result in a way that
either one alone is not.

A covariate taken from HYCOM is **not interchangeable** with the
same-named covariate from Copernicus or FVCOM, though this returns it in
a column of the same name. Three different models. Say which you used.

## Three-hourly, and no monthly mean

HYCOM publishes instantaneous fields every three hours. There is no
monthly or daily mean to fetch, so this does not offer one:

- `frequency = "daily"` (the default) takes **one snapshot per day**, at
  the hour given by `hour`. It is an instant, not a daily mean, and a
  12:00 UTC snapshot of a tidal shelf sea is not the day's average.

- `frequency = "3hourly"` returns every step, with an `HOUR` column.

A real mean is then
[`upscale_time()`](https://camilleross.org/datamatch/reference/upscale_time.md)'s
job, which keeps the aggregation visible and the choice of summary
yours:

    steps <- accessHYCOM(vars = "SST", frequency = "3hourly", years = 2010,
                         months = 6, bounding_box = bb)
    daily <- upscale_time(steps, to = "day")     # a genuine daily mean

Fetching a month of three-hourly data is 248 downloads over a slow
protocol. Prefer `dates` and a small box unless the whole series is
genuinely wanted.

## Reaching past 2015

The default archive is the **reanalysis**, `GLBv53X`, which is one
internally consistent run over 1994–2015. HYCOM continues to the
present, but as a chain of shorter **operational** experiments — the
model as it was running at the time.
[`hycom_archives()`](https://camilleross.org/datamatch/reference/hycom_archives.md)
lists them and
[`hycom_covering()`](https://camilleross.org/datamatch/reference/hycom_covering.md)
says which span a given date:

    hycom_covering("2019-06-15")
    #> [1] "GLBv930" "GLBy930"

    recent <- accessHYCOM(vars = "BOTS", dates = "2019-06-15",
                          bounding_box = bb, archive = "GLBy930")

## Reading across archives

`archive = "continuous"` spans the whole 1994–2024 record in one call,
rather than one archive per call. It is opt-in because the seam is real:
crossing out of `GLBv53X` leaves an internally consistent reanalysis for
the model as it was running at the time, so a step in a series across
that date can be the change of run rather than a change in the ocean.
The call warns once, naming the day it happens.

The grids mostly agree — `GLBv0.08` and `GLBy0.08` hold the same 126
latitudes between 40 and 45 °N — so on a mid-latitude shelf the cells
line up across the seam. It is the run that changes, not the geometry.

Provenance is recorded per row rather than per fetch, so a value from
the operational model never claims to be the reanalysis.
[`matchData()`](https://camilleross.org/datamatch/reference/matchData.md)
carries that into `<var>_source`.

    env <- accessHYCOM(vars = "BOTS", years = 2014:2019, months = 6,
                       bounding_box = bb, archive = "continuous")
    source_of(env)
    #> [1] "hycom:GLBv53X+hycom:GLBv563+hycom:GLBv930"

One archive is read per call otherwise, and a request falling outside
the one named is told which others hold it rather than being stitched to
them silently. The archives overlap, so where two cover a date there is
a real choice between the more consistent run and the more recent one,
and crossing from the reanalysis into an operational run is a
discontinuity in how the values were made. The grids themselves agree
through the middle latitudes, so on a shelf the cells line up across the
seam even though the runs do not — see
[`hycom_archives()`](https://camilleross.org/datamatch/reference/hycom_archives.md).

## One dataset per year, sometimes

The reanalysis is published one dataset per year, so a request spanning
years opens one connection per year. The operational archives are each a
single aggregation and open once.

## See also

[`hycom_variables()`](https://camilleross.org/datamatch/reference/hycom_variables.md)
for what can be read,
[`accessCopernicus()`](https://camilleross.org/datamatch/reference/accessCopernicus.md),
[`accessFVCOM()`](https://camilleross.org/datamatch/reference/accessFVCOM.md),
[`accessCCMP()`](https://camilleross.org/datamatch/reference/accessCCMP.md)
and
[`accessERDDAP()`](https://camilleross.org/datamatch/reference/accessERDDAP.md)
for the other sources,
[`matchData()`](https://camilleross.org/datamatch/reference/matchData.md)
for joining any of them

## Examples

``` r
if (FALSE) { # \dontrun{
bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

# Bottom salinity, which the Copernicus reanalysis cannot serve directly
bottom <- accessHYCOM(vars = c("BOTT", "BOTS"), years = 2010, months = 1:12,
                      bounding_box = bb)

matched <- matchData(observations, bottom)

# Every three-hourly step, then a genuine daily mean
steps <- accessHYCOM(vars = "SST", frequency = "3hourly",
                     dates = "2010-06-15", bounding_box = bb)
daily <- upscale_time(steps, to = "day")
} # }
```
