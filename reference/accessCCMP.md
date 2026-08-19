# Access CCMP ocean surface winds

Downloads the CCMP wind analysis from Remote Sensing Systems and returns
it as an `sf` point object with one row per grid cell and time step —
the same shape
[`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md),
[`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md),
[`accessHYCOM()`](https://chross22.github.io/datamatch/reference/accessHYCOM.md)
and
[`accessERDDAP()`](https://chross22.github.io/datamatch/reference/accessERDDAP.md)
return, so
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
joins it unchanged.

## Usage

``` r
accessCCMP(
  vars,
  years = NULL,
  months = NULL,
  bounding_box,
  dates = NULL,
  frequency = c("daily", "6hourly"),
  hour = 12L,
  version = "v03.1",
  overwrite = FALSE
)
```

## Arguments

- vars:

  variables to read, from
  [`ccmp_variables()`](https://chross22.github.io/datamatch/reference/ccmp_variables.md)

- years:

  years to read. Required unless `dates` is given.

- months:

  months to read. Required unless `dates` is given.

- bounding_box:

  named list with `xmin`, `xmax`, `ymin`, `ymax`, or an `sf`/`sfc`
  object. Longitudes negative west.

- dates:

  the exact dates to read, as `YYYYMMDD` strings, `YYYY-MM-DD` strings,
  or `Date` objects

- frequency:

  `"daily"` (the default) for one snapshot per day, or `"6hourly"` for
  all four steps. Neither is a mean.

- hour:

  which UTC hour to take when `frequency = "daily"`. Must be 0, 6, 12 or
  18.

- version:

  which CCMP version to read, from
  [`ccmp_versions()`](https://chross22.github.io/datamatch/reference/ccmp_versions.md)

- overwrite:

  re-read days already cached

## Value

one row per grid cell per time step, with `YEAR`, `MONTH`, `DAY`, an
`HOUR` column when `frequency = "6hourly"`, and a column per requested
variable

## Why reach for it, and why not

CCMP is the longest consistent surface wind record available here. It
runs from **January 1993 to within days of the present**, six-hourly
throughout, which is both longer and finer in time than the Copernicus
L4 wind — that is monthly from mid-1994, or hourly only from 2007, with
nothing daily in between.

Against that: **CCMP carries no wind stress.** The Copernicus product
does, and stress rather than speed is what drives mixing and Ekman
pumping. Stress cannot be recovered from these winds without choosing a
drag coefficient, which is a modelling decision rather than a unit
conversion. Where stress is the covariate you want, use the Copernicus
wind.

The two are different analyses of the same quantity, so a wind from CCMP
is **not interchangeable** with one from Copernicus even though both
arrive in a `UWND` column. Say which you used.

## It downloads the whole globe

RSS publishes CCMP as static files with no OPeNDAP endpoint, so there is
no way to ask for a region. **A day is one 33 MB global file** however
small the bounding box, and the subset is taken locally. A year is
therefore about 12 GB of transfer to keep a few megabytes of it.

The extracted subset is cached, so this is paid once per day of data. A
request for more than 30 days says what it is about to download before
starting.

## Six-hourly, and no mean to fetch

CCMP is an analysis at 00, 06, 12 and 18 UTC. There is no daily or
monthly mean in the archive, so none is invented:

- `frequency = "daily"` (the default) takes one **snapshot**, at `hour`.

- `frequency = "6hourly"` returns all four steps, with an `HOUR` column.

A real mean is
[`upscale_time()`](https://chross22.github.io/datamatch/reference/upscale_time.md)'s
job, which keeps it visible:

    steps <- accessCCMP(vars = c("UWND", "VWND"), frequency = "6hourly",
                        dates = "2010-06-15", bounding_box = bb)
    daily <- upscale_time(steps, to = "day")

Note that a mean of `UWND` and `VWND` is not a mean `WSPD`. Averaging
the components and taking the magnitude gives the net displacement of
air; averaging the speed gives how hard it blew. On a day the wind
reversed, the first is near zero and the second is not.

## Longitude convention

CCMP is stored on a 0-360 grid, alone among the sources here.
`bounding_box` is given negative west as everywhere else in this
package, converted on the way in, and the returned coordinates are
negative west too — so the result overlays the other sources without
adjustment.

## See also

[`ccmp_variables()`](https://chross22.github.io/datamatch/reference/ccmp_variables.md),
[`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
for the Copernicus wind, which carries stress

## Examples

``` r
if (FALSE) { # \dontrun{
bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

wind <- accessCCMP(vars = c("UWND", "VWND", "WSPD"),
                   dates = unique(observations$date), bounding_box = bb)

matched <- matchData(observations, wind)
} # }
```
