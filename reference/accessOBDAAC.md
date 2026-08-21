# Access NASA OB.DAAC ocean colour and sea surface temperature

Downloads Level-3 mapped satellite fields from NASA's Ocean Biology DAAC
and returns them as an `sf` point object with one row per grid cell and
time step — the same shape
[`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md),
[`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md),
[`accessHYCOM()`](https://chross22.github.io/datamatch/reference/accessHYCOM.md),
[`accessCCMP()`](https://chross22.github.io/datamatch/reference/accessCCMP.md),
[`accessERDDAP()`](https://chross22.github.io/datamatch/reference/accessERDDAP.md)
and
[`accessCEFI()`](https://chross22.github.io/datamatch/reference/accessCEFI.md)
return, so
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
joins it unchanged.

## Usage

``` r
accessOBDAAC(
  vars,
  years = NULL,
  months = NULL,
  bounding_box,
  dates = NULL,
  frequency = c("daily", "monthly"),
  sensor = "MODISA",
  resolution = "4km",
  overwrite = FALSE
)
```

## Arguments

- vars:

  variables to read, from
  [`obdaac_variables()`](https://chross22.github.io/datamatch/reference/obdaac_variables.md)

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

  `"daily"` (the default) or `"monthly"`

- sensor:

  which mission to read, from
  [`obdaac_sensors()`](https://chross22.github.io/datamatch/reference/obdaac_sensors.md)

- resolution:

  `"4km"` (the default) or `"9km"`. At 9 km a global file is about a
  third the size, which is the difference worth knowing for a long
  record.

- overwrite:

  re-read time steps already cached

## Value

one row per grid cell per time step, with `YEAR`, `MONTH`, `DAY` and a
column per requested variable

## It needs an Earthdata Login

This is the only source in this package that will not work until you
have created an account, and the failure without one is misleading: NASA
answers an unauthenticated request with HTTP 200 and the login page.
Register once at <https://urs.earthdata.nasa.gov/users/new>, generate an
appkey at <https://oceandata.sci.gsfc.nasa.gov/appkey/>, and put it in
`~/.Renviron`:

    EARTHDATA_APPKEY=your-key-here

A `~/.netrc` entry for `urs.earthdata.nasa.gov` works too. See
[`obdaac_credentials()`](https://chross22.github.io/datamatch/reference/obdaac_credentials.md)
for both routes and where they are looked for. A download that comes
back as the login page is refused by name rather than being written to
disk as a broken file.

## It downloads the whole globe

OB.DAAC serves Level-3 mapped fields as global static files with no
server-side subsetting, so **one variable for one day is one global
file** however small the bounding box, and the subset is taken locally.
At 4 km a daily chlorophyll field is about 15 MB and at 9 km about 5, so
`resolution = "9km"` is three times cheaper for a study whose grid is
coarser than 4 km anyway.

The exact total is reported before anything is transferred, because the
file search returns each file's size, and the extracted subsets are
cached, so a long record is paid for once.

## Why there is no eight-day option

OB.DAAC publishes eight-day composites and they are the obvious answer
to cloud gaps, but this package cannot join them honestly.
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
joins on an hour, a day, a month or a year, and an eight-day bin is none
of those: stamped as a day it would demand an observation fall on the
bin's first date, and nearly every row would go unmatched. Use
`"monthly"`, which is a step the join understands, or
[`fill_satellite_gaps()`](https://chross22.github.io/datamatch/reference/fill_satellite_gaps.md)
on the daily field, which records what it filled.

## Which sensor, and why it matters

`sensor` defaults to `"MODISA"`, which has the longest current record
with both colour and SST. It is a choice you should make deliberately
rather than inherit — see the section of
[`obdaac_sensors()`](https://chross22.github.io/datamatch/reference/obdaac_sensors.md)
on why the sensors are not interchangeable — and
[`source_of()`](https://chross22.github.io/datamatch/reference/source_of.md)
records which one answered.

## See also

[`obdaac_sensors()`](https://chross22.github.io/datamatch/reference/obdaac_sensors.md),
[`obdaac_variables()`](https://chross22.github.io/datamatch/reference/obdaac_variables.md),
[`accessERDDAP()`](https://chross22.github.io/datamatch/reference/accessERDDAP.md)
for satellite fields that need no account,
[`fill_satellite_gaps()`](https://chross22.github.io/datamatch/reference/fill_satellite_gaps.md)
for cloud gaps

## Examples

``` r
if (FALSE) { # \dontrun{
bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

# The long record: SeaWiFS chlorophyll from the late 1990s
early <- accessOBDAAC(vars = "CHL", years = 1998, months = 1:12,
                      bounding_box = bb, frequency = "monthly",
                      sensor = "SEAWIFS")

# Light and clarity alongside chlorophyll, from Aqua
light <- accessOBDAAC(vars = c("CHL", "PAR", "KD490"),
                      dates = unique(observations$date), bounding_box = bb)

matched <- matchData(observations, light)
} # }
```
