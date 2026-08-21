# Access satellite data through ERDDAP

Downloads a subset of an ERDDAP gridded dataset and returns it as an
`sf` point object with one row per grid cell and time step — the same
shape the other access functions return, so
[`matchData()`](https://camilleross.org/datamatch/reference/matchData.md)
joins it unchanged.

## Usage

``` r
accessERDDAP(
  vars,
  years = NULL,
  months = NULL,
  bounding_box,
  dates = NULL,
  dataset = "MUR",
  overwrite = FALSE
)
```

## Arguments

- vars:

  variables to read, from the dataset's own catalog. `MUR` offers `SST`,
  `SST_ERROR` and `ICE`; the VIIRS entries offer `CHL`.

- years:

  years to read. Required unless `dates` is given.

- months:

  months to read. Required unless `dates` is given.

- bounding_box:

  named list with `xmin`, `xmax`, `ymin`, `ymax`, or an `sf`/`sfc`
  object. Longitudes negative west, as elsewhere.

- dates:

  the exact dates to read, as `YYYYMMDD` strings, `YYYY-MM-DD` strings,
  or `Date` objects

- dataset:

  which dataset to read: a name from
  [`erddap_datasets()`](https://camilleross.org/datamatch/reference/erddap_datasets.md),
  or a spec from
  [`erddap_dataset()`](https://camilleross.org/datamatch/reference/erddap_dataset.md)
  describing any other

- overwrite:

  re-read days already cached

## Value

one row per grid cell per day, with `YEAR`, `MONTH`, `DAY` and a column
per requested variable

## Why this one needs no account

MUR and the VIIRS products are also at PO.DAAC, where they need an
Earthdata login. ERDDAP serves them openly and subsets server-side, so a
bounding box costs a small download rather than a global file. That is
the whole reason this route was chosen: no credentials for this package
to handle, and none for you to configure.

## Satellite SST is not model SST

`MUR` measures the **foundation** temperature — below the daily warming
layer — where a model's `SST` is its topmost level, and satellite
chlorophyll is an optical retrieval where a model's is a state variable.
Both land in columns called `SST` and `CHL`, which is what makes them
drop into an existing pipeline, and is exactly why
[`matchData()`](https://camilleross.org/datamatch/reference/matchData.md)
records `<var>_source`.

Two further cautions specific to satellites. **MUR is gap-free by
construction** — it is an analysis, so cloud is interpolated over rather
than left as `NA`, and `SST_ERROR` is where the uncertainty of that
shows up; fetch it alongside if the interpolation matters. And
**`VIIRSCHL` is DINEOF gap-filled**, so its holes are filled too;
`VIIRSCHL2018` is the raw retrieval and is gappy under cloud, which
[`fill_satellite_gaps()`](https://camilleross.org/datamatch/reference/fill_satellite_gaps.md)
is for.

## See also

[`erddap_datasets()`](https://camilleross.org/datamatch/reference/erddap_datasets.md)
for what ships,
[`erddap_dataset()`](https://camilleross.org/datamatch/reference/erddap_dataset.md)
for anything else on an ERDDAP server

## Examples

``` r
if (FALSE) { # \dontrun{
bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

# MUR SST at 0.01 degrees - far finer than any model here
sst <- accessERDDAP(vars = c("SST", "SST_ERROR"),
                    dates = unique(observations$date), bounding_box = bb)

matched <- matchData(observations, sst)

# VIIRS chlorophyll
chl <- accessERDDAP(vars = "CHL", years = 2022, months = 6,
                    bounding_box = bb, dataset = "VIIRSCHL")
} # }
```
