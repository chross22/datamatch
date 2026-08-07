---
output: github_document
---

<!-- README.md is generated from README.Rmd. Please edit that file -->



# datamatch

<!-- badges: start -->
[![R-CMD-check](https://github.com/chross22/datamatch/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/chross22/datamatch/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

datamatch pulls environmental data from the Copernicus Marine Service and joins
it to point data in space and time. The join is general — species observations,
survey stations, tag positions, or another gridded product — and the package
also covers regridding, gap filling, seafloor terrain, and basin-scale climate
indices.

<details>
<summary><b>Contents</b></summary>

**Getting started**

- [Installation](#installation)
- [Set up](#set-up) — the Copernicus client, sign-in, and where downloads are cached
- [Quick start](#quick-start)
  - [One call per product](#one-call-per-product) — why `SST` and `CHL` are two fetches
  - [Monthly or daily](#monthly-or-daily) — monthly by default; every day of a period, or particular dates
    - [Every day in a period](#every-day-in-a-period)
    - [Particular days](#particular-days)
  - [Downloads run in parallel](#downloads-run-in-parallel) — `n_workers`, and what is already cached

**Choosing what to fetch**

- [Variable names](#variable-names) — request `SST` rather than `thetao`
  - [Satellite or model?](#satellite-or-model) — two sources for chlorophyll, and why they are not interchangeable
- [Spatial and temporal resolution](#spatial-and-temporal-resolution) — what each product resolves, and where the gaps are
- [Forecasts](#forecasts) — the same variables, ten days ahead

**Working with what comes back**

- [Resampling](#resampling) — moving between grids and time steps
  - [Aggregating loses detail, which is the safe direction](#aggregating-loses-detail-which-is-the-safe-direction)
  - [Interpolating adds cells, not information](#interpolating-adds-cells-not-information)
- [Filling satellite gaps](#filling-satellite-gaps) — substituting the model where cloud blocked the view
- [Looking at the data](#looking-at-the-data) — maps, coverage, series, and matched points

**Other covariates**

- [Static and basin-scale covariates](#static-and-basin-scale-covariates)
  - [Seafloor terrain](#seafloor-terrain) — depth, slope, aspect, and TPI
  - [Climate indices](#climate-indices) — NAO, AO, AMO, PDO, LCR, AMOC
    - [The overturning circulation](#the-overturning-circulation)
    - [The Labrador Current retroflection index](#the-labrador-current-retroflection-index)

**Putting it to use**

- [Putting it together](#putting-it-together) — a full worked example, four sources onto one table
- [Matching](#matching) — a general spatiotemporal join, not just observations
- [Looking things up](#looking-things-up) — dictionaries, catalogs, and small helpers
- [Troubleshooting](#troubleshooting) — what the error messages mean
- [Related packages](#related-packages)

</details>

## Installation

You can install the development version of datamatch from [GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("chross22/datamatch")
```

## Set up

Downloads go through `copernicusmarine`, the official Python client. It is not
an R package and is not installed with this one:

``` bash
pip install copernicusmarine
copernicusmarine login
```

`login` needs a free [Copernicus Marine
account](https://data.marine.copernicus.eu/register), and only has to be run
once — the client stores the credentials itself, and this package never sees
them.

Sometimes the client is installed but R cannot find it. This is common when it
lives in a conda environment whose `PATH` RStudio does not inherit. Point at it
directly in `~/.Rprofile`:

``` r
options(datamatch.copernicusmarine = "~/miniconda3/bin/copernicusmarine")
```

Downloaded files are cached so a repeated request is read from disk rather than
re-fetched. The cache goes in `tools::R_user_dir("datamatch", "cache")` unless
you say otherwise:

``` r
options(datamatch.cache = "~/data/copernicus")   # or DATAMATCH_CACHE
```

## Quick start

Request variables by name and let the catalog find the product for you:


``` r
library(datamatch)

env <- accessEnvDat(
  vars = c("SST", "SSS", "MLD"),          # no product_id, no dataset_id
  years = 2003:2017,
  months = 1:12,
  bounding_box = list(xmin = -76, xmax = -65, ymin = 35, ymax = 45)
)

matched <- matchData(observations, env)
```

`variable_dictionary()` lists what is available.

### One call per product

**Variables from different Copernicus products need separate calls.** `SST` is
physics, `CHL` is biogeochemistry, and they live in different datasets on
different grids. Asking for both at once is an error, not a download:


``` r
accessEnvDat(vars = c("SST", "CHL"), ...)
#> Error: These variables come from different Copernicus datasets and cannot be
#>   fetched together.
```

Fetch each separately, then join them to your observations one after another:


``` r
bb <- list(xmin = -76, xmax = -65, ymin = 35, ymax = 45)

phys <- accessEnvDat(vars = c("SST", "SSS", "MLD"),
                     years = 2003:2017, months = 1:12, bounding_box = bb)

bio  <- accessEnvDat(vars = c("CHL", "NO3"),
                     years = 2003:2017, months = 1:12, bounding_box = bb)

matched <- matchData(observations, phys)
matched <- matchData(matched, bio)
```

`matchData()` chains. Each call adds that product's columns and leaves the row
count alone, so the order does not matter and nothing needs combining by hand.

This is not a limitation to work around. The two products are on different grids,
and refusing to fetch them together means the package never quietly reconciles
those grids on your behalf. `matchData()` handles both correctly because it
matches to the nearest cell whatever its size.

### Monthly or daily

**Fetches are monthly means by default**, and a call that mentions neither
`frequency` nor `dates` behaves exactly as it always has.

There are two ways to ask for daily data, for two different jobs:

| Want | Use | Gives |
|---|---|---|
| Every day in a period | `frequency = "daily"` with `years` and `months` | a continuous series |
| Particular days | `dates` | only those dates |

#### Every day in a period

`frequency = "daily"` uses the daily datasets, expanding each requested month
into all of its days:


``` r
sst <- accessEnvDat(vars = c("SST", "MLD"), frequency = "daily",
                    years = 2015, months = 4:6, bounding_box = bb)
```

That is the form to use for a continuous series — a time series at one station,
an animation, anything where the gaps between days would matter.

Daily is a real cost, not a flag: three months is 91 downloads rather than 3,
and 91 grids rather than 3 in memory. A decade of daily data over a large box
will not fit in a laptop's RAM as an `sf` object, and is better fetched a season
at a time.

#### Particular days

`dates` names the exact dates to fetch, so only the days that matter are
downloaded:


``` r
accessEnvDat(vars = "SST", dates = c("20150402", "20150517"), bounding_box = bb)
```

**This is the argument to use when matching daily data to observations.** Survey
dates differ from month to month, and a rule such as "the 1st and 15th" does not
describe them. Take the dates from the observations themselves:


``` r
env <- accessEnvDat(vars = "SST", dates = unique(observations$date),
                    bounding_box = bb)

matched <- matchData(observations, env)
```

`YYYYMMDD` strings, `YYYY-MM-DD` strings, and `Date` objects are all accepted.
Dates are sorted and deduplicated, so the result comes back in date order however
the argument was written. A date the calendar does not have — `"20150230"` — is
an error naming it, not a silently dropped request.

`dates` says which time steps to fetch, so `years` and `months` are neither
needed nor accepted alongside it, and it implies `frequency = "daily"`.

It is also how a long record is thinned rather than fetched whole, since any
sequence of dates will do:


``` r
# Weekly through a decade: 574 downloads rather than 4,017
accessEnvDat(vars = "SST", bounding_box = bb,
             dates = seq(as.Date("2005-01-01"), as.Date("2015-12-31"), by = "week"))

# Or the same day each month, if that is genuinely what you want
accessEnvDat(vars = "SST", bounding_box = bb,
             dates = seq(as.Date("2005-01-15"), as.Date("2015-12-15"), by = "month"))
```

Fetching dates is not the same as averaging a month. Three dates are a sample of
the month, carrying whatever weather fell on them; a monthly mean is the month.
Which you want depends on whether the observations you are matching are
themselves instants or aggregates.

Not everything is published daily. `PH`, `PP`, `DIATO` and `DINO` are monthly
composites only, and asking for them daily is refused before anything is
downloaded rather than failing at the API. Daily `CHL` comes from the *gap-free*
interpolated ocean colour dataset rather than the monthly composite — its cloud
gaps are already filled by Copernicus, so `fill_satellite_gaps()` has nothing to
do on it. `accessEnvDat()` says so when it makes that substitution.

`variable_dataset(vars, frequency = "daily")` shows which dataset each variable
would come from, and `NA` where there is none.

### Downloads run in parallel

**`n_workers` controls this, and it defaults to 4** — parallel downloading is on
without being asked for. A Copernicus subset request spends nearly all of its
time waiting on the API rather than on your machine, so several requests in
flight take barely longer than one.

Two months of daily SST and SSS over a one-degree box — 59 downloads — each run
cold-cache, all three back to back in one session:

| `n_workers` | Elapsed | |
|---|---|---|
| 1 | 295 s | |
| 4 (the default) | 80 s | **3.7× faster** |
| 6 | 51 s | **5.8× faster** |

All three returned identical data. The gain scales with workers rather than with
cores, because the wait is the network rather than your machine. How much you see
depends on the API's mood as much as anything, so treat these as the shape of it
rather than a promise.


``` r
# The default. 15 years x 12 months is 180 downloads, four at a time
accessEnvDat(vars = "SST", years = 2003:2017, months = 1:12, bounding_box = bb)

accessEnvDat(vars = "SST", years = 2003:2017, months = 1:12, bounding_box = bb,
             n_workers = 8)   # more at once
accessEnvDat(vars = "SST", years = 2003:2017, months = 1:12, bounding_box = bb,
             n_workers = 1)   # one at a time
```

**This is not a daily-only feature.** Any fetch spanning more than one time step
is more than one download, so a long monthly record benefits as much as a daily
one — the 180 downloads above are monthly.

Two things it deliberately does not do. It does not re-download what you already
have: files in the cache are read straight from disk, and a fully cached call
starts no workers at all. And it does not parallelise across calls — each
`accessEnvDat()` call is one dataset, so fetching SST and CHL is two calls, run
one after the other with each parallel inside itself.

The limit is the service, not your cores, so raising `n_workers` far past 8
mostly earns rate limiting. A day that fails does not abandon the others: every
day is attempted, the ones that succeeded stay cached, and the error names each
day that failed — so re-running the same call retries only those.

`variable_dataset(c("SST", "CHL"))` tells you which product each variable comes
from, so you can plan the calls before making them. See [Putting it
together](#putting-it-together) for the same pattern with seafloor and
basin-scale covariates added.

## Variable names

Copernicus variable codes are terse and easy to misremember. `thetao` is
temperature, `mlotst` is mixed layer depth, `zos` is sea surface height. Get one
wrong and you get a failed download rather than an obvious mistake.

So you can request variables by name instead. The dictionary lists what is
available, and which product and dataset each comes from:


``` r
library(datamatch)

variable_dictionary()
#> Copernicus variables available by name
#> ------------------------------------------------------------------
#>  name      variable label                                   units    
#>  SST       thetao   Sea surface temperature                 degrees C
#>  SSS       so       Sea surface salinity                    PSU      
#>  BOTT      bottomT  Bottom temperature                      degrees C
#>  UO        uo       Eastward current velocity               m/s      
#>  VO        vo       Northward current velocity              m/s      
#>  SSH       zos      Sea surface height                      m        
#>  MLD       mlotst   Mixed layer depth                       m        
#>  SIC       siconc   Sea ice concentration                   fraction 
#>  CHL       CHL      Chlorophyll-a concentration (satellite) mg/m3    
#>  PP        PP       Primary production (satellite)          mg/m2/day
#>  DIATO     DIATO    Diatom chlorophyll-a concentration      mg/m3    
#>  DINO      DINO     Dinophyte chlorophyll-a concentration   mg/m3    
#>  NO3       no3      Nitrate concentration                   mmol/m3  
#>  PO4       po4      Phosphate concentration                 mmol/m3  
#>  O2        o2       Dissolved oxygen                        mmol/m3  
#>  PH        ph       pH                                      unitless 
#>  CHL_MODEL chl      Chlorophyll-a concentration (model)     mg/m3    
#>  NPP_MODEL nppv     Net primary production (model)          mg/m3/day
#> 
#> GLOBAL_MULTIYEAR_PHY_001_030
#>   variables: SST, SSS, BOTT, UO, VO, SSH, MLD, SIC
#>   dataset:   cmems_mod_glo_phy_my_0.083deg_P1M-m
#>   docs:      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 
#> OCEANCOLOUR_GLO_BGC_L4_MY_009_104
#>   variables: CHL, PP, DIATO, DINO
#>   dataset:   cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1Mcmems_obs-oc_glo_bgc-pp_my_l4-multi-4km_P1M
#>   docs:      https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 
#> GLOBAL_MULTIYEAR_BGC_001_029
#>   variables: NO3, PO4, O2, PH, CHL_MODEL, NPP_MODEL
#>   dataset:   cmems_mod_glo_bgc_my_0.25deg_P1M-m
#>   docs:      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 
#> Pass a name to accessEnvDat(vars = ...), or the Copernicus code.
#> With every variable from one product, product_id and dataset_id can be
#> omitted - they are inferred from the names.
#> Full descriptions: as.data.frame(variable_dictionary())$description
```

`as_markdown()` renders either dictionary as a pipe table, for pasting into
documentation:


``` r
as_markdown(variable_dictionary())
```

| name      | variable | label                                   | units     |
| --------- | -------- | --------------------------------------- | --------- |
| SST       | thetao   | Sea surface temperature                 | degrees C |
| SSS       | so       | Sea surface salinity                    | PSU       |
| BOTT      | bottomT  | Bottom temperature                      | degrees C |
| UO        | uo       | Eastward current velocity               | m/s       |
| VO        | vo       | Northward current velocity              | m/s       |
| SSH       | zos      | Sea surface height                      | m         |
| MLD       | mlotst   | Mixed layer depth                       | m         |
| SIC       | siconc   | Sea ice concentration                   | fraction  |
| CHL       | CHL      | Chlorophyll-a concentration (satellite) | mg/m3     |
| PP        | PP       | Primary production (satellite)          | mg/m2/day |
| DIATO     | DIATO    | Diatom chlorophyll-a concentration      | mg/m3     |
| DINO      | DINO     | Dinophyte chlorophyll-a concentration   | mg/m3     |
| NO3       | no3      | Nitrate concentration                   | mmol/m3   |
| PO4       | po4      | Phosphate concentration                 | mmol/m3   |
| O2        | o2       | Dissolved oxygen                        | mmol/m3   |
| PH        | ph       | pH                                      | unitless  |
| CHL_MODEL | chl      | Chlorophyll-a concentration (model)     | mg/m3     |
| NPP_MODEL | nppv     | Net primary production (model)          | mg/m3/day |

Pass those names to `accessEnvDat()` and the result comes back with them as
column names, rather than the Copernicus codes:


``` r
env <- accessEnvDat(
  vars = c("SST", "SSS", "MLD"),
  years = 2003:2017,
  months = 1:12,
  bounding_box = list(xmin = -76, xmax = -65, ymin = 35, ymax = 45)
)
names(env)
#> "SST" "SSS" "MLD" "YEAR" "MONTH" "DAY" "geometry"
```

**`product_id` and `dataset_id` can be omitted** when every variable is in the
dictionary. The catalog already knows where they live. Raw Copernicus codes work
the same way, so `vars = c("thetao", "so")` infers its dataset too.

Variables from different datasets cannot be fetched in one request. Mixing them
is refused before anything is downloaded, rather than failing obscurely at the
API:


``` r
accessEnvDat(vars = c("SST", "CHL"), ...)
#> Error: These variables come from different Copernicus datasets and cannot be
#>   fetched together:
#>     SST  ->  cmems_mod_glo_phy_my_0.083deg_P1M-m
#>     CHL  ->  cmems_mod_glo_bgc_my_0.25deg_P1M-m
#>   Call accessEnvDat() once per dataset.
```

Existing calls need no change. Anything outside the dictionary is passed through
to the API with a warning, since Copernicus serves far more than this catalog
covers.

### Satellite or model?

Copernicus serves chlorophyll and primary production from two very different
sources, and both are available:

| Name | Source | Resolution | Trade-off |
|---|---|---|---|
| `CHL`, `PP` | Copernicus-GlobColour, satellite | 4 km | Observed, finer — but surface-only and gappy under persistent cloud |
| `CHL_MODEL`, `NPP_MODEL` | Biogeochemistry reanalysis | 0.25° | Gap-free and depth-resolved — but simulated, and coarser |

The plain names default to satellite, since the values are observed rather than
simulated. Switch to the model versions where cloud gaps would matter more than
resolution.

One caution: **satellite `PP` and model `NPP_MODEL` are not the same quantity.**
`PP` is depth-integrated (mg/m2/day), `NPP_MODEL` volumetric (mg/m3/day).
Substituting one for the other is a units error, not a resolution difference.

Phytoplankton functional types come from the same satellite plankton dataset as
`CHL`, so they can be fetched together:


``` r
env <- accessEnvDat(
  vars = c("CHL", "DIATO", "DINO"),   # one request, one dataset
  years = 2003:2017, months = 1:12,
  bounding_box = list(xmin = -76, xmax = -65, ymin = 35, ymax = 45)
)
```

`DIATO` and `DINO` are diatom and dinophyte chlorophyll — the spring-bloom
species large copepods prefer, and the later stratified-water group
respectively.


``` r
variable_dictionary("biogeochemical")        # filter by product
variable_dataset(c("SST", "CHL"))            # which dataset each comes from
as.data.frame(variable_dictionary())$description  # full descriptions
```

## Spatial and temporal resolution

Products do not share a grid, so how resolution is handled matters:

| Source | Spatial | Temporal | Gaps |
|---|---|---|---|
| Physics reanalysis | 0.083° (~9 km) | monthly or daily, from 1993 | gap-free |
| Biogeochemistry reanalysis | 0.25° (~28 km) | monthly or daily, from 1993 | gap-free |
| Satellite ocean colour | 4 km | monthly, from 1997 | **cloud gaps** |
| Analysis-and-forecast | 0.083° / 0.25° | monthly or daily, to ~10 days ahead | gap-free |

Satellite is the finest source, and the only observed one. It is also the only
one with holes. Those holes are not random. They cluster in the seasons and
latitudes where cloud is persistent. `fill_satellite_gaps()` substitutes the
model equivalent where the satellite saw nothing, and records the source of
every value.

**`accessEnvDat()` fetches one dataset per call**, on that dataset's native grid.
It does not resample, and it refuses to fetch variables from different datasets
together rather than quietly reconciling them.

**`matchData()` is resolution-agnostic.** Observations match to the nearest
environmental cell. So a 0.083-degree and a 0.25-degree product both attach
correctly to the same stations. The observation simply lands in a bigger or
smaller cell.

In time it matches at the environmental data's own resolution, inferred from its
time steps. A monthly product matches by month, a daily one by day. Matching a
monthly mean on exact dates would match nothing, because the mean carries one
time step per month while observations fall on arbitrary days.

**Combining two products onto one grid is the caller's decision**, because
neither answer is free.

Keep the finer grid and each coarse cell's value gets repeated across the fine
cells inside it. Fine-scale structure survives in the fine variables, but the
coarse one comes out blocky. A spatial gradient computed from it measures the
source grid, not the ocean.

Keep the coarser grid and nothing is repeated, but you throw away resolution the
fine variables really had. `taupatch` exposes this as a `covariates.grid`
setting.

`upscale_grid()` and `downscale_grid()` are how you act on that decision.

## Resampling

Four functions, one pair per axis, plus one for gaps. Each takes a `method`,
because there is no single right way to change resolution:

| Function | What it does |
|---|---|
| `upscale_grid()` | Aggregates onto a coarser grid — `mean`, `median`, `min`, `max`, `sum`, `mode` |
| `downscale_grid()` | Interpolates onto a finer grid — `nearest`, `bilinear`, `cubic`, `idw` |
| `upscale_time()` | Aggregates onto a coarser time step — `mean`, `median`, `min`, `max`, `sum`, `sd` |
| `downscale_time()` | Interpolates onto a finer time step — `step`, `linear`, `spline` |
| `fill_satellite_gaps()` | Substitutes another covariate wherever the first is missing |


``` r
chl <- accessEnvDat(vars = "CHL", years = 2010, months = 1:12, bounding_box = bb)
sst <- accessEnvDat(vars = "SST", years = 2010, months = 1:12, bounding_box = bb)

# Satellite CHL (4 km) onto the physics grid, so the two can be modelled together
chl_on_sst <- upscale_grid(chl, to = sst)

# Or onto a stated resolution
chl_quarter <- upscale_grid(chl, to = 0.25, method = "median")

# Daily data to monthly means; monthly back out to daily
monthly <- upscale_time(daily_sst, to = "month")
daily   <- downscale_time(monthly, to = "day")
```

The target is either a resolution or **another object whose grid to adopt**. The
second form is what puts two products on one grid.

A resolution is anchored to the origin, not to your data's corner. So two
products upscaled to 0.25° land on the *same* cells, instead of half a cell
apart.

**The right treatment differs by covariate**, which is why this is per-covariate
rather than one setting for everything. Ocean-colour chlorophyll is a 4 km optical
retrieval riddled with cloud gaps. Physics is a 0.083° model with no gaps at all.

Averaging chlorophyll up to the physics grid summarises values that were really
measured. Interpolating physics down to 4 km invents structure. Those are not the
same operation, and no single choice can be right for both.

### Aggregating loses detail, which is the safe direction

`mean` is the default. The others exist because "the value of this coarse cell"
is not one question:

- `median` resists the retrieval outliers at satellite cloud edges.
- `min` of depth is the shallowest point a cell contains, not its average.
- `sum` is for per-cell totals. It is meaningless for a concentration.
- `sd` over a period is variability, which is a covariate in its own right.

Pass one method for everything, or a named vector per variable:


``` r
upscale_grid(env, to = 0.25, method = c(CHL = "median", DEPTH = "min"))
```

**Partly-covered periods and cells come back `NA` by default.** A mean over the
four days of January you happened to fetch is not a January mean, and nothing in
the number itself says so.

`min_coverage` defaults to 0.5. It measures against the steps a period *has* (31
for January), not the steps you downloaded. Set `min_coverage = 0` to aggregate
whatever is present. Set `keep_counts = TRUE` to see what was behind each value.

### Interpolating adds cells, not information

This is the direction to be careful in. A 0.25° field rendered at 4 km has 4 km
*cells*, but it still resolves nothing below 0.25°. None of these methods consult
any other data source, so there is nowhere for real fine-scale structure to come
from.

That is why the defaults are the blunt ones. `nearest` and `step` replicate the
source value, leaving the result visibly blocky at the source resolution, so the
output looks like what it is. `bilinear`, `cubic`, `linear`, and `spline` return
smooth fields that look like finely-resolved measurements and are not.

There is a further trap specific to the time axis:

> **`linear` and `spline` do not preserve the period mean.** Interpolate twelve
> monthly means to daily values, average those days back up, and you will not
> recover the months you started from — in the package's own tests a March mean
> of 15.0 comes back as 14.83. Any budget or total computed from such a series
> inherits that error. `step` preserves it exactly.

`idw` is the exception worth reaching for. Alone among the spatial methods, it
fills across holes rather than propagating them. That makes it useful on gappy
satellite data, where `fill_satellite_gaps()` is not an option.

Resampled output keeps the `YEAR`/`MONTH`/`DAY` stamping convention, so
`matchData()` reads its resolution back correctly and can be used on the result
directly.

## Forecasts

The same variables can be requested from the analysis-and-forecast products,
which run to about ten days ahead:


``` r
env <- accessEnvDat(
  vars = c("SST", "MLD"),
  years = 2026, months = 8,
  bounding_box = list(xmin = -76, xmax = -65, ymin = 35, ymax = 45),
  mode = "forecast"
)
```

Two differences from the reanalysis are worth knowing, and are why this is a
mapping rather than a swapped identifier:

- **The forecast splits variables across more datasets.** `SST` and `SSS` share
  a dataset in the reanalysis but not in the forecast, so a set that fetches in
  one request may need several.
- **Some codes differ.** Bottom temperature is `bottomT` in the reanalysis and
  `tob` in the forecast. Requesting `BOTT` gets the right one either way.

Satellite variables have no forecast — ocean colour is observation, and there is
no observation of the future. Asking for `CHL` in forecast mode says so and
points at `CHL_MODEL`.

## Filling satellite gaps


``` r
chl_sat <- accessEnvDat(vars = "CHL", years = 2010, months = 1:12, bounding_box = bb)
chl_mod <- accessEnvDat(vars = "CHL_MODEL", years = 2010, months = 1:12, bounding_box = bb)

filled <- fill_satellite_gaps(chl_sat, chl_mod, c(CHL = "CHL_MODEL"))
table(filled$CHL_source)
#> satellite     model   missing
#>      8214      1902         0
```

The two sources measure the same quantity in different ways. They are not
interchangeable. So the seam is left visible rather than smoothed over. Nothing
is rescaled by default, and a `<var>_source` column records where each value came
from.

`rescale = TRUE` matches the model's mean and variance to the satellite's over
the cells where both exist. That reduces the step, at the cost of altering the
model values.

## Looking at the data

Four plots, in the order they are usually wanted. All use base graphics, so they
need no extra packages. Each returns the data it drew, so the numbers behind a
picture are always available.


``` r
env <- accessEnvDat(vars = c("SST", "CHL"), years = 2010, months = 1:12,
                    bounding_box = bb)

plot_env(env)                                # first variable, first time step
plot_env(env, "CHL", time = c(MONTH = 6))    # June chlorophyll
```

`plot_env()` maps one variable for one time step. It is the first thing worth
doing after a download. It is also the fastest way to catch a bounding box that
landed somewhere unintended, a variable that is entirely `NA`, or a depth range
that returned the wrong level.

Data are drawn as a raster, so gaps read as holes rather than absent dots. The
time step is named in the title, so a map is never ambiguous about which month it
shows.


``` r
plot_coverage(env)
```

`plot_coverage()` is the one to run before trusting a satellite series. It plots
the fraction of cells carrying a value in each time step. On ocean colour the
shape is stark: near-complete in summer, a quarter of the grid in winter.

That picture decides three things. Whether a monthly mean is worth having.
Whether `fill_satellite_gaps()` is worth the seam it introduces. And where to set
`min_coverage` when aggregating.


``` r
plot_series(env)                     # one panel per variable
plot_series(env, "SST", fun = max)   # the warmest cell each month
```

`plot_series()` reduces each time step to one number over the study area. That is
how a seasonal cycle, a trend, or a step change at a product boundary becomes
visible.

The interquartile range across cells is shaded behind the line. A mean alone
hides the difference between a uniformly warm month and one that is warm inshore
and cold offshore.


``` r
matched <- matchData(observations, env)

plot_matched(matched[matched$MONTH == 7, ], "SST")
```

`plot_matched()` shows what the join actually produced. Observations that matched
nothing are drawn as open circles rather than dropped. A cluster of them is
usually the real finding: observations outside the environmental data's extent,
or in a period it does not cover.

Subset to one period first, as above. The colour scale spans everything passed
in. Plot a whole year of a seasonal variable and the seasons mix together, so the
map reads as noise. A warm February inshore point and a cool August offshore one
can take the same colour.

## Static and basin-scale covariates

Not everything useful is a gridded Copernicus variable on a monthly time step.
Two other kinds are available, and they behave differently from the Copernicus
data and from each other.

### Seafloor terrain

This does not vary by month or year. So it is fetched once for a study area and
attached to every time step. It comes from NOAA ETOPO via `marmap`, a suggested
package rather than a hard dependency:


``` r
bathy <- fetch_bathymetry(
  bounding_box = list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
)

observations <- attach_bathymetry(observations, bathy, c("DEPTH", "SLOPE", "TPI"))
```

`bathymetry_variables()` lists them: `DEPTH`, `SLOPE`, `ASPECT`, and `TPI`.

`TPI`, the topographic position index, is a cell's depth relative to the mean of
the eight around it. It answers a question depth cannot. A 100 m bank top and a
100 m basin floor are the same depth and very different places. TPI is positive
on the first, negative on the second, and near zero on both flat bottom and
uniform slopes.

It is scale-dependent by construction. It describes position within the
immediate neighbourhood, so its meaning follows the
resolution of the grid it was computed on.

`attach_bathymetry()` takes either a plain data frame with coordinate columns or
an `sf` object, so it works on observations and on `accessEnvDat()` output alike.

### Climate indices

These are monthly, and have **no spatial dimension**. One value describes the
whole basin, so every observation in a month receives the same number:


``` r
observations <- attach_climate_index(observations, c("NAO", "AMO"))

index_dictionary()          # NAO, AO, AMO, PDO, LCR, AMOC
```

That makes them a different kind of covariate from local temperature. They tell
you about *when* — what year and season it was. They tell you nothing about
*where* within a region conditions are better.

So they are useful for interannual questions ("was this a warm-regime year?") and
useless for spatial ones. A model given only indices cannot produce a map.

Six are available, and they are not interchangeable.

| Name | What it measures | Units | Timescale | Record |
|---|---|---|---|---|
| `NAO` | Pressure difference, Icelandic Low to Azores High | standardized anomaly | Year to year | 1950– |
| `AO` | Strength of the polar vortex | standardized anomaly | Year to year | 1950– |
| `AMO` | Detrended North Atlantic SST anomaly | degrees C | Multidecadal | 1948– |
| `PDO` | Leading mode of North Pacific SST | standardized anomaly | Decadal | 1948– |
| `LCR` | Retroflection of the Labrador Current | fraction | Year to year | 1993–2014 |
| `AMOC` | Overturning transport at 26.5°N | Sv | Year to year | 2004– |

Most are **standardized anomalies** — in standard deviations, not anything
physical. Only `AMO` (degrees C) and `AMOC` (Sverdrups) carry real units, so a
coefficient fitted to one of those is not comparable with one fitted to `NAO`.
`index_dictionary()` carries the units at runtime.

**`NAO`** is the usual first choice in the Northwest Atlantic. It sets the
strength and track of the westerlies, and with them heat flux and mixing over the
shelves. Its winter values carry most of the signal. Summer values are noisier
and mean less.

**`AO`** is the hemispheric version of the same thing: polar vortex strength
rather than an Atlantic-specific pressure dipole. In winter it correlates
strongly with `NAO`. Including both usually buys little and costs collinearity,
so pick one unless you have a reason.

**`AMO`** is a slow background state, not a year-to-year signal. It varies over
decades. Within a study period of ten or twenty years it may act more like a
trend than a covariate. One caution: it is *derived from* North Atlantic SST, so
using it to predict local SST is partly circular.

**`PDO`** is North Pacific and included for completeness. It has limited relevance
to Atlantic shelf systems, and a relationship found with it is worth treating
sceptically.

The last two are different in kind, and get their own sections below.

#### The overturning circulation

`AMOC` is the strength of the Atlantic overturning in Sverdrups, measured
directly by the RAPID mooring array at 26.5°N. Alone among these it is a
measurement rather than a pattern derived from pressure or SST.


``` r
amoc <- fetch_climate_index("AMOC")      # monthly, April 2004 onward
observations <- attach_climate_index(observations, "AMOC")
```

Being real is also its limitation, in two ways. It **starts in April 2004**, so
it cannot reach back over a longer survey record. And it is measured **far south
of the shelf**: it describes the basin-scale circulation the Labrador and slope
currents sit within, not conditions on the Gulf of Maine or Scotian Shelf. A
weakening AMOC is associated with a warming Northwest Atlantic shelf, but that
is a chain of several links, so check the sign of any relationship against `LCR`
and `AMO` rather than assuming it.

Two practical notes. RAPID publishes this only as NetCDF, so it needs the
`ncdf4` package — a `Suggests`, installed with `install.packages("ncdf4")`. And
the published series is twelve-hourly, averaged to monthly here; the file is over
a megabyte, so it is cached like the Copernicus downloads.

> Moat BI et al. Atlantic meridional overturning circulation observed by the
> RAPID-MOCHA-WBTS array at 26°N. British Oceanographic Data Centre, NERC, UK.
> <https://doi.org/10.5285/223b34a3-2dc5-c945-e063-6c86abc0f5b3>

#### Staying current

Four of the six indices are still growing. Downloads are cached, and the cache
expires on an interval matched to how often each provider actually publishes, so
a living index re-downloads on its own without being asked:


``` r
climate_index_status()      # what is cached, how old, what is due
refresh_climate_index()     # force a re-fetch of everything still growing
refresh_climate_index("AMOC")
```

| Updates | Cache reused for | Indices |
|---|---|---|
| Monthly | 7 days | `NAO`, `AO`, `AMO`, `PDO` |
| Roughly yearly | 30 days | `AMOC` |
| Never | forever | `LCR` |

`LCR` finished at 2014, so re-downloading it cannot produce anything new and it
is skipped rather than fetched again.

Two behaviours are worth knowing, because both are deliberate.

**Staleness is judged from the data, not the cache.** A fresh download of a file
the provider stopped updating is still stale. If a series ends further behind the
present than its source's usual publishing lag, you are told, along with the
command to force a refresh and the note that if refreshing changes nothing then
the provider has not published either.

**A failed download falls back to the cached copy, with a warning.** A provider
being briefly unreachable should not become an error here when usable data is
already on disk. The warning is what keeps the old copy from being mistaken for
a current one.

#### The Labrador Current retroflection index

`LCR` is the odd one out among the five, and often the most directly useful. The
other four are atmospheric or SST patterns. This one describes a *current*: how
much of the Labrador Current turns eastward at the Grand Banks instead of
continuing southwest along the shelf.

Positive values mean stronger retroflection. That means less cold, fresh,
oxygen-rich Labrador water reaching the Scotian Shelf and Gulf of Maine. For
shelf water properties that is a shorter causal chain than the NAO, which acts on
them only indirectly through winds.


``` r
lcr <- fetch_climate_index("LCR")        # monthly, 1993-2014
observations <- attach_climate_index(observations, "LCR")
```

It is the published output of one study rather than an operational product, so
**cite it when you use it**:

> Jutras M, Dufour CO, Mucci A, Talbot LC (2023) Large-scale control of the
> retroflection of the Labrador Current. *Nature Communications* **14**:2623.
> <https://doi.org/10.1038/s41467-023-38321-y>

`index_dictionary()` prints that citation, and
`as.data.frame(index_dictionary())$reference` carries it at runtime.

Three limits worth knowing.

It **covers 1993–2014 only**, so it cannot be attached to recent observations.

The series is fetched from the paper's published source data, not recomputed. The
authors derived it by seeding 966 virtual particles per week across a line at
(53°N, 56.7°W)–(54.3°N, 52.0°W). Each was tracked for three years through
GLORYS12V1 velocities with [OceanParcels](https://oceanparcels.org/). The index
is the difference between the counts crossing hydrographic sections on the
Labrador and Scotian Shelves.

Extending the record past 2014 means redoing that computation, not calling a
different function.

**The values are the raw index, not the normalized one plotted in the paper.**
The published source data runs roughly −0.09 to 0.18, consistent with a fraction
of the seeded particles. Figure 3a of the paper shows a detrended, smoothed
series normalized to [−1, 1], spanning about −0.6 to +0.5.

Both describe the same quantity, but the numbers are not comparable. Don't read a
value here against that figure. To get the paper's variant, apply its chain
yourself: detrend, 12-month rolling mean, rescale to [−1, 1], subtract the
1993–2015 mean.

One interaction to know. `attach_climate_index()` joins on year and month, and
`upscale_time(to = "year")` stamps its output `MONTH = 1`. So attaching an index
to annual data would give every year January's value. Aggregate the index to a
year first instead.

## Putting it together

A worked example: physical, biological, seafloor, and basin-scale covariates onto
one table of species observations. The whole thing is a pipeline of joins. Each
step adds columns and never changes the number of rows.


``` r
library(datamatch)

bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
years <- 2010:2014

# 1. Physical and biological variables come from different Copernicus datasets,
#    so they are two calls. accessEnvDat() refuses to mix them in one.
phys <- accessEnvDat(vars = c("SST", "SSS", "MLD"),
                     years = years, months = 1:12, bounding_box = bb)

bio  <- accessEnvDat(vars = c("CHL", "NO3"),
                     years = years, months = 1:12, bounding_box = bb)

# 2. Seafloor terrain: static, fetched once for the area.
bathy <- fetch_bathymetry(bounding_box = bb)

# 3. Join each source to the observations in turn.
matched <- matchData(observations, phys)
matched <- matchData(matched, bio)

matched <- attach_bathymetry(matched, bathy, c("DEPTH", "SLOPE", "TPI"))
matched <- attach_climate_index(matched, c("NAO", "LCR"))
```

The result carries one row per original observation with every covariate
attached:

```
YEAR MONTH count   SST   SSS   MLD   CHL   NO3  DEPTH  SLOPE    TPI   NAO   LCR
2010     1     2  6.41 32.80  84.2  0.84  4.12  105.5   1.83   77.2  0.31  0.05
2010     1     1  5.98 32.94  91.7  0.79  4.55  294.7   0.42 -114.7  0.31  0.05
```

Three things about this that are worth understanding rather than copying.

**The two `accessEnvDat()` calls are not an inconvenience to work around.** `SST`
and `CHL` live in different datasets on different grids: 0.083° for the physics,
0.25° for the biogeochemistry. The package refuses to fetch them together rather
than quietly reconciling two grids on your behalf. `matchData()` then handles
both correctly, because it matches to the nearest cell whatever its size.

**`matchData()` chains.** Its output is an `sf` object with the same time columns
it consumed. So you can feed it back in for the next dataset, and the row count is
preserved. Order does not matter.

**The joins fail in different ways.** `matchData()` warns and fills `NA` when an
observation falls in a period the environmental data does not cover.
`attach_climate_index()` gives `NA` outside the index's record, which for `LCR`
means anything after 2014. Check for both before modelling:


``` r
colSums(is.na(sf::st_drop_geometry(matched)))
```

You may want everything on a common grid instead, to model the field itself
rather than the observations. Regrid first, then match:


``` r
phys_coarse <- upscale_grid(phys, to = bio)    # 0.083° onto the 0.25° BGC grid
```

## Matching

`matchData(dat, source)` joins each row of `dat` to the nearest feature of
`source` within the same time period, and returns `dat` with `source`'s columns
added.


``` r
matched <- matchData(observations, env)
```

**Neither side has to be observations or environmental data.** It is a
spatiotemporal nearest-feature join between two `sf` point objects carrying
`YEAR`/`MONTH`/`DAY`, so it works equally for stations against a covariate grid,
tag positions against a model field, moorings against satellite retrievals, or
one gridded product against another. The arguments are named `dat` and `source`
for that reason.

Matching happens at **`source`'s** temporal resolution, inferred from its time
steps. That matters for monthly products: a monthly mean carries one time step
per month while observations fall on arbitrary days, so matching on exact dates
would match nothing. Pass `temporal_resolution` to override.

Rows falling in a period `source` does not cover are returned with `NA` and a
warning naming the periods, rather than being dropped silently. One row out per
row in, always. A `source` column whose name collides with one already in `dat`
is suffixed `.matched`, so nothing of yours is overwritten.

> The arguments used to be `speciesDat` and `envDat`. Those still work and warn;
> they will be removed in a later version.

## Looking things up

Small helpers for asking the package what it knows, rather than reading the
source or guessing:


``` r
variable_dictionary()          # printable table of Copernicus variables
copernicus_variables()         # the same catalog as a list, for programmatic use
forecast_variables()           # which variables have a forecast equivalent
variable_dataset("SST")        # which dataset a variable comes from
product_url("GLOBAL_MULTIYEAR_PHY_001_030")   # link to the product page

index_dictionary()             # printable table of climate indices
climate_indices()              # the same catalog as a list
bathymetry_variables()         # DEPTH, SLOPE, ASPECT, TPI

covariate_columns(env)         # which columns of an object are covariates
grid_resolution(env)           # the grid spacing, for deciding which way to resample
```

The `_dictionary()` pair print as tables and are what to read; the plain catalog
functions return lists and are what to write code against. `as_markdown()`
renders either dictionary for pasting into documentation.

## Troubleshooting

Errors you might hit, and what they mean.

**`Could not find the Copernicus Marine client`**

R cannot see `copernicusmarine` on its `PATH`. Common when it lives in a conda
environment that RStudio does not inherit. Point at it directly:


``` r
options(datamatch.copernicusmarine = "~/miniconda3/bin/copernicusmarine")
```

**`These variables come from different Copernicus datasets`**

Expected, not a fault. `SST` is physics and `CHL` is biogeochemistry, on
different grids. Fetch them separately and chain `matchData()`, as in [One call
per product](#one-call-per-product). `variable_dataset()` shows which dataset each
variable comes from.

In forecast mode this happens more often, because the forecast products split
variables across more datasets than the reanalysis does. `SST` and `UO` share a
dataset as reanalysis but not as forecast.

**`The download did not return: uo, vo`**

Those variables were requested but are not in the returned file. Either the
dataset does not serve them, or they are unavailable at the requested depth or
date. The message lists what did arrive.

**`The depth range returned several model levels`**

`depth` spanned more than one model level, so a variable came back on several
layers and there is no way to know which was wanted. Request a single level with
`depth = c(0, 1)`.

**`Copernicus download failed after 3 attempt(s)`**

The request was retried and kept failing. The message carries the client's own
output. Rapid repeated downloads can also be rate-limited, in which case waiting
and re-running works.

**`Expected N variable column(s) but the download returned M`**

From a version before the layer-matching fix. Update the package: this message
blamed the depth range for causes it could not distinguish, and the two real ones
now report themselves. See `NEWS.md`.

**Values in the wrong range for their column name**

Salinity around 32 in an `SST` column means you are on a version predating the
layer-ordering fix, where multi-variable downloads could be mislabelled silently.
Update and re-fetch. `NEWS.md` describes what was affected and how to check.

## Related packages

- [derivoce](https://github.com/chross22/derivoce) — derived covariates
  (gradients, FTLE/FSLE, front and isobath distances, lags, integrals) computed
  from what `accessEnvDat()` returns
