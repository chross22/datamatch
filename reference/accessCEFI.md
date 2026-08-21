# Access CEFI regional MOM6 output

Reads the NOAA CEFI regional ocean model over OPeNDAP and returns it as
an `sf` point object with one row per grid cell and time step — the same
shape
[`accessCopernicus()`](https://camilleross.org/datamatch/reference/accessCopernicus.md),
[`accessFVCOM()`](https://camilleross.org/datamatch/reference/accessFVCOM.md),
[`accessHYCOM()`](https://camilleross.org/datamatch/reference/accessHYCOM.md),
[`accessCCMP()`](https://camilleross.org/datamatch/reference/accessCCMP.md)
and
[`accessERDDAP()`](https://camilleross.org/datamatch/reference/accessERDDAP.md)
return, so
[`matchData()`](https://camilleross.org/datamatch/reference/matchData.md)
joins it unchanged.

## Usage

``` r
accessCEFI(
  vars,
  years = NULL,
  months = NULL,
  bounding_box,
  dates = NULL,
  frequency = c("monthly", "daily"),
  experiment = "hindcast",
  init = NULL,
  member = NULL,
  release = "latest",
  archive = NULL,
  overwrite = FALSE
)
```

## Arguments

- vars:

  variables to read, from
  [`cefi_variables()`](https://camilleross.org/datamatch/reference/cefi_variables.md)

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

  `"monthly"` (the default) or `"daily"`

- experiment:

  which CEFI experiment to read. `"hindcast"` is the default;
  `"decadal_forecast"` is experimental. The rest are refused with the
  reason — see
  [`cefi_experiments()`](https://camilleross.org/datamatch/reference/cefi_experiments.md).

- init:

  for a forecast, which initialisation to read, as `"i198001"` or
  `"198001"`. Required for `"decadal_forecast"`.

- member:

  for a forecast, which ensemble member or members to read, from 1
  to 10. Required for `"decadal_forecast"`. Several may be given, and
  each arrives as its own block of rows carrying its own source tag.

- release:

  a release directory such as `"r20250715"`, or `"latest"` (the
  default), which follows whatever CEFI published last

- archive:

  a spec from
  [`cefi_archive()`](https://camilleross.org/datamatch/reference/cefi_archive.md),
  to read a domain this package does not ship. Overrides `experiment`,
  `frequency` and `release`.

- overwrite:

  re-read time steps already cached

## Value

one row per grid cell per time step, with `YEAR`, `MONTH`, `DAY` and a
column per requested variable

## Why reach for it, and why not

On the Northwest Atlantic shelf this is the highest-resolution coupled
physics-and-biogeochemistry field available here: a twelfth of a degree
for both, against a quarter degree for the Copernicus biogeochemical
reanalysis. It carries nutrients, oxygen, pH, pCO2, phytoplankton carbon
and mesozooplankton biomass on the same grid as the temperature and
salinity, which no other source in this package does.

Against that: **it is one region**. Outside roughly 98W-36W and 5N-58N
there is nothing to read, and a bounding box outside the domain is
refused rather than returning an empty join. It is also **a model
throughout** — its `CHL` is simulated, not retrieved, and is not the
satellite `CHL` from
[`accessERDDAP()`](https://camilleross.org/datamatch/reference/accessERDDAP.md)
under another name.

## Forecasts are experimental

`experiment = "decadal_forecast"` reads a prediction rather than a
reconstruction, and this package treats it as experimental: it warns on
every call, and it will not choose for you between the things a forecast
makes you choose.

A decadal file is ten years from one January, and there are sixty of
them, so `init` says which initialisation to read. Each holds **ten
ensemble members**, so `member` says which. Neither has a defensible
default and neither is guessed:

- The members are not repeats of one number. They are the model's own
  estimate of how uncertain it is, and averaging them is a modelling
  decision — a reasonable one, often the right one, but not one a fetch
  should make silently. Read the members you want and combine them
  yourself, so the combination is visible in your code.

- A year covered by several initialisations is covered by several
  different forecasts of it, at different lead times. Which one you mean
  is a question about your analysis, not about the archive.

The source tag records both, so
[`source_of()`](https://camilleross.org/datamatch/reference/source_of.md)
on the result says which initialisation and which member produced it.

## What is monthly and what is also daily

The hindcast saves everything monthly. Its **daily** output is
biogeochemistry only — see the section of the same name in
[`cefi_variables()`](https://camilleross.org/datamatch/reference/cefi_variables.md)
— and a daily request for `SST` is refused with the list of what is
available daily rather than returning nothing.

## Longitude and the domain

The regridded files are already on a -180 to 180 grid, so `bounding_box`
is given negative west as everywhere else in this package and needs no
conversion in either direction.

## See also

[`cefi_variables()`](https://camilleross.org/datamatch/reference/cefi_variables.md),
[`cefi_archives()`](https://camilleross.org/datamatch/reference/cefi_archives.md),
[`cefi_archive()`](https://camilleross.org/datamatch/reference/cefi_archive.md),
[`accessCopernicus()`](https://camilleross.org/datamatch/reference/accessCopernicus.md)
for a global reanalysis to compare against

## Examples

``` r
if (FALSE) { # \dontrun{
bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

# The hindcast, monthly
env <- accessCEFI(vars = c("SST", "BOTT", "BOTS"), years = 2015,
                  months = 1:12, bounding_box = bb)
source_of(env)
#> [1] "cefi:NWA12-hindcast-r20250715"

# Daily biogeochemistry on survey dates
bgc <- accessCEFI(vars = c("CHL", "NO3", "PH"), frequency = "daily",
                  dates = unique(observations$date), bounding_box = bb)

matched <- matchData(observations, bgc)
} # }
```
