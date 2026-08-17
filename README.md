
<!-- README.md is generated from README.Rmd. Please edit that file -->

# datamatch: Fetch Ocean Data from Several Sources and Match It in Space and Time

<!-- badges: start -->

[![R-CMD-check](https://github.com/chross22/datamatch/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/chross22/datamatch/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

datamatch pulls ocean and atmosphere data and joins it to point data in
space and time. The join is general — species observations, survey
stations, tag positions, or another gridded product — and the package
also covers regridding, gap filling, seafloor terrain, and basin-scale
climate indices.

Five sources sit behind one interface, sharing one set of variable
names:

| Source | Function | Gives | Steps | Record |
|----|----|----|----|----|
| [Copernicus Marine](#quick-start) | `accessEnvDat()` | physics, biogeochemistry, ocean colour, wind and stress | monthly, daily, hourly | 1993– |
| [FVCOM / NECOFS](#fvcom-a-regional-model-on-an-unstructured-mesh) | `accessFVCOM()` | coastal model on a triangular mesh | monthly, hourly | 1978–2013, then 2025– |
| [HYCOM](#hycom-and-bottom-fields-for-free) | `accessHYCOM()` | independent global model, sea-floor fields | 3-hourly | 1994–2024 |
| [CCMP](#ccmp-the-long-wind-record) | `accessCCMP()` | surface winds | 6-hourly | 1993–present |
| [MUR / VIIRS](#mur-and-viirs-through-erddap) | `accessERDDAP()` | satellite SST and chlorophyll | daily | 2002– / 2012– |

All five return the same `sf` shape, so `matchData()` joins any of them
to your observations and they chain together:

``` r
matched <- matchData(observations, accessEnvDat(vars = "SST", ...))
matched <- matchData(matched,      accessHYCOM(vars = "BOTS", ...))
matched <- matchData(matched,      accessCCMP(vars = "WSPD", ...))
```

> **One name, several sources, and they are not the same number.** `SST`
> from Copernicus, FVCOM and HYCOM are three different models, and
> `WSPD` from Copernicus and CCMP two different analyses. Sharing the
> column name is what makes them interchangeable *mechanically* — so
> everything downstream works unchanged — and is exactly why it is worth
> recording which one you used. `matchData()` writes a `<var>_source`
> column saying which, and `source_of()` reads it back.

**How to read the rest of this.** [Quick start](#quick-start) and
[Variable names](#variable-names) use Copernicus throughout, because it
has the widest variable list and the setup everything else builds on —
but nearly all of it (matching, resampling, plotting, the time-step
rules) applies to every source. The other four get their own sections
under [The five
sources](#fvcom-a-regional-model-on-an-unstructured-mesh), and the
[“Choosing a data
source”](https://chross22.github.io/datamatch/articles/sources.html)
vignette compares them side by side if that is what you came for.

<details>

<summary>

<b>Contents</b>
</summary>

**Getting started**

- [Installation](#installation)
- [Set up](#set-up) — only Copernicus needs an account
- [Quick start](#quick-start)
  - [One call per product](#one-call-per-product)
  - [Monthly, daily, or hourly](#monthly-daily-or-hourly)
  - [Downloads run in parallel](#downloads-run-in-parallel)

**Choosing what to fetch**

- [Variable names](#variable-names) — request `SST` rather than `thetao`
  - [Satellite or model?](#satellite-or-model)
  - [Winds](#winds)
  - [Bottom salinity](#bottom-salinity)
- [Spatial and temporal resolution](#spatial-and-temporal-resolution)
- [Forecasts](#forecasts) — the same variables, ten days ahead

**The five sources**

- [FVCOM, a regional model on an unstructured
  mesh](#fvcom-a-regional-model-on-an-unstructured-mesh) — NECOFS,
  1978–2013 and 2025–
- [HYCOM, and bottom fields for free](#hycom-and-bottom-fields-for-free)
  — GOFS 3.1, 1994–2024
- [CCMP, the long wind record](#ccmp-the-long-wind-record) — six-hourly
  winds, 1993–present
- [MUR and VIIRS, through ERDDAP](#mur-and-viirs-through-erddap) — 0.01°
  satellite SST, and chlorophyll

**Putting it to use**

- [Working with what comes back](#working-with-what-comes-back) —
  resampling, gap filling, plots
- [Static and basin-scale
  covariates](#static-and-basin-scale-covariates) — seafloor terrain and
  climate indices
- [Putting it together](#putting-it-together) — a full worked example
- [Matching](#matching) — a general spatiotemporal join
- [Function reference](#function-reference) — everything the package
  exports
- [Vignettes](#vignettes)
- [Troubleshooting](#troubleshooting) — what the error messages mean
- [Related packages](#related-packages)
- [References](#references) — cite the data, not this package

</details>

## Installation

You can install the development version of datamatch from
[GitHub](https://github.com/chross22/datamatch) with:

``` r
# install.packages("devtools")
devtools::install_github("chross22/datamatch")
```

## Set up

**Only Copernicus needs an account.** FVCOM, HYCOM, CCMP and the ERDDAP
satellite products are read over plain HTTP and OPeNDAP with no
credentials at all; they need the `ncdf4` package, which is a
`Suggests`:

``` r
install.packages("ncdf4")
```

Copernicus downloads go through `copernicusmarine`, the official Python
client. It is not an R package and is not installed with this one:

``` bash
pip install copernicusmarine
copernicusmarine login
```

`login` needs a free [Copernicus Marine
account](https://data.marine.copernicus.eu/register), and only has to be
run once — the client stores the credentials itself, and this package
never sees them.

Sometimes the client is installed but R cannot find it. This is common
when it lives in a conda environment whose `PATH` RStudio does not
inherit. Point at it directly in `~/.Rprofile`:

``` r
options(datamatch.copernicusmarine = "~/miniconda3/bin/copernicusmarine")
```

Downloaded files are cached so a repeated request is read from disk
rather than re-fetched. The cache goes in
`tools::R_user_dir("datamatch", "cache")` unless you say otherwise:

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

**Variables from different Copernicus products need separate calls.**
`SST` is physics, `CHL` is biogeochemistry, and they live in different
datasets on different grids. Asking for both at once is an error, not a
download:

``` r
accessEnvDat(vars = c("SST", "CHL"), ...)
#> Error: These variables come from different Copernicus datasets and cannot be
#>   fetched together.
```

Fetch each separately, then join them to your observations one after
another:

``` r
bb <- list(xmin = -76, xmax = -65, ymin = 35, ymax = 45)

phys <- accessEnvDat(vars = c("SST", "SSS", "MLD"),
                     years = 2003:2017, months = 1:12, bounding_box = bb)

bio  <- accessEnvDat(vars = c("CHL", "NO3"),
                     years = 2003:2017, months = 1:12, bounding_box = bb)

matched <- matchData(observations, phys)
matched <- matchData(matched, bio)
```

`matchData()` chains. Each call adds that product’s columns and leaves
the row count alone, so the order does not matter and nothing needs
combining by hand.

This is not a limitation to work around. The two products are on
different grids, and refusing to fetch them together means the package
never quietly reconciles those grids on your behalf. `matchData()`
handles both correctly because it matches to the nearest cell whatever
its size.

### Monthly, daily, or hourly

**Fetches are monthly means by default**, and a call that mentions
neither `frequency` nor `dates` behaves exactly as it always has.

There are two ways to ask for daily data, for two different jobs:

| Want | Use | Gives |
|----|----|----|
| Every day in a period | `frequency = "daily"` with `years` and `months` | a continuous series |
| Particular days | `dates` | only those dates |

There is also `frequency = "hourly"`, which only the wind variables have
— see [Winds](#winds). The ocean reanalyses are daily at finest.

#### Every day in a period

`frequency = "daily"` uses the daily datasets, expanding each requested
month into all of its days:

``` r
sst <- accessEnvDat(vars = c("SST", "MLD"), frequency = "daily",
                    years = 2015, months = 4:6, bounding_box = bb)
```

That is the form to use for a continuous series — a time series at one
station, an animation, anything where the gaps between days would
matter.

Daily is a real cost, not a flag: three months is 91 downloads rather
than 3, and 91 grids rather than 3 in memory. A decade of daily data
over a large box will not fit in a laptop’s RAM as an `sf` object, and
is better fetched a season at a time.

#### Particular days

`dates` names the exact dates to fetch, so only the days that matter are
downloaded:

``` r
accessEnvDat(vars = "SST", dates = c("20150402", "20150517"), bounding_box = bb)
```

**This is the argument to use when matching daily data to
observations.** Survey dates differ from month to month, and a rule such
as “the 1st and 15th” does not describe them. Take the dates from the
observations themselves:

``` r
env <- accessEnvDat(vars = "SST", dates = unique(observations$date),
                    bounding_box = bb)

matched <- matchData(observations, env)
```

`YYYYMMDD` strings, `YYYY-MM-DD` strings, and `Date` objects are all
accepted. Dates are sorted and deduplicated, so the result comes back in
date order however the argument was written. A date the calendar does
not have — `"20150230"` — is an error naming it, not a silently dropped
request.

`dates` says which time steps to fetch, so `years` and `months` are
neither needed nor accepted alongside it, and it implies
`frequency = "daily"`.

It is also how a long record is thinned rather than fetched whole, since
any sequence of dates will do:

``` r
# Weekly through a decade: 574 downloads rather than 4,017
accessEnvDat(vars = "SST", bounding_box = bb,
             dates = seq(as.Date("2005-01-01"), as.Date("2015-12-31"), by = "week"))

# Or the same day each month, if that is genuinely what you want
accessEnvDat(vars = "SST", bounding_box = bb,
             dates = seq(as.Date("2005-01-15"), as.Date("2015-12-15"), by = "month"))
```

Fetching dates is not the same as averaging a month. Three dates are a
sample of the month, carrying whatever weather fell on them; a monthly
mean is the month. Which you want depends on whether the observations
you are matching are themselves instants or aggregates.

Not everything is published daily. `PH`, `PP`, `DIATO` and `DINO` are
monthly composites only, and asking for them daily is refused before
anything is downloaded rather than failing at the API. Daily `CHL` comes
from the *gap-free* interpolated ocean colour dataset rather than the
monthly composite — its cloud gaps are already filled by Copernicus, so
`fill_satellite_gaps()` has nothing to do on it. `accessEnvDat()` says
so when it makes that substitution.

`variable_dataset(vars, frequency = "daily")` shows which dataset each
variable would come from, and `NA` where there is none.

### Downloads run in parallel

`n_workers` defaults to 4, so a fetch spanning many time steps downloads
several at once — a Copernicus request spends nearly all its time
waiting on the API rather than on your machine. Files already cached are
read from disk and start no workers at all, and a day that fails does
not abandon the others.

→ [Working with what comes
back](https://chross22.github.io/datamatch/articles/working-with-data.html#downloads-run-in-parallel)
has the timings and what raising it actually buys.

## Variable names

Copernicus variable codes are terse and easy to misremember. `thetao` is
temperature, `mlotst` is mixed layer depth, `zos` is sea surface height.
Get one wrong and you get a failed download rather than an obvious
mistake.

So you can request variables by name instead. The dictionary lists what
is available, and which product and dataset each comes from:

``` r
library(datamatch)

variable_dictionary()
#> Copernicus variables available by name
#> ------------------------------------------------------------------
#>  name      variable              label                                  
#>  SST       thetao                Sea surface temperature                
#>  SSS       so                    Sea surface salinity                   
#>  BOTT      bottomT               Bottom temperature                     
#>  BOTS      so                    Bottom salinity                        
#>  UO        uo                    Eastward current velocity              
#>  VO        vo                    Northward current velocity             
#>  SSH       zos                   Sea surface height                     
#>  MLD       mlotst                Mixed layer depth                      
#>  SIC       siconc                Sea ice concentration                  
#>  CHL       CHL                   Chlorophyll-a concentration (satellite)
#>  PP        PP                    Primary production (satellite)         
#>  DIATO     DIATO                 Diatom chlorophyll-a concentration     
#>  DINO      DINO                  Dinophyte chlorophyll-a concentration  
#>  NO3       no3                   Nitrate concentration                  
#>  PO4       po4                   Phosphate concentration                
#>  O2        o2                    Dissolved oxygen                       
#>  PH        ph                    pH                                     
#>  CHL_MODEL chl                   Chlorophyll-a concentration (model)    
#>  NPP_MODEL nppv                  Net primary production (model)         
#>  WSPD      wind_speed            Wind speed                             
#>  UWND      eastward_wind         Eastward wind                          
#>  VWND      northward_wind        Northward wind                         
#>  TAUX      eastward_stress       Eastward wind stress                   
#>  TAUY      northward_stress      Northward wind stress                  
#>  TAU       wind_stress_magnitude Wind stress magnitude                  
#>  units    
#>  degrees C
#>  PSU      
#>  degrees C
#>  PSU      
#>  m/s      
#>  m/s      
#>  m        
#>  m        
#>  fraction 
#>  mg/m3    
#>  mg/m2/day
#>  mg/m3    
#>  mg/m3    
#>  mmol/m3  
#>  mmol/m3  
#>  mmol/m3  
#>  unitless 
#>  mg/m3    
#>  mg/m3/day
#>  m/s      
#>  m/s      
#>  m/s      
#>  N/m2     
#>  N/m2     
#>  N/m2     
#> 
#> GLOBAL_MULTIYEAR_PHY_001_030
#>   variables: SST, SSS, BOTT, BOTS, UO, VO, SSH, MLD, SIC
#>   dataset:   cmems_mod_glo_phy_my_0.083deg_P1M-m
#>   docs:      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 
#> OCEANCOLOUR_GLO_BGC_L4_MY_009_104
#>   variables: CHL, PP, DIATO, DINO
#>   dataset:   cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M
#>              cmems_obs-oc_glo_bgc-pp_my_l4-multi-4km_P1M
#>   docs:      https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 
#> GLOBAL_MULTIYEAR_BGC_001_029
#>   variables: NO3, PO4, O2, PH, CHL_MODEL, NPP_MODEL
#>   dataset:   cmems_mod_glo_bgc_my_0.25deg_P1M-m
#>   docs:      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 
#> WIND_GLO_PHY_CLIMATE_L4_MY_012_003
#>   variables: WSPD, UWND, VWND, TAUX, TAUY, TAU
#>   dataset:   cmems_obs-wind_glo_phy_my_l4_P1M
#>   docs:      https://data.marine.copernicus.eu/product/WIND_GLO_PHY_CLIMATE_L4_MY_012_003/description
#> 
#> Pass a name to accessEnvDat(vars = ...), or the Copernicus code.
#> With every variable from one product, product_id and dataset_id can be
#> omitted - they are inferred from the names.
#> Full descriptions: as.data.frame(variable_dictionary())$description
```

`as_markdown()` renders either dictionary as a pipe table, for pasting
into documentation:

``` r
as_markdown(variable_dictionary())
```

| name | variable | label | units |
|----|----|----|----|
| SST | thetao | Sea surface temperature | degrees C |
| SSS | so | Sea surface salinity | PSU |
| BOTT | bottomT | Bottom temperature | degrees C |
| BOTS | so | Bottom salinity | PSU |
| UO | uo | Eastward current velocity | m/s |
| VO | vo | Northward current velocity | m/s |
| SSH | zos | Sea surface height | m |
| MLD | mlotst | Mixed layer depth | m |
| SIC | siconc | Sea ice concentration | fraction |
| CHL | CHL | Chlorophyll-a concentration (satellite) | mg/m3 |
| PP | PP | Primary production (satellite) | mg/m2/day |
| DIATO | DIATO | Diatom chlorophyll-a concentration | mg/m3 |
| DINO | DINO | Dinophyte chlorophyll-a concentration | mg/m3 |
| NO3 | no3 | Nitrate concentration | mmol/m3 |
| PO4 | po4 | Phosphate concentration | mmol/m3 |
| O2 | o2 | Dissolved oxygen | mmol/m3 |
| PH | ph | pH | unitless |
| CHL_MODEL | chl | Chlorophyll-a concentration (model) | mg/m3 |
| NPP_MODEL | nppv | Net primary production (model) | mg/m3/day |
| WSPD | wind_speed | Wind speed | m/s |
| UWND | eastward_wind | Eastward wind | m/s |
| VWND | northward_wind | Northward wind | m/s |
| TAUX | eastward_stress | Eastward wind stress | N/m2 |
| TAUY | northward_stress | Northward wind stress | N/m2 |
| TAU | wind_stress_magnitude | Wind stress magnitude | N/m2 |

Pass those names to `accessEnvDat()` and the result comes back with them
as column names, rather than the Copernicus codes:

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

**`product_id` and `dataset_id` can be omitted** when every variable is
in the dictionary. The catalog already knows where they live. Raw
Copernicus codes work the same way, so `vars = c("thetao", "so")` infers
its dataset too.

Variables from different datasets cannot be fetched in one request.
Mixing them is refused before anything is downloaded, rather than
failing obscurely at the API:

``` r
accessEnvDat(vars = c("SST", "CHL"), ...)
#> Error: These variables come from different Copernicus datasets and cannot be
#>   fetched together:
#>     SST  ->  cmems_mod_glo_phy_my_0.083deg_P1M-m
#>     CHL  ->  cmems_mod_glo_bgc_my_0.25deg_P1M-m
#>   Call accessEnvDat() once per dataset.
```

Existing calls need no change. Anything outside the dictionary is passed
through to the API with a warning, since Copernicus serves far more than
this catalog covers.

### Satellite or model?

Chlorophyll and primary production come from two very different places.
`CHL` and `PP` are Copernicus-GlobColour satellite retrievals —
observed, 4 km, and gappy under cloud. `CHL_MODEL` and `NPP_MODEL` are
the biogeochemistry reanalysis — gap-free and depth-resolved, but
simulated and coarser. The plain names default to satellite.

One caution: **satellite `PP` and model `NPP_MODEL` are not the same
quantity.** `PP` is depth-integrated (mg/m2/day), `NPP_MODEL` volumetric
(mg/m3/day).

→ [Choosing a data
source](https://chross22.github.io/datamatch/articles/sources.html#satellite-or-model)
covers the trade in full.

### Winds

Six wind variables come from the Copernicus L4 wind product —
scatterometer retrievals blended with an ECMWF model background. They
are fetched like anything else:

``` r
wind <- accessEnvDat(vars = c("WSPD", "UWND", "VWND", "TAU"),
                     years = 2003:2017, months = 1:12, bounding_box = bb)
```

| Name           | What it is                             | Units |
|----------------|----------------------------------------|-------|
| `WSPD`         | Wind speed at 10 m                     | m/s   |
| `UWND`, `VWND` | Eastward and northward wind components | m/s   |
| `TAUX`, `TAUY` | Eastward and northward wind stress     | N/m2  |
| `TAU`          | Wind stress magnitude                  | N/m2  |

**Wind is its own product on its own grid**, not part of the physics
reanalysis, so it is a separate call from `SST` — the usual rule. It is
0.25° monthly, about three times coarser than GLORYS, and runs from June
1994.

**Speed and stress are not the same covariate.** Stress is roughly
quadratic in speed, so it is what actually sets mixing and, through its
curl, Ekman pumping. If the question is about the ocean’s response to
wind rather than about the wind itself, `TAU` is usually the one to
reach for.

One subtlety in the monthly means: `WSPD` is averaged *as a speed*, so
it exceeds the magnitude of the mean vector wherever direction varied
within the month. A month of storms from every direction has a large
`WSPD` and a small `sqrt(UWND² + VWND²)`. Both are correct; they answer
different questions.

#### There is no daily wind

Copernicus publishes this wind monthly or hourly and **nothing
between**, so `frequency = "daily"` is refused for it rather than
quietly substituted. Fetch hourly and aggregate, which also leaves the
choice of summary with you:

``` r
hourly <- accessEnvDat(vars = c("UWND", "VWND"), frequency = "hourly",
                       dates = unique(observations$date), bounding_box = bb)

daily <- upscale_time(hourly, to = "day")                  # the day's mean
peak  <- upscale_time(hourly, to = "day", method = "max")  # its strongest hour
```

Hourly data carries an `HOUR` column, so a day is 24 rows per cell and
`matchData()` joins on the hour — which means observations need an hour
of their own, on UTC. A day is still one download, so hourly costs no
more requests than daily; it costs 24 times the rows.

Two limits worth knowing before planning around it. The hourly product
starts in **2007**, where the monthly one reaches back to 1994. And it
carries the vector components only — `WSPD` and `TAU` are magnitudes it
leaves to be computed, so both are monthly only.

Wind has no forecast, either. Copernicus publishes a near-real-time wind
analysis, but it is hourly only and reaches the present rather than past
it.

### Bottom salinity

`BOTS` costs a different amount depending on where it comes from.
GLORYS12V1 publishes no sea-floor salinity, so in reanalysis mode it is
**derived** — the full depth column is fetched and the deepest wet level
kept, which means it must be fetched on its own and returns a
`BOTS_depth` column. In forecast mode, and from FVCOM, HYCOM and their
sigma or bottom fields, it is an ordinary request.

→ [Choosing a data
source](https://chross22.github.io/datamatch/articles/sources.html#bottom-salinity-four-ways)
shows all four ways side by side.

## Spatial and temporal resolution

Products do not share a grid, so how resolution is handled matters:

| Source | Spatial | Temporal | Gaps |
|----|----|----|----|
| Physics reanalysis | 0.083° (~9 km) | monthly or daily, from 1993 | gap-free |
| Biogeochemistry reanalysis | 0.25° (~28 km) | monthly or daily, from 1993 | gap-free |
| Satellite ocean colour | 4 km | monthly, from 1997 | **cloud gaps** |
| Surface wind (Copernicus) | 0.25° monthly, 0.125° hourly | monthly from 1994, hourly from 2007; **no daily** | gap-free |
| CCMP wind | 0.25° | six-hourly, 1993 to the present | gap-free |
| FVCOM (NECOFS) | unstructured mesh | monthly 1978–2013; hourly 2025– | gap-free within the mesh |
| HYCOM | 0.08° | three-hourly, 1994–2024 across archives | occasional missing steps |
| Analysis-and-forecast | 0.083° / 0.25° | monthly or daily, to ~10 days ahead | gap-free |

Satellite is the finest source, and the only observed one. It is also
the only one with holes. Those holes are not random. They cluster in the
seasons and latitudes where cloud is persistent. `fill_satellite_gaps()`
substitutes the model equivalent where the satellite saw nothing, and
records the source of every value.

**`accessEnvDat()` fetches one dataset per call**, on that dataset’s
native grid. It does not resample, and it refuses to fetch variables
from different datasets together rather than quietly reconciling them.

**`matchData()` is resolution-agnostic.** Observations match to the
nearest environmental cell. So a 0.083-degree and a 0.25-degree product
both attach correctly to the same stations. The observation simply lands
in a bigger or smaller cell.

In time it matches at the environmental data’s own resolution, inferred
from its time steps. A monthly product matches by month, a daily one by
day. Matching a monthly mean on exact dates would match nothing, because
the mean carries one time step per month while observations fall on
arbitrary days.

**Combining two products onto one grid is the caller’s decision**,
because neither answer is free.

Keep the finer grid and each coarse cell’s value gets repeated across
the fine cells inside it. Fine-scale structure survives in the fine
variables, but the coarse one comes out blocky. A spatial gradient
computed from it measures the source grid, not the ocean.

Keep the coarser grid and nothing is repeated, but you throw away
resolution the fine variables really had. `taupatch` exposes this as a
`covariates.grid` setting.

`upscale_grid()` and `downscale_grid()` are how you act on that
decision.

## Forecasts

The same variables can be requested from the analysis-and-forecast
products, which run to about ten days ahead:

``` r
env <- accessEnvDat(
  vars = c("SST", "MLD"),
  years = 2026, months = 8,
  bounding_box = list(xmin = -76, xmax = -65, ymin = 35, ymax = 45),
  mode = "forecast"
)
```

Two differences from the reanalysis are worth knowing, and are why this
is a mapping rather than a swapped identifier:

- **The forecast splits variables across more datasets.** `SST` and
  `SSS` share a dataset in the reanalysis but not in the forecast, so a
  set that fetches in one request may need several.
- **Some codes differ.** Bottom temperature is `bottomT` in the
  reanalysis and `tob` in the forecast. Requesting `BOTT` gets the right
  one either way.

Satellite variables have no forecast — ocean colour is observation, and
there is no observation of the future. Asking for `CHL` in forecast mode
says so and points at `CHL_MODEL`.

## FVCOM, a regional model on an unstructured mesh

Copernicus is not the only source. `accessFVCOM()` reads NECOFS — the
Northeast Coastal Ocean Forecast System, built on FVCOM at UMass
Dartmouth — and returns the same shape of object, so everything
downstream works unchanged:

``` r
bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

fv <- accessFVCOM(vars = c("SST", "BOTT", "BOTS"), years = 2010:2013,
                  months = 1:12, bounding_box = bb)

matched <- matchData(observations, fv)
```

`fvcom_variables()` lists what is available, under the same names the
Copernicus catalog uses: `SST`, `SSS`, `BOTT`, `BOTS`, `SSH`, `UO`,
`VO`, `UBAR`, `VBAR`, `TAUX`, `TAUY`, plus `DEPTH`, `SWRAD` and `NHF`.

**Why reach for it.** It is a coastal model on a triangular mesh that
refines toward the shore. Over the box these examples use — -70 to -66
E, 41 to 44 N — GLORYS resolves 1,742 cells where GOM3 carries 6,579
nodes, concentrated where the bathymetry is complicated. If the question
is about the shelf rather than the basin, that resolution is the reason.

**Why not.** It is one regional model rather than a reanalysis
assimilating observations basin-wide, it stops at the mesh boundary, and
the hindcast **ends in 2013**. Most importantly:

> A covariate from FVCOM is **not interchangeable** with the same-named
> covariate from Copernicus, even though this returns it in a column of
> the same name. They are different models on different meshes. Say
> which you used.

### Bottom salinity is free here

FVCOM uses sigma coordinates — each of the 45 layers is a fixed
*fraction* of the local water column — so the deepest layer is the sea
floor at every node. `BOTS` is a layer index rather than the derivation
it takes against GLORYS. If bottom properties are the point, this is the
cheaper source for them.

The flip side is that a sigma layer is not a depth. Layer 45 sits at
98.9% of the local depth: a metre off the bottom on the shelf, fifty
metres off it in the Northeast Channel.

### Nodes and elements are two different sets of points

Scalars sit on mesh nodes; velocities and stresses sit on element
centroids — 48,451 and 90,415 of them on GOM3. So the two kinds cannot
be fetched together, and asking is an error rather than a silent
interpolation of one onto the other:

``` r
accessFVCOM(vars = c("SST", "UBAR"), ...)
#> Error: These variables sit on different parts of the FVCOM mesh and cannot be
#>   read together:
#>     SST  ->  nodes
#>     UBAR  ->  elements

# Two calls, chained - the same pattern as two Copernicus products
scalars  <- accessFVCOM(vars = c("SST", "BOTS"), years = 2010, months = 1:12,
                        bounding_box = bb)
currents <- accessFVCOM(vars = c("UBAR", "VBAR"), years = 2010, months = 1:12,
                        bounding_box = bb)

matched <- matchData(observations, scalars)
matched <- matchData(matched, currents)
```

### Monthly means only

The hindcast is published as hourly fields and as monthly means of them,
and only the monthly aggregation is offered — because the hourly one
cannot be opened at all. It carries 342,348 time steps, and `nc_open()`
reads the whole time coordinate before returning anything, so the
request for it exceeds the server’s DAP timeout. The failure takes over
ten minutes to arrive and says only `NetCDF: DAP failure`, which is why
this is documented rather than left to be discovered.

Sub-monthly FVCOM is therefore not a matter of passing a different
argument. It would mean reading the per-file datasets behind the
aggregation, a month at a time.

### Hindcast and forecast archive are two products

`fvcom_archives()` ships two NECOFS archives, and the second is **not**
a continuation of the first:

|             | `GOM3` (default) | `GOM7`                        |
|-------------|------------------|-------------------------------|
| Kind        | hindcast         | archived operational forecast |
| Mesh        | 48,451 nodes     | 207,081 nodes                 |
| Step        | monthly means    | hourly                        |
| Covers      | 1978–2013        | 2025–                         |
| Wind stress | yes              | **no**                        |

Three things change at once — the mesh, the step, and whether the output
is retrospective — so they are separate archives rather than one
stitched series. Between 2014 and 2024 this server publishes neither,
which is a gap in NECOFS rather than in this package.

`GOM7` is hourly, so `frequency` chooses what to take:

``` r
# One snapshot a day at 12 UTC - the default, because a month of hourly GOM7 is
# 720 reads of a 207,081-node field
daily <- accessFVCOM(vars = c("SST", "BOTS"), years = 2025, months = 6,
                     bounding_box = bb, archive = "GOM7")

# Every hour, when a real daily mean is wanted
steps <- accessFVCOM(vars = "SST", years = 2025, months = 6,
                     bounding_box = bb, archive = "GOM7", frequency = "hourly")
mean_sst <- upscale_time(steps, to = "day")
```

A snapshot is an instant, not a daily mean.

`fvcom_archives()` names what is built in: the GOM3 hindcast (monthly,
1978–2013) and the GOM7 forecast archive (hourly, 2025–), with nothing
between them. Reading it needs the `ncdf4` package, a `Suggests`, and a
network route to a plain-HTTP service on port 8080, which some
institutional networks block.

### Reading FVCOM from anywhere else

**FVCOM is a model, not a data product.** There is no global FVCOM
archive to point at. Groups run it for their own coastlines and publish
on their own servers, and what ships here is one server’s Northeast US
output — so the built-in list is a convenience, not the limit.

Any other FVCOM endpoint is reached by describing it once:

``` r
elsewhere <- fvcom_archive("http://example.org/thredds/dodsC/some_fvcom_run")

str(elsewhere)     # mesh size, period, and which fields that run actually saved

env <- accessFVCOM(vars = "SST", years = 2010, months = 1:12,
                   bounding_box = bb, archive = elsewhere)
```

This works because everything `accessFVCOM()` does depends on FVCOM’s
*structure* rather than on the region: values on mesh nodes and element
centroids, sigma layers, `lon`/`lat` and `lonc`/`latc`, an `Itime` day
count. What differs between deployments — the mesh, the period, which
fields were saved — is read from the file. `fvcom_archive()` opens the
endpoint once and reports all of it, so a URL that is wrong, blocked, or
not FVCOM fails there with the reason rather than part-way through a
fetch:

``` r
fvcom_archive("https://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_53.X/data/1994")
#> Error: This does not look like FVCOM output: it has no 'node' dimension.
```

One caution carries over: point it at an aggregation of *hourly* output
and it may not open at all, for the reason above. Prefer a monthly
aggregation, or a single file, over a long hourly one.

FVCOM is somebody else’s model, so cite it:

> Chen C, Beardsley RC, Cowles G (2006). An unstructured grid,
> finite-volume coastal ocean model (FVCOM) system. *Oceanography*
> **19**(1):78–89. <https://doi.org/10.5670/oceanog.2006.92>

## HYCOM, and bottom fields for free

`accessHYCOM()` reads HYCOM + NCODA GOFS 3.1 from the Naval Research
Laboratory’s THREDDS server. The default archive is the reanalysis
(`GLBv0.08` `expt_53.X`, 1994–2015); operational archives carry the
record to September 2024, and [Reaching past 2015](#reaching-past-2015)
covers the crossing:

``` r
bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

bottom <- accessHYCOM(vars = c("BOTT", "BOTS"), years = 2010, months = 1:12,
                      bounding_box = bb)

matched <- matchData(observations, bottom)
```

Two reasons to reach for it. HYCOM publishes **`salinity_bottom` and
`water_temp_bottom` as fields**, so `BOTS` costs nothing here — where
GLORYS12V1 has no bottom salinity at all and `accessEnvDat()` must
derive one from the full depth column. And it is an **independent
model**, so agreement between it and Copernicus is evidence about a
result in a way that either alone is not.

`hycom_variables()` lists what is available: `SST`, `SSS`, `BOTT`,
`BOTS`, `SSH`, `UO`, `VO`, plus `UO_BOTTOM` and `VO_BOTTOM`.

### Three-hourly, and no mean to fetch

HYCOM publishes instantaneous fields every three hours. There is no
daily or monthly mean in the archive, so this does not offer one:

| `frequency`         | Gives                                                |
|---------------------|------------------------------------------------------|
| `"daily"` (default) | one **snapshot** per day, at `hour` (default 12 UTC) |
| `"3hourly"`         | every step, with an `HOUR` column                    |

A snapshot is not a mean. A 12:00 UTC field on a tidal shelf sea is one
instant of that day. For a real mean, fetch the steps and aggregate —
which keeps the operation visible and the choice of summary yours:

``` r
steps <- accessHYCOM(vars = "SST", frequency = "3hourly",
                     dates = "2010-06-15", bounding_box = bb)

daily <- upscale_time(steps, to = "day")     # a genuine daily mean
```

### Reaching past 2015

The default archive is the **reanalysis** (`GLBv53X`, 1994–2015): one
internally consistent run, which is why it is the default. HYCOM
continues to the present, but as a chain of shorter **operational**
experiments — the model as it was running at the time:

``` r
hycom_covering("2019-06-15")
#> [1] "GLBv930" "GLBy930"

recent <- accessHYCOM(vars = c("BOTT", "BOTS"), dates = "2019-06-15",
                      bounding_box = bb, archive = "GLBy930")
```

Together they run 1994 → September 2024. One archive is read per call,
and a request falling outside the one named is told which others hold it
rather than being stitched to them silently — because the archives
overlap, so where two cover a date there is a real choice between the
more consistent run and the more recent one.

The seam that matters is the **run**, not the grid. Crossing from the
reanalysis into an operational archive changes how the values were
produced. The grids mostly agree: `GLBv0.08` and `GLBy0.08` hold the
same 126 latitudes between 40 and 45 °N, identically, so on a
mid-latitude shelf the cells line up across the seam. They diverge
toward the poles, where `GLBv0.08` stretches and `GLBy0.08` stays
uniform. (`GLBy0.08` also stores longitude 0–360 rather than −180…180 —
handled internally, so pass the box negative west either way.)

Two practical notes. **The archive has gaps** — some three-hourly steps
are simply absent, so a `"daily"` request at an hour that is missing
skips that day and warns. And **the first request against a year is
slow**, tens of seconds, because it opens that year’s dataset; later
days within the same year cost a second or two, and everything is
cached.

## CCMP, the long wind record

`accessCCMP()` reads the Cross-Calibrated Multi-Platform ocean surface
wind analysis from Remote Sensing Systems. No account is needed — the
registration RSS asks for covers their FTP service, and the HTTPS
archive is open:

``` r
bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

wind <- accessCCMP(vars = c("UWND", "VWND", "WSPD"),
                   dates = unique(observations$date), bounding_box = bb)

matched <- matchData(observations, wind)
```

It is the longest and finest-in-time wind record here — **six-hourly
from January 1993 to within days of the present**, where the Copernicus
L4 wind is monthly from mid-1994 or hourly only from 2007, with nothing
daily between:

|            | Copernicus L4                | CCMP v3.1               |
|------------|------------------------------|-------------------------|
| Record     | monthly 1994–, hourly 2007–  | six-hourly 1993–present |
| Grid       | 0.25° monthly, 0.125° hourly | 0.25°                   |
| Winds      | `WSPD`, `UWND`, `VWND`       | `WSPD`, `UWND`, `VWND`  |
| Stress     | `TAUX`, `TAUY`, `TAU`        | **none**                |
| Subsetting | server-side                  | **whole globe per day** |

The last two rows are the trade. **CCMP carries no wind stress**, and
stress — not speed — is what drives mixing and Ekman pumping. It cannot
be recovered from these winds without choosing a drag coefficient, which
is a modelling decision this package will not make for you. Where stress
is the covariate, use the Copernicus wind.

And **CCMP has no server-side subsetting**: RSS publishes static files,
so a day is one 33 MB global file however small the box. A year is
roughly 12 GB of transfer to keep a few megabytes. Subsets are cached,
so it is paid once, and a request for more than 30 days says what it is
about to download before starting.

`ccmp_variables()` lists the four: `WSPD`, `UWND`, `VWND` and `NOBS`.

`NOBS` is worth fetching alongside the winds when coverage is in doubt —
it counts the satellite retrievals behind each cell, and zero means the
value is the model background rather than an observation.

Like HYCOM, CCMP is an analysis at fixed hours with no mean in the
archive, so `frequency = "daily"` takes a snapshot at `hour` and
`"6hourly"` returns all four steps; `upscale_time(to = "day")` is how a
real mean is made.

> One trap handled for you: CCMP is stored on a **0–360 longitude
> grid**, alone among the sources here. Pass `bounding_box` negative
> west as everywhere else — it is converted on the way in, and the
> coordinates come back negative west, so the result overlays the other
> sources without adjustment.

## MUR and VIIRS, through ERDDAP

`accessERDDAP()` reads satellite products from NOAA’s ERDDAP servers —
**no account needed**, and subset server-side:

``` r
bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

sst <- accessERDDAP(vars = c("SST", "SST_ERROR"),
                    dates = unique(observations$date), bounding_box = bb)

matched <- matchData(observations, sst)
```

| Dataset         | Gives                     | Resolution  | Record          |
|-----------------|---------------------------|-------------|-----------------|
| `MUR` (default) | `SST`, `SST_ERROR`, `ICE` | 0.01° daily | 2002-06–        |
| `VIIRSCHL`      | `CHL`, gap-filled         | 0.04° daily | 2020-05–        |
| `VIIRSCHL2018`  | `CHL`, raw retrieval      | 0.04° daily | 2012-01–2022-07 |

**MUR is the finest field here by a wide margin** — 0.01° is about 1 km,
where the physics reanalysis is 9 km and GOM3’s mesh a few km on the
shelf. The same routing matters as elsewhere: these products are also at
PO.DAAC, where they need an Earthdata login; ERDDAP serves them openly,
so there are no credentials for this package to handle or for you to
configure.

Three things to know:

- **A satellite SST is not a model SST.** MUR measures the *foundation*
  temperature, below the daily warming layer; a model `SST` is its
  topmost level. On a calm sunny afternoon they differ by a degree or
  more. Both arrive in a column called `SST`, which is why `matchData()`
  records `<var>_source`.
- **MUR is gap-free by construction.** It is an analysis, so cloud is
  interpolated over rather than left `NA` — fetch `SST_ERROR` alongside
  if that interpolation matters. `VIIRSCHL` is likewise DINEOF
  gap-filled; `VIIRSCHL2018` is the raw retrieval and is gappy under
  cloud, which is what
  [`fill_satellite_gaps()`](https://chross22.github.io/datamatch/articles/working-with-data.html#filling-satellite-gaps)
  is for.
- **There is no global VIIRS SST here.** The VIIRS SST on these servers
  covers the US West Coast only. MUR is the SST to use instead — it is a
  blended analysis taking VIIRS among its inputs, at finer resolution
  and over a longer record.

`erddap_datasets()` lists what ships and `erddap_dictionary()` tabulates
the variables. ERDDAP hosts thousands more;
`erddap_dataset(server, dataset_id)` describes any of them for
`accessERDDAP()`, the same way `fvcom_archive()` does for FVCOM.

## Working with what comes back

Everything an access function returns is the same shape, so the same
tools apply whichever source produced it: resampling between grids and
time steps, filling satellite gaps, and looking at what arrived.

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

Two rules worth carrying even if you read no further. **Aggregating
loses detail, which is the safe direction; interpolating adds cells, not
information** — so the defaults are the blunt methods that look like
what they are. And **`linear` and `spline` do not preserve the period
mean**, so a budget computed from an interpolated series inherits that
error; `step` does preserve it.

→ [**Working with what comes
back**](https://chross22.github.io/datamatch/articles/working-with-data.html)
covers the methods, when each is right, `min_coverage`, and what each
plot is for.

## Static and basin-scale covariates

Two kinds of covariate are not gridded fields on a time step, and
neither is attached with `matchData()`:

``` r
bathy <- fetch_bathymetry(bounding_box = bb)
observations <- attach_bathymetry(observations, bathy, c("DEPTH", "SLOPE", "TPI"))

observations <- attach_climate_index(observations, c("NAO", "AMO"))
```

**Seafloor terrain** — `DEPTH`, `SLOPE`, `ASPECT`, `TPI` from NOAA ETOPO
— does not vary in time, so it is fetched once and attached to every
step. **Climate indices** — `NAO`, `AO`, `AMO`, `PDO`, `LCR`, `AMOC` —
have no spatial dimension at all: one value describes the whole basin in
a month, so they tell you about *when*, never about *where*.

`bathymetry_variables()` and `index_dictionary()` list what is
available.

→ [**Static and basin-scale
covariates**](https://chross22.github.io/datamatch/articles/covariates.html)
covers what TPI actually measures, which index to choose and why they
are not interchangeable, the `LCR` and `AMOC` caveats, and how the index
cache expires on each provider’s publishing cadence.

## Depositing what you made

`write_eml()` writes [Ecological Metadata
Language](https://eml.ecoinformatics.org/) for a matched table — the
standard EDI, LTER and DataONE expect alongside a deposited dataset:

``` r
write_eml(
  matched, "matched.xml",
  title = "Bottom conditions at trawl stations, Gulf of Maine",
  creator = list(individualName = list(givenName = "Camille", surName = "Ross"),
                 userId = list(directory = "https://orcid.org",
                               userId = "0000-0002-1428-2294")),
  abstract = "Survey stations with environmental covariates matched by datamatch."
)
```

Most of the document is filled in from the data: the bounding box and
date range from the object itself, and an attribute for every column
with its definition, units and measurement scale taken from whichever
source catalog defines that name.

The part worth having is the **methods section**. Because `matchData()`
records `<var>_source` on every join, a table with four sources chained
onto it produces a methods statement naming all four and a citation for
each — which is otherwise the most tedious part of depositing a derived
dataset, and the easiest to get wrong. `title`, `creator` and `abstract`
are yours to supply; nothing else needs to be.

> One detail that would otherwise bite at submission rather than at
> write time: EML validates units against a fixed vocabulary, and
> **`PSU` and `N/m²` are not in it**. Both are written as custom units
> and declared in the document’s own `unitList`, so what comes out
> validates. `write_eml()` checks that before returning.

Needs the `emld` package, a `Suggests`.

## Putting it together

A worked example: physical, biological, seafloor, and basin-scale
covariates onto one table of species observations. The whole thing is a
pipeline of joins. Each step adds columns and never changes the number
of rows.

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

    YEAR MONTH count   SST   SSS   MLD   CHL   NO3  DEPTH  SLOPE    TPI   NAO   LCR
    2010     1     2  6.41 32.80  84.2  0.84  4.12  105.5   1.83   77.2  0.31  0.05
    2010     1     1  5.98 32.94  91.7  0.79  4.55  294.7   0.42 -114.7  0.31  0.05

Three things about this that are worth understanding rather than
copying.

**The two `accessEnvDat()` calls are not an inconvenience to work
around.** `SST` and `CHL` live in different datasets on different grids:
0.083° for the physics, 0.25° for the biogeochemistry. The package
refuses to fetch them together rather than quietly reconciling two grids
on your behalf. `matchData()` then handles both correctly, because it
matches to the nearest cell whatever its size.

**`matchData()` chains.** Its output is an `sf` object with the same
time columns it consumed. So you can feed it back in for the next
dataset, and the row count is preserved. Order does not matter.

**The joins fail in different ways.** `matchData()` warns and fills `NA`
when an observation falls in a period the environmental data does not
cover. `attach_climate_index()` gives `NA` outside the index’s record,
which for `LCR` means anything after 2014. Check for both before
modelling:

``` r
colSums(is.na(sf::st_drop_geometry(matched)))
```

You may want everything on a common grid instead, to model the field
itself rather than the observations. Regrid first, then match:

``` r
phys_coarse <- upscale_grid(phys, to = bio)    # 0.083° onto the 0.25° BGC grid
```

## Matching

`matchData(dat, source)` joins each row of `dat` to the nearest feature
of `source` within the same time period, and returns `dat` with
`source`’s columns added.

``` r
matched <- matchData(observations, env)
```

**Neither side has to be observations or environmental data.** It is a
spatiotemporal nearest-feature join between two `sf` point objects
carrying `YEAR`/`MONTH`/`DAY`, so it works equally for stations against
a covariate grid, tag positions against a model field, moorings against
satellite retrievals, or one gridded product against another. The
arguments are named `dat` and `source` for that reason.

Matching happens at **`source`’s** temporal resolution, inferred from
its time steps. That matters for monthly products: a monthly mean
carries one time step per month while observations fall on arbitrary
days, so matching on exact dates would match nothing. Pass
`temporal_resolution` to override.

Rows falling in a period `source` does not cover are returned with `NA`
and a warning naming the periods, rather than being dropped silently.
One row out per row in, always. A `source` column whose name collides
with one already in `dat` is suffixed `.matched`, so nothing of yours is
overwritten.

> The arguments used to be `speciesDat` and `envDat`. Those still work
> and warn; they will be removed in a later version.

## Function reference

Everything the package exports, in the order you would meet it. The
[pkgdown
site](https://chross22.github.io/datamatch/reference/index.html) has a
page for each.

**Fetching** — five sources, one shape out

|  |  |
|----|----|
| `accessEnvDat()` | Copernicus Marine: physics, biogeochemistry, ocean colour, wind |
| `accessFVCOM()` | FVCOM / NECOFS on an unstructured mesh |
| `accessHYCOM()` | HYCOM GOFS 3.1, with sea-floor fields |
| `accessCCMP()` | CCMP six-hourly surface winds |
| `accessERDDAP()` | MUR SST and VIIRS chlorophyll, via NOAA ERDDAP |

**Matching**

|  |  |
|----|----|
| `matchData()` | the spatiotemporal nearest-feature join |
| `source_of()` | which source and archive an object came from |
| `write_eml()` | EML metadata for a matched table, for depositing it |
| `covariate_columns()` | which columns are data rather than time or provenance |

**Resampling and gap filling**

|  |  |
|----|----|
| `upscale_grid()`, `downscale_grid()` | between spatial grids |
| `upscale_time()`, `downscale_time()` | between time steps |
| `fill_satellite_gaps()` | substitute a model where the satellite saw nothing |
| `grid_resolution()` | the spacing of a grid, for deciding which way to go |

**Plotting**

|                   |                                                  |
|-------------------|--------------------------------------------------|
| `plot_env()`      | a map of one variable at one time step           |
| `plot_coverage()` | the fraction of cells carrying a value, per step |
| `plot_series()`   | the study area reduced to a series               |
| `plot_matched()`  | what the join produced, including what missed    |

**Other covariates**

|  |  |
|----|----|
| `fetch_bathymetry()`, `attach_bathymetry()`, `bathymetry_variables()` | seafloor terrain |
| `fetch_climate_index()`, `attach_climate_index()`, `climate_indices()`, `index_dictionary()` | basin-scale indices |
| `climate_index_status()`, `refresh_climate_index()` | what is cached, and forcing a re-fetch |

**Catalogs** — what each source offers, and how to reach one it does not
ship

|  |  |
|----|----|
| `variable_dictionary()`, `copernicus_variables()`, `variable_dataset()`, `forecast_variables()`, `product_url()` | Copernicus |
| `fvcom_variables()`, `fvcom_dictionary()`, `fvcom_archives()`, `fvcom_archive()` | FVCOM |
| `hycom_variables()`, `hycom_dictionary()`, `hycom_archives()`, `hycom_covering()` | HYCOM |
| `ccmp_variables()`, `ccmp_dictionary()`, `ccmp_versions()` | CCMP |
| `erddap_datasets()`, `erddap_dictionary()`, `erddap_dataset()` | ERDDAP |
| `as_markdown()` | render any dictionary as a pipe table |

The `_dictionary()` functions print as tables and are what to read; the
plain catalog functions return lists and are what to write code against.
`fvcom_archive()`, `erddap_dataset()` and `hycom_covering()` are the
escape hatches — the first two reach any endpoint the package does not
ship, the third says which HYCOM archive holds a given date.

## Vignettes

The README is orientation. The detail lives in four articles:

|  |  |
|----|----|
| [Getting started](https://chross22.github.io/datamatch/articles/datamatch.html) | observations to a modelling table, end to end |
| [Choosing a data source](https://chross22.github.io/datamatch/articles/sources.html) | which of the five to reach for, and what changes when you do |
| [Working with what comes back](https://chross22.github.io/datamatch/articles/working-with-data.html) | resampling, gap filling, and looking at the data |
| [Static and basin-scale covariates](https://chross22.github.io/datamatch/articles/covariates.html) | seafloor terrain and climate indices |

## Troubleshooting

Errors you might hit, and what they mean.

**`Could not find the Copernicus Marine client`**

R cannot see `copernicusmarine` on its `PATH`. Common when it lives in a
conda environment that RStudio does not inherit. Point at it directly:

``` r
options(datamatch.copernicusmarine = "~/miniconda3/bin/copernicusmarine")
```

**`These variables come from different Copernicus datasets`**

Expected, not a fault. `SST` is physics and `CHL` is biogeochemistry, on
different grids. Fetch them separately and chain `matchData()`, as in
[One call per product](#one-call-per-product). `variable_dataset()`
shows which dataset each variable comes from.

In forecast mode this happens more often, because the forecast products
split variables across more datasets than the reanalysis does. `SST` and
`UO` share a dataset as reanalysis but not as forecast.

**`Copernicus publishes no daily dataset for: UWND, VWND`**

Expected. This wind is published hourly or monthly and nothing between.
Fetch `frequency = "hourly"` and aggregate with
`upscale_time(to = "day")`, as in [There is no daily
wind](#there-is-no-daily-wind). The same message for `PH`, `PP`, `DIATO`
or `DINO` means the opposite — those are monthly composites, so fetch
them monthly.

**`Copernicus publishes no hourly dataset for: WSPD`**

`WSPD` and `TAU` are magnitudes the hourly wind product does not carry.
Fetch `UWND` and `VWND` hourly and compute the magnitude, or take these
monthly.

**`BOTS must be fetched on its own`**

Bottom salinity is derived from the whole depth column, which is a
different request from the single level a surface variable wants. Call
`accessEnvDat()` once for `BOTS` and once for the rest, then chain
`matchData()`. See [Bottom salinity](#bottom-salinity).

**`The download did not return: uo, vo`**

Those variables were requested but are not in the returned file. Either
the dataset does not serve them, or they are unavailable at the
requested depth or date. The message lists what did arrive.

**`The depth range returned several model levels`**

`depth` spanned more than one model level, so a variable came back on
several layers and there is no way to know which was wanted. Request a
single level with `depth = c(0, 1)`.

**`Copernicus download failed after 3 attempt(s)`**

The request was retried and kept failing. The message carries the
client’s own output. Rapid repeated downloads can also be rate-limited,
in which case waiting and re-running works.

**`Expected N variable column(s) but the download returned M`**

From a version before the layer-matching fix. Update the package: this
message blamed the depth range for causes it could not distinguish, and
the two real ones now report themselves. See `NEWS.md`.

**Values in the wrong range for their column name**

Salinity around 32 in an `SST` column means you are on a version
predating the layer-ordering fix, where multi-variable downloads could
be mislabelled silently. Update and re-fetch. `NEWS.md` describes what
was affected and how to check.

## Related packages

- [derivoce](https://github.com/chross22/derivoce) — derived covariates
  (gradients, FTLE/FSLE, front and isobath distances, lags, integrals)
  computed from what `accessEnvDat()` returns

## References

Everything datamatch returns comes from someone else’s data, and the
obligation to cite travels with the data rather than with this package.
`index_dictionary()` carries the references for the indices at runtime,
and `variable_dictionary()` links to each Copernicus product page.

**Cite whichever of these you actually used.**

### Copernicus Marine Service

[Copernicus asks for a specific
form](https://help.marine.copernicus.eu/en/articles/4444611-how-to-cite-copernicus-marine-products-and-services),
including the access date:

> *Product Title*. E.U. Copernicus Marine Service Information (CMEMS).
> Marine Data Store (MDS). DOI: 10.48670/moi-xxxxx (Accessed on DD MMM
> YYYY)

Reanalysis products, used by default:

| Product | Supplies | DOI |
|----|----|----|
| Global Ocean Physics Reanalysis (GLORYS12V1) | `SST`, `SSS`, `BOTT`, `BOTS`, `UO`, `VO`, `SSH`, `MLD`, `SIC` | [10.48670/moi-00021](https://doi.org/10.48670/moi-00021) |
| Global Ocean Biogeochemistry Hindcast | `CHL_MODEL`, `NPP_MODEL`, `NO3`, `PO4`, `O2`, `PH` | [10.48670/moi-00019](https://doi.org/10.48670/moi-00019) |
| Global Ocean Colour (Copernicus-GlobColour) | satellite `CHL`, `PP`, `DIATO`, `DINO` | [10.48670/moi-00281](https://doi.org/10.48670/moi-00281) |
| Global Ocean Monthly Mean Sea Surface Wind and Stress | `WSPD`, `UWND`, `VWND`, `TAUX`, `TAUY`, `TAU` | [10.48670/moi-00181](https://doi.org/10.48670/moi-00181) |
| Global Ocean Hourly Reprocessed Sea Surface Wind and Stress | the same, with `frequency = "hourly"` | [10.48670/moi-00185](https://doi.org/10.48670/moi-00185) |

`BOTS` is derived from GLORYS’s salinity field rather than published by
it, so it carries that product’s citation like any other variable taken
from it.

The two wind products are separate records with separate DOIs. A study
using monthly wind cites the first; one using hourly wind, or a daily
field aggregated from it, cites the second.

Analysis-and-forecast products, used with `mode = "forecast"`:

| Product | DOI |
|----|----|
| Global Ocean Physics Analysis and Forecast | [10.48670/moi-00016](https://doi.org/10.48670/moi-00016) |
| Global Ocean Biogeochemistry Analysis and Forecast | [10.48670/moi-00015](https://doi.org/10.48670/moi-00015) |

`variable_dataset()` says which product a variable came from, so only
the ones you used need citing. Downloads go through the [Copernicus
Marine Toolbox](https://toolbox-docs.marine.copernicus.eu/), which
publishes no DOI of its own — cite the products.

### Ocean and wind models

Each is somebody else’s work, and `fvcom_archives()`, `hycom_archives()`
and `ccmp_versions()` carry these references at runtime:

- **FVCOM / NECOFS** — Chen C, Beardsley RC, Cowles G (2006). An
  unstructured grid, finite-volume coastal ocean model (FVCOM) system.
  *Oceanography* **19**(1):78–89.
  <https://doi.org/10.5670/oceanog.2006.92>

- **HYCOM / GOFS 3.1** — Chassignet EP, Hurlburt HE, Smedstad OM,
  Halliwell GR, Hogan PJ, Wallcraft AJ, Baraille R, Bleck R (2007). The
  HYCOM (HYbrid Coordinate Ocean Model) data assimilative system.
  *Journal of Marine Systems* **65**:60–83.
  <https://doi.org/10.1016/j.jmarsys.2005.09.016>

- **CCMP** — Mears C, Lee T, Ricciardulli L, Wang X, Wentz F (2022).
  Improving the Accuracy of the Cross-Calibrated Multi-Platform (CCMP)
  Ocean Vector Winds. *Remote Sensing* **14**(17):4230.
  <https://doi.org/10.3390/rs14174230>

- **MUR** — Chin TM, Vazquez-Cuervo J, Armstrong EM (2017). A
  multi-scale high-resolution analysis of global sea surface
  temperature. *Remote Sensing of Environment* **200**:154–169.
  <https://doi.org/10.1016/j.rse.2017.07.029>

- **VIIRS gap-filled chlorophyll** — Liu X, Wang M (2018). Gap filling
  of missing data for VIIRS global ocean color products using the DINEOF
  method. *IEEE Transactions on Geoscience and Remote Sensing*
  **56**:4464–4476. <https://doi.org/10.1109/TGRS.2018.2820423>

Say which archive as well as which model — a value from the HYCOM
reanalysis and one from an operational experiment are not the same run,
and `source_of()` records exactly that.

### Seafloor terrain

- NOAA National Centers for Environmental Information (2022). *ETOPO
  2022 15 Arc-Second Global Relief Model*.
  <https://doi.org/10.25921/fd45-gt74>
- Pante E, Simon-Bouhet B, Irisson J (2025). *marmap: Import, Plot and
  Analyze Bathymetric and Topographic Data*.
  <https://doi.org/10.32614/CRAN.package.marmap>

`fetch_bathymetry()` requests the 60 arc-second bedrock grid
(`ETOPO_2022_v1_60s_bed`) through `marmap`.

### Climate indices

Two are the published output of specific work and **should be cited when
used**:

- **`LCR`** — Jutras M, Dufour CO, Mucci A, Talbot LC (2023).
  Large-scale control of the retroflection of the Labrador Current.
  *Nature Communications* **14**:2623.
  <https://doi.org/10.1038/s41467-023-38321-y>

- **`AMOC`** — Moat BI, Smeed DA, Rayner D, Johns WE, Smith R, Volkov D,
  Elipot S, Petit T, Kajtar J, Baringer MO, Collins J (2026). *Atlantic
  meridional overturning circulation observed by the RAPID-MOCHA-WBTS
  array at 26°N from 2004 to 2024 (v2024.1a)*. British Oceanographic
  Data Centre, NERC, UK.
  <https://doi.org/10.5285/48d0bf43-0598-ceb2-e063-7086abc062f1>

  BODC mints a new DOI for each release and retires the old one, so this
  changes when RAPID publishes a new version. `index_dictionary()`
  carries the current reference.

The other four are operational products with no single paper behind
them. Credit the provider:

- **`NAO`**, **`AO`** — NOAA Climate Prediction Center.
  <https://www.cpc.ncep.noaa.gov/>
- **`AMO`**, **`PDO`** — NOAA Physical Sciences Laboratory.
  <https://psl.noaa.gov/data/climateindices/>

### Software this is built on

- Pebesma E, Bivand R (2023). *Spatial Data Science: With Applications
  in R*. Chapman and Hall/CRC. <https://doi.org/10.1201/9780429459016> —
  the `sf` reference
- Hijmans R, Brown A, Barbosa M (2026). *terra: Spatial Data Analysis*.
  <https://doi.org/10.32614/CRAN.package.terra>
- Pierce D (2025). *ncdf4: Interface to Unidata netCDF Format Data
  Files*. <https://doi.org/10.32614/CRAN.package.ncdf4> — needed for
  `AMOC`

`citation("datamatch")` gives this package’s own entry, and `citation()`
works on any of the above.

### Keeping these current

Citations go stale without anyone touching them. Data centres reissue a
DOI when a record is superseded and retire the old one, so a reference
that was correct when written stops resolving on its own. The `AMOC`
entry here has already been through that once, when BODC published a
newer RAPID release.

Two scheduled workflows watch for it, and open an issue rather than
editing anything, since choosing a replacement is a judgement about
which version to track:

- **Citation check**, quarterly, resolves every DOI cited in the README,
  the catalogs, and `NEWS.md`.
- **Copernicus catalog check**, monthly, compares the variable catalog
  against the live Copernicus catalogue, since dataset identifiers are
  revised too.

Both run on demand from the Actions tab, and locally:

``` r
# from the package root
system("Rscript inst/scripts/check_citations.R")
system("Rscript inst/scripts/check_catalog.R")
```

## Citing datamatch

``` r
citation("datamatch")
```

The data products a run fetches carry their own citations; the
References section above says which, and each function’s `?help` repeats
it.
