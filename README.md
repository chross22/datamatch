---
output: github_document
---

<!-- README.md is generated from README.Rmd. Please edit that file -->



# datamatch: Fetch Ocean Data from Several Sources and Match It in Space and Time

<!-- badges: start -->
[![R-CMD-check](https://github.com/chross22/datamatch/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/chross22/datamatch/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

datamatch pulls ocean and atmosphere data and joins it to point data in space
and time. The join is general — species observations, survey stations, tag
positions, or another gridded product — and the package also covers regridding,
gap filling, seafloor terrain, and basin-scale climate indices.

Five sources sit behind one interface, sharing one set of variable names:

| Source | Function | Gives | Steps | Record |
|---|---|---|---|---|
| Copernicus Marine | `accessCopernicus()` | physics, biogeochemistry, ocean colour, wind and stress | monthly, daily, hourly | 1993– |
| FVCOM / NECOFS | `accessFVCOM()` | coastal model on a triangular mesh | monthly, hourly | 1978–2013, then 2025– |
| HYCOM | `accessHYCOM()` | independent global model, sea-floor fields | 3-hourly | 1994–2024 |
| CCMP | `accessCCMP()` | surface winds | 6-hourly | 1993–present |
| MUR / VIIRS | `accessERDDAP()` | satellite SST and chlorophyll | daily | 2002– / 2012– |

Each takes `vars`, a `bounding_box`, and either `years`/`months` or `dates`, and
each returns one row per cell per time step, as `sf`. So `matchData()` joins any
of them to your observations, and they chain:

``` r
matched <- matchData(observations, accessCopernicus(vars = "SST", ...))
matched <- matchData(matched,      accessHYCOM(vars = "BOTS", ...))
matched <- matchData(matched,      accessCCMP(vars = "WSPD", ...))
```

> **One name, several sources, and they are not the same number.** `SST` from
> Copernicus, FVCOM and HYCOM are three different models, and `WSPD` from
> Copernicus and CCMP two different analyses. Sharing the column name is what
> makes them interchangeable *mechanically* — so everything downstream works
> unchanged — and is exactly why it is worth recording which one you used.
> `matchData()` writes a `<var>_source` column saying which, and `source_of()`
> reads it back.

This README is the front door. The detail lives in
[four articles](#vignettes), and
["Choosing a data source"](https://chross22.github.io/datamatch/articles/sources.html)
compares the five side by side if that is what you came for.

## Installation

``` r
# install.packages("devtools")
devtools::install_github("chross22/datamatch")
```

## Set up

**Only Copernicus needs an account.** FVCOM, HYCOM, CCMP and the ERDDAP
satellite products are read over plain HTTP and OPeNDAP with no credentials at
all; they need the `ncdf4` package, which is a `Suggests`:

``` r
install.packages("ncdf4")
```

Copernicus downloads go through `copernicusmarine`, the official Python client.
It is not an R package and is not installed with this one:

``` bash
pip install copernicusmarine
copernicusmarine login
```

`login` needs a free [Copernicus Marine
account](https://data.marine.copernicus.eu/register), and only has to be run
once — the client stores the credentials itself, and this package never sees
them. If the client is installed but R cannot find it — common when it lives in
a conda environment whose `PATH` RStudio does not inherit — point at it directly
in `~/.Rprofile`:

``` r
options(datamatch.copernicusmarine = "~/miniconda3/bin/copernicusmarine")
```

Downloaded files are cached, so a repeated request is read from disk rather than
re-fetched. The cache goes in `tools::R_user_dir("datamatch", "cache")` unless
you say otherwise:

``` r
options(datamatch.cache = "~/data/copernicus")   # or DATAMATCH_CACHE
```

## Quick start

Request variables by name and let the catalog find the product for you:


``` r
library(datamatch)

env <- accessCopernicus(
  vars = c("SST", "SSS", "MLD"),          # no product_id, no dataset_id
  years = 2003:2017,
  months = 1:12,
  bounding_box = list(xmin = -76, xmax = -65, ymin = 35, ymax = 45)
)

matched <- matchData(observations, env)
```

**Variables from different products need separate calls.** `SST` is physics,
`CHL` is biogeochemistry, and they live in different datasets on different
grids. Asking for both at once is an error, not a download — the package will
not quietly reconcile two grids on your behalf. Fetch each separately and chain
`matchData()`, which handles both correctly because it matches to the nearest
cell whatever its size.

**Fetches are monthly means by default.** For daily data there are two forms,
for two different jobs:

| Want | Use | Gives |
|---|---|---|
| Every day in a period | `frequency = "daily"` with `years` and `months` | a continuous series |
| Particular days | `dates` | only those dates |

`dates` is the one to use when matching to observations, since survey dates
differ from month to month:


``` r
env <- accessCopernicus(vars = "SST", dates = unique(observations$date),
                        bounding_box = bb)
```

It is also how a long record is thinned rather than fetched whole — a weekly
sequence through a decade is 574 downloads rather than 4,017. Daily is a real
cost, not a flag: three months is 91 downloads and 91 grids in memory.

→ [Choosing a data
source](https://chross22.github.io/datamatch/articles/sources.html#sub-daily-data-and-means-that-are-not-means)
covers sub-daily data, and which sources have a real mean to fetch rather than a
snapshot.

## The shared vocabulary

Source codes are terse and easy to misremember — `thetao` is temperature,
`mlotst` is mixed layer depth. Get one wrong and you get a failed download
rather than an obvious mistake. So variables are requested by name, and come
back in columns of that name:


``` r
as_markdown(variable_dictionary())
```

| name      | variable              | label                                   | units     |
| --------- | --------------------- | --------------------------------------- | --------- |
| SST       | thetao                | Sea surface temperature                 | degrees C |
| SSS       | so                    | Sea surface salinity                    | PSU       |
| BOTT      | bottomT               | Bottom temperature                      | degrees C |
| BOTS      | so                    | Bottom salinity                         | PSU       |
| UO        | uo                    | Eastward current velocity               | m/s       |
| VO        | vo                    | Northward current velocity              | m/s       |
| SSH       | zos                   | Sea surface height                      | m         |
| MLD       | mlotst                | Mixed layer depth                       | m         |
| SIC       | siconc                | Sea ice concentration                   | fraction  |
| CHL       | CHL                   | Chlorophyll-a concentration (satellite) | mg/m3     |
| PP        | PP                    | Primary production (satellite)          | mg/m2/day |
| DIATO     | DIATO                 | Diatom chlorophyll-a concentration      | mg/m3     |
| DINO      | DINO                  | Dinophyte chlorophyll-a concentration   | mg/m3     |
| NO3       | no3                   | Nitrate concentration                   | mmol/m3   |
| PO4       | po4                   | Phosphate concentration                 | mmol/m3   |
| O2        | o2                    | Dissolved oxygen                        | mmol/m3   |
| PH        | ph                    | pH                                      | unitless  |
| CHL_MODEL | chl                   | Chlorophyll-a concentration (model)     | mg/m3     |
| NPP_MODEL | nppv                  | Net primary production (model)          | mg/m3/day |
| WSPD      | wind_speed            | Wind speed                              | m/s       |
| UWND      | eastward_wind         | Eastward wind                           | m/s       |
| VWND      | northward_wind        | Northward wind                          | m/s       |
| TAUX      | eastward_stress       | Eastward wind stress                    | N/m2      |
| TAUY      | northward_stress      | Northward wind stress                   | N/m2      |
| TAU       | wind_stress_magnitude | Wind stress magnitude                   | N/m2      |

`variable_dictionary()` prints the same thing grouped by product, with the
dataset identifiers and documentation links. `fvcom_dictionary()`,
`hycom_dictionary()`, `ccmp_dictionary()` and `erddap_dictionary()` do the same
for the other four sources, and `as_markdown()` renders any of them as a pipe
table.

**`product_id` and `dataset_id` can be omitted** when every variable is in the
dictionary — the catalog already knows where they live. Raw source codes work
the same way. Anything outside the dictionary is passed through to the API with
a warning, since these services serve far more than this catalog covers.

## Copernicus Marine

`accessCopernicus()`. The widest catalog and the longest record: physics,
biogeochemistry, satellite ocean colour, and surface wind and stress, from 1993
with a forecast running ten days ahead. The only source needing an account, and
the one the Quick start uses.

Three things about it that surprise people:

- **Chlorophyll comes from two very different places.** `CHL` and `PP` are
  satellite retrievals — observed, 4 km, gappy under cloud. `CHL_MODEL` and
  `NPP_MODEL` are the biogeochemistry reanalysis — gap-free and depth-resolved,
  but simulated and coarser. Satellite `PP` and model `NPP_MODEL` are also not
  the same quantity: one is depth-integrated, the other volumetric.
- **Wind is its own product on its own grid**, published monthly or hourly and
  **nothing between**, so `frequency = "daily"` is refused for it rather than
  quietly substituted. Speed and stress are not the same covariate either —
  stress is roughly quadratic in speed, and is what actually sets mixing.
- **`BOTS` is derived here.** GLORYS12V1 publishes no sea-floor salinity, so the
  full depth column is fetched and the deepest wet level kept — which means it
  must be fetched on its own, and returns a `BOTS_depth` column.

`mode = "forecast"` requests the same variables from the analysis-and-forecast
products, about ten days ahead. The forecast splits variables across more
datasets and renames a few codes; requesting `BOTT` gets the right one either
way. Satellite variables have no forecast, and asking says so.

→ [Choosing a data
source](https://chross22.github.io/datamatch/articles/sources.html) covers the
satellite-or-model trade, bottom salinity four ways, and the wind record in
full.

## FVCOM

`accessFVCOM()` reads NECOFS — the Northeast Coastal Ocean Forecast System,
built on FVCOM at UMass Dartmouth — and returns the same shape of object, so
everything downstream works unchanged:


``` r
bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

fv <- accessFVCOM(vars = c("SST", "BOTT", "BOTS"), years = 2010:2013,
                  months = 1:12, bounding_box = bb)
```

**Why reach for it.** It is a coastal model on a triangular mesh that refines
toward the shore. Over that box GLORYS resolves 1,742 cells where GOM3 carries
6,579 nodes, concentrated where the bathymetry is complicated. Sigma coordinates
also make `BOTS` free — the deepest layer is the sea floor at every node.

**Why not.** It is one regional model rather than a reanalysis assimilating
observations basin-wide, it stops at the mesh boundary, and the hindcast **ends
in 2013**. `fvcom_archives()` ships two archives and the second is *not* a
continuation of the first: GOM3 is a monthly hindcast on 48,451 nodes to 2013,
GOM7 an hourly forecast archive on 207,081 nodes from 2025, with no wind stress
and nothing in between.

Two structural facts worth knowing before the first call. Scalars sit on mesh
**nodes** and velocities on element **centroids**, so the two kinds cannot be
fetched together and asking is an error rather than a silent interpolation. And
`accessFVCOM()` returns values at points, which is what matching needs but is
not the grid — `fvcom_mesh()` returns the triangles themselves:


``` r
mesh <- fvcom_mesh(bounding_box = bb)

plot_mesh(mesh)                       # the grid itself
plot_mesh(mesh, "DEPTH")              # shaded by bathymetry
plot_mesh(mesh, "SST", values = sst)  # shaded by a fetched covariate
```

**FVCOM is a model, not a data product** — there is no global archive to point
at. Groups run it for their own coastlines, so `fvcom_archive(url)` describes
any other endpoint and `accessFVCOM()` reads it, because everything it does
depends on FVCOM's structure rather than on the region.

## HYCOM

`accessHYCOM()` reads HYCOM + NCODA GOFS 3.1 from the Naval Research
Laboratory's THREDDS server. Two reasons to reach for it: it publishes
**`salinity_bottom` and `water_temp_bottom` as fields**, so `BOTS` costs nothing
where Copernicus must derive it; and it is an **independent model**, so
agreement between it and Copernicus is evidence about a result in a way that
either alone is not.

It publishes instantaneous fields every three hours and there is **no mean in
the archive**, so `frequency = "daily"` takes a snapshot at `hour` (12 UTC by
default) and `"3hourly"` returns every step. A snapshot is not a mean; for a real
one, fetch the steps and `upscale_time(to = "day")`.

The default archive is the reanalysis (1994–2015), one internally consistent
run. HYCOM continues to September 2024, but as a chain of shorter **operational**
experiments — the model as it was running at the time. `hycom_covering(date)`
says which archives hold a day, and a request outside the one named is told
which others have it rather than being stitched to them silently:


``` r
hycom_covering("2019-06-15")
#> [1] "GLBv930" "GLBy930"
```

The seam that matters is the **run**, not the grid. Note also that some
three-hourly steps are simply absent, so a daily request at a missing hour skips
that day and warns.

## CCMP

`accessCCMP()` reads the Cross-Calibrated Multi-Platform ocean surface wind
analysis from Remote Sensing Systems, with no account needed. It is the longest
and finest-in-time wind record here — **six-hourly from January 1993 to within
days of the present**, where the Copernicus wind is monthly from mid-1994 or
hourly only from 2007.

Two trades. **CCMP carries no wind stress**, and stress rather than speed is
what drives mixing and Ekman pumping; it cannot be recovered without choosing a
drag coefficient, which is a modelling decision this package will not make for
you. And **CCMP has no server-side subsetting** — RSS publishes static files, so
a day is one 33 MB global file however small the box. Subsets are cached, and a
request for more than 30 days says what it is about to download before starting.

`NOBS` is worth fetching alongside the winds when coverage is in doubt: it counts
the satellite retrievals behind each cell, and zero means the value is the model
background rather than an observation.

> One trap handled for you: CCMP is stored on a **0–360 longitude grid**, alone
> among the sources here. Pass `bounding_box` negative west as everywhere else —
> it is converted on the way in, and comes back negative west, so the result
> overlays the other sources without adjustment.

## MUR and VIIRS, through ERDDAP

`accessERDDAP()` reads satellite products from NOAA's ERDDAP servers — no
account needed, and subset server-side:

| Dataset | Gives | Resolution | Record |
|---|---|---|---|
| `MUR` (default) | `SST`, `SST_ERROR`, `ICE` | 0.01° daily | 2002-06– |
| `VIIRSCHL` | `CHL`, gap-filled | 0.04° daily | 2020-05– |
| `VIIRSCHL2018` | `CHL`, raw retrieval | 0.04° daily | 2012-01–2022-07 |

**MUR is the finest field here by a wide margin** — 0.01° is about 1 km, where
the physics reanalysis is 9 km. But **a satellite SST is not a model SST**: MUR
measures the *foundation* temperature, below the daily warming layer, where a
model `SST` is its topmost level. On a calm sunny afternoon they differ by a
degree or more. Both arrive in a column called `SST`, which is why `matchData()`
records `<var>_source`.

MUR is also gap-free by construction — it is an analysis, so cloud is
interpolated over rather than left `NA`. Fetch `SST_ERROR` alongside if that
matters. ERDDAP hosts thousands more datasets; `erddap_dataset()` describes any
of them for `accessERDDAP()`, the same way `fvcom_archive()` does for FVCOM.

## Matching

`matchData(dat, source)` joins each row of `dat` to the nearest feature of
`source` within the same time period, and returns `dat` with `source`'s columns
added.

**Neither side has to be observations or environmental data.** It is a
spatiotemporal nearest-feature join between two `sf` point objects carrying
`YEAR`/`MONTH`/`DAY`, so it works equally for stations against a covariate grid,
tag positions against a model field, or one gridded product against another.

Matching happens at **`source`'s** temporal resolution, inferred from its time
steps. That matters for monthly products: a monthly mean carries one time step
per month while observations fall on arbitrary days, so matching on exact dates
would match nothing. Pass `temporal_resolution` to override.

Rows falling in a period `source` does not cover are returned with `NA` and a
warning naming the periods, rather than being dropped silently. One row out per
row in, always. A `source` column colliding with one already in `dat` is
suffixed `.matched`, so nothing of yours is overwritten.

> The arguments used to be `speciesDat` and `envDat`. Those still work and warn;
> they will be removed in a later version.

## Working with what comes back

Everything an access function returns is the same shape, so the same tools apply
whichever source produced it:


``` r
upscale_grid(chl, to = sst)             # onto another product's grid
downscale_grid(sst, to = 0.05)          # onto a finer one
upscale_time(hourly, to = "day")        # hour -> day -> month -> year
downscale_time(monthly, to = "day")

fill_satellite_gaps(chl_sat, chl_mod, c(CHL = "CHL_MODEL"))

plot_env(env)                           # a map of one variable, one step
plot_coverage(env)                      # how much of the grid carries a value
plot_series(env)                        # the study area reduced to a series
plot_matched(matched, "SST")            # what the join actually produced
```

Two rules worth carrying even if you read no further. **Aggregating loses
detail, which is the safe direction; interpolating adds cells, not
information** — so the defaults are the blunt methods that look like what they
are. And **`linear` and `spline` do not preserve the period mean**, so a budget
computed from an interpolated series inherits that error; `step` does preserve
it.

Combining two products onto one grid is deliberately the caller's decision,
because neither answer is free: keep the finer grid and the coarse variable
comes out blocky, keep the coarser and you discard resolution the fine variables
really had.

→ [**Working with what comes back**](https://chross22.github.io/datamatch/articles/working-with-data.html)
covers the methods, when each is right, `min_coverage`, and what each plot is
for.

## Static and basin-scale covariates

Two kinds of covariate are not gridded fields on a time step, and neither is
attached with `matchData()`:


``` r
bathy <- fetch_bathymetry(bounding_box = bb)
observations <- attach_bathymetry(observations, bathy, c("DEPTH", "SLOPE", "TPI"))

observations <- attach_climate_index(observations, c("NAO", "AMO"))
```

**Seafloor terrain** — `DEPTH`, `SLOPE`, `ASPECT`, `TPI` from NOAA ETOPO — does
not vary in time, so it is fetched once and attached to every step.
**Climate indices** — `NAO`, `AO`, `AMO`, `PDO`, `LCR`, `AMOC` — have no spatial
dimension at all: one value describes the whole basin in a month, so they tell
you about *when*, never about *where*.

→ [**Static and basin-scale covariates**](https://chross22.github.io/datamatch/articles/covariates.html)
covers what TPI actually measures, which index to choose and why they are not
interchangeable, and the `LCR` and `AMOC` caveats.

## Putting it together

Physical, biological, seafloor and basin-scale covariates onto one table of
observations. The whole thing is a pipeline of joins; each step adds columns and
never changes the number of rows:


``` r
bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

phys <- accessCopernicus(vars = c("SST", "SSS", "MLD"),
                         years = 2010:2014, months = 1:12, bounding_box = bb)
bio  <- accessCopernicus(vars = c("CHL", "NO3"),
                         years = 2010:2014, months = 1:12, bounding_box = bb)
bathy <- fetch_bathymetry(bounding_box = bb)

matched <- matchData(observations, phys)
matched <- matchData(matched, bio)
matched <- attach_bathymetry(matched, bathy, c("DEPTH", "SLOPE", "TPI"))
matched <- attach_climate_index(matched, c("NAO", "LCR"))

colSums(is.na(sf::st_drop_geometry(matched)))   # the joins fail in different ways
```

`matchData()` warns and fills `NA` when an observation falls in a period the
environmental data does not cover; `attach_climate_index()` gives `NA` outside
the index's record, which for `LCR` means anything after 2014. Check for both
before modelling.

→ [**Getting started**](https://chross22.github.io/datamatch/articles/datamatch.html)
walks this through end to end.

## Depositing what you made

`write_eml()` writes [Ecological Metadata
Language](https://eml.ecoinformatics.org/) for a matched table — the standard
EDI, LTER and DataONE expect alongside a deposited dataset. Most of the document
is filled in from the data: the bounding box and date range from the object, and
an attribute for every column with its definition, units and measurement scale.

The part worth having is the **methods section**. Because `matchData()` records
`<var>_source` on every join, a table with four sources chained onto it produces
a methods statement naming all four and a citation for each — otherwise the most
tedious part of depositing a derived dataset, and the easiest to get wrong.
`title`, `creator` and `abstract` are yours to supply; nothing else needs to be.
Needs the `emld` package, a `Suggests`.

## Function reference

The [pkgdown reference
index](https://chross22.github.io/datamatch/reference/index.html) has a page for
each export. In brief:

| | |
|---|---|
| **Fetching** | `accessCopernicus()`, `accessFVCOM()`, `accessHYCOM()`, `accessCCMP()`, `accessERDDAP()` |
| **Matching** | `matchData()`, `source_of()`, `write_eml()`, `covariate_columns()` |
| **Resampling** | `upscale_grid()`, `downscale_grid()`, `upscale_time()`, `downscale_time()`, `grid_resolution()`, `fill_satellite_gaps()` |
| **Plotting** | `plot_env()`, `plot_coverage()`, `plot_series()`, `plot_matched()`, `plot_mesh()` |
| **Terrain and indices** | `fetch_bathymetry()`, `attach_bathymetry()`, `bathymetry_variables()`, `fetch_climate_index()`, `attach_climate_index()`, `climate_indices()`, `index_dictionary()`, `climate_index_status()`, `refresh_climate_index()` |
| **Catalogs** | `variable_dictionary()`, `fvcom_dictionary()`, `hycom_dictionary()`, `ccmp_dictionary()`, `erddap_dictionary()`, `as_markdown()` |
| **Escape hatches** | `fvcom_archive()`, `erddap_dataset()`, `hycom_covering()`, `fvcom_mesh()` |

The `_dictionary()` functions print as tables and are what to read; the plain
catalog functions return lists and are what to write code against —
`copernicus_variables()`, `variable_dataset()`, `forecast_variables()` and
`product_url()` for Copernicus, and `fvcom_variables()`, `fvcom_archives()`,
`hycom_variables()`, `hycom_archives()`, `ccmp_variables()`, `ccmp_versions()`
and `erddap_datasets()` for the rest. `accessEnvDat()` is the old name for
`accessCopernicus()`; it works, and warns.

## Vignettes

| | |
|---|---|
| [Getting started](https://chross22.github.io/datamatch/articles/datamatch.html) | observations to a modelling table, end to end |
| [Choosing a data source](https://chross22.github.io/datamatch/articles/sources.html) | which of the five to reach for, what changes when you do, error messages, and what to cite |
| [Working with what comes back](https://chross22.github.io/datamatch/articles/working-with-data.html) | resampling, gap filling, and looking at the data |
| [Static and basin-scale covariates](https://chross22.github.io/datamatch/articles/covariates.html) | seafloor terrain and climate indices |

## Related packages

- [derivoce](https://github.com/chross22/derivoce) — derived covariates
  (gradients, FTLE/FSLE, front and isobath distances, lags, integrals) computed
  from what `accessCopernicus()` returns

## Citing

Everything datamatch returns comes from someone else's data, and the obligation
to cite travels with the data rather than with this package. **Cite whichever
products you actually used** — [Choosing a data
source](https://chross22.github.io/datamatch/articles/sources.html#what-to-cite)
lists them all with DOIs, `variable_dictionary()` links to each Copernicus
product page, and `index_dictionary()`, `fvcom_archives()`, `hycom_archives()`
and `ccmp_versions()` carry their references at runtime.

```r
citation("datamatch")
```
