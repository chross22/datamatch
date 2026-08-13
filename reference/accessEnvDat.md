# Access environmental data from Copernicus Marine Service

Downloads a Copernicus dataset over a bounding box and time range, and
returns it as an `sf` point object with one row per grid cell and time
step.

## Usage

``` r
accessEnvDat(
  product_id = NULL,
  dataset_id = NULL,
  vars,
  years = NULL,
  months = NULL,
  bounding_box,
  depth = c(0, 1),
  overwrite = FALSE,
  n_workers = 4,
  frequency = c("monthly", "daily", "hourly"),
  dates = NULL,
  mode = c("reanalysis", "forecast")
)
```

## Arguments

- product_id:

  product identification string from the Copernicus Marine Data Store.
  Optional when `vars` are catalog names.

- dataset_id:

  dataset identification string from the Copernicus Marine Data Store.
  Optional when `vars` are catalog names.

- vars:

  variables to access: names from
  [`variable_dictionary()`](https://chross22.github.io/datamatch/reference/variable_dictionary.md),
  raw Copernicus variable codes, or a mixture

- years:

  years of data to access. Required unless `dates` is given, which names
  the time steps itself.

- months:

  months of data to access. Required unless `dates` is given.

- bounding_box:

  named list of spatial coordinates of bounding box

- depth:

  depth range to access (in meters). Widened to the whole water column
  for a derived variable such as `BOTS`, which needs it, unless given
  explicitly.

- overwrite:

  whether or not to overwrite the data if it exists locally

- n_workers:

  how many days to download at once. See the Downloading in parallel
  section. Use `n_workers = 1` to download one day at a time.

- frequency:

  `"monthly"` (the default) for monthly means, `"daily"` for daily ones,
  or `"hourly"`, which only the wind variables have. See the Monthly and
  daily data and Hourly wind sections. Ignored when `dataset_id` is
  given, since the dataset itself fixes the step.

- dates:

  the exact dates to fetch, as `YYYYMMDD` strings, `YYYY-MM-DD` strings,
  or `Date` objects. `NULL`, the default, fetches every day of the
  requested months instead. Passing `dates` implies
  `frequency = "daily"` and replaces `years` and `months`, which must
  then not be given. See the Fetching specific dates section.

- mode:

  `"reanalysis"` (the default) for the multi-year hindcast, or
  `"forecast"` for the analysis-and-forecast products, which run to
  about ten days ahead. See
  [`forecast_variables()`](https://chross22.github.io/datamatch/reference/forecast_variables.md)
  for which variables have a forecast equivalent and how the identifiers
  differ.

## Value

sf object containing requested environmental data from Copernicus Marine
Service, with `YEAR`/`MONTH`/`DAY` columns, an `HOUR` column when the
fetch was hourly, and a `<var>_depth` column for a derived bottom
variable

## Requesting variables by name

`vars` accepts the short names in
[`variable_dictionary()`](https://chross22.github.io/datamatch/reference/variable_dictionary.md)
— `"SST"`, `"CHL"`, `"MLD"` — as well as raw Copernicus codes.
Copernicus codes are terse and easy to misremember (`thetao` for
temperature, `mlotst` for mixed layer depth, `zos` for sea surface
height), and getting one wrong produces a failed download rather than an
obvious mistake.

Names carry through to the result, so a request for `"SST"` returns a
column called `SST` rather than `thetao`.

## Citing the data

The products carry their own DOIs and Copernicus asks that they be cited
with an access date.
[`variable_dataset()`](https://chross22.github.io/datamatch/reference/variable_dataset.md)
says which product a variable came from, and
[`product_url()`](https://chross22.github.io/datamatch/reference/product_url.md)
links to its page. The README's References section lists every DOI.

Because the catalog knows which product and dataset holds each variable,
**`product_id` and `dataset_id` can be omitted** when every requested
variable is in it:

    accessEnvDat(
      vars = c("SST", "SSS", "MLD"),
      years = 2003:2017, months = 1:12,
      bounding_box = list(xmin = -76, xmax = -65, ymin = 35, ymax = 45)
    )

Variables from different datasets cannot be fetched in one request, and
mixing them is refused before anything is downloaded rather than failing
obscurely at the API. Anything outside the catalog is passed through as
a code, with a warning — Copernicus serves far more than the catalog
covers, but a typo looks identical to a real code.

## Monthly and daily data

`frequency = "monthly"` (the default) fetches monthly means: one field
per month, and one row per grid cell per month. `frequency = "daily"`
fetches the daily datasets instead, expanding each requested month into
its days.

    accessEnvDat(vars = c("SST", "MLD"), frequency = "daily",
                 years = 2015, months = 4:6,
                 bounding_box = list(xmin = -70, xmax = -65, ymin = 42, ymax = 45))

Note what that costs: three months of daily data is 91 downloads rather
than 3, and 91 grids rather than 3 in memory. A decade of daily data
over a large box will not fit in a laptop's RAM as an `sf` object, and
is better fetched a season at a time.

## Fetching specific dates

`dates` is the other way to keep that in hand. It names the exact dates
to fetch, so only the days that matter are downloaded:

    accessEnvDat(vars = "SST", dates = c("20150402", "20150517", "20150623"),
                 bounding_box = bb)

This is the argument to use when matching daily data to observations.
Survey dates differ from month to month, and a rule such as "the 1st and
15th" does not describe them. Take the dates from the observations
themselves:

    accessEnvDat(vars = "SST", dates = unique(observations$date), bounding_box = bb)

`YYYYMMDD` strings, `YYYY-MM-DD` strings, and `Date` objects are all
accepted, and may be mixed. Dates are sorted and deduplicated, so the
result comes back in date order however the argument was written, and a
date named twice is fetched once.

`dates` says which time steps to fetch, so `years` and `months` are
neither needed nor accepted alongside it. Passing it implies
`frequency = "daily"`, since naming a date means nothing to a monthly
mean, and passing it with an explicit `frequency = "monthly"` is a
contradiction rather than something to resolve by guessing.

A date that does not exist — `"20150230"` — is an error naming it,
rather than a silently dropped request.

Fetching dates is not the same as averaging a month. Three dates are a
sample of the month, with whatever weather fell on them; a monthly mean
is the month. Which you want depends on whether the observations being
matched are themselves instants or aggregates.

Not every variable has a daily equivalent. `PH`, `PP`, `DIATO` and
`DINO` are published as monthly composites only, and asking for them
daily is refused before anything is downloaded. Daily `CHL` comes from
the gap-free interpolated ocean colour dataset rather than the monthly
composite, which `accessEnvDat()` reports when it happens — see
[`copernicus_variables()`](https://chross22.github.io/datamatch/reference/copernicus_variables.md).

## Hourly wind

`frequency = "hourly"` fetches the hourly wind product. It is the only
step below daily this package reaches, and only the wind variables have
one — the ocean reanalyses are daily at finest.

The result carries an `HOUR` column alongside `YEAR`/`MONTH`/`DAY`, so a
day is 24 rows per cell rather than one, and
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
joins on the hour. Observations must then carry an hour of their own, on
UTC.

    wind <- accessEnvDat(vars = c("UWND", "VWND"), frequency = "hourly",
                         dates = unique(observations$date), bounding_box = bb)

A day is one download whichever step is used, so hourly costs no more
requests than daily — but 24 times the rows, which is what makes a large
box expensive.

**There is no daily wind.** Copernicus publishes this wind hourly and
monthly and nothing between, so `frequency = "daily"` is refused for it.
Aggregate the hourly field instead, which also leaves the choice of
summary with you:

    daily_wind <- upscale_time(wind, to = "day")               # the day's mean
    peak       <- upscale_time(wind, to = "day", method = "max")  # its strongest hour

`WSPD` and `TAU` are magnitudes the hourly product does not carry, so
they are monthly only.

## Bottom salinity

`BOTS` is the one variable that is computed rather than downloaded.
GLORYS12V1 publishes temperature at the sea floor but no salinity
counterpart, so in reanalysis mode the full salinity column is fetched
and the deepest wet level in each cell kept. The depth that value came
from is returned alongside it, as `BOTS_depth`, rather than left to be
assumed.

Two consequences follow, and both are said out loud when it happens:

- **It must be fetched on its own.** The whole depth column is a
  different request from the single level a surface variable wants, so
  mixing `BOTS` with `SST` is an error rather than a quiet second
  download.

- **It costs far more than a surface variable.** Roughly fifty levels
  are downloaded over the same box to keep one, so `depth` is widened to
  the full column unless you set it yourself.

In forecast mode none of this applies: the analysis-and-forecast product
publishes `sob` outright, so `BOTS` is an ordinary variable there,
fetches alongside `BOTT`, and returns no `BOTS_depth`.

Passing `dataset_id` explicitly overrides all of this: that dataset's
own frequency decides, since a Copernicus dataset is published at one
step.

## Downloading in parallel

Days already in the cache are read directly. Only the missing ones are
downloaded, and those go out `n_workers` at a time through a PSOCK
cluster, since a Copernicus subset request spends nearly all its time
waiting on the API rather than on this machine.

The default of 4 is deliberately modest. The limit is the service and
the network, not local cores, and a large `n_workers` mostly earns rate
limiting. Raise it toward 8 for many small requests; use `n_workers = 1`
to download serially.

The cluster is PSOCK rather than fork-based
([`parallel::mclapply()`](https://rdrr.io/r/parallel/mclapply.html)):
GDAL, which `terra` and `sf` use internally, is not fork-safe, and
forking after it has initialised can corrupt state in the children.
PSOCK workers are fresh R sessions, which avoids that.

Reading and converting the downloaded files stays in this session. Those
are local file reads, and returning each day's data frame from a worker
would cost more in serialisation than the read saves.

A day that fails does not abort the others. Every day is attempted, the
successful ones stay in the cache, and the error names each day that
failed — so re-running the same call retries only those.
