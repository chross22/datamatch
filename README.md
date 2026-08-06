---
output: github_document
---

<!-- README.md is generated from README.Rmd. Please edit that file -->



# datamatch

<!-- badges: start -->
[![R-CMD-check](https://github.com/chross22/datamatch/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/chross22/datamatch/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of datamatch is to pull environmental data from Copernicus Marine Service and match spatially and temporally to species occurence data.

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

If the client is installed but R cannot find it — common when it lives in a
conda environment that RStudio does not inherit the `PATH` of — point at it
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

matched <- matchData(speciesDat = observations, envDat = env)
```

`variable_dictionary()` lists what is available.

## Variable names

Copernicus variable codes are terse and easy to misremember — `thetao` for
temperature, `mlotst` for mixed layer depth, `zos` for sea surface height — and
getting one wrong produces a failed download rather than an obvious mistake. So
variables can be requested by name instead, and the dictionary lists what is
available, along with the product and dataset each comes from:


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
dictionary, since the catalog already knows where they live. Raw Copernicus
codes work the same way, so `vars = c("thetao", "so")` infers its dataset too. Variables from
different datasets cannot be fetched in one request, and mixing them is refused
before any download is attempted rather than failing obscurely at the API:


``` r
accessEnvDat(vars = c("SST", "CHL"), ...)
#> Error: These variables come from different Copernicus datasets and cannot be
#>   fetched together:
#>     SST  ->  cmems_mod_glo_phy_my_0.083deg_P1M-m
#>     CHL  ->  cmems_mod_glo_bgc_my_0.25deg_P1M-m
#>   Call accessEnvDat() once per dataset.
```

Raw Copernicus codes still work exactly as before, so existing calls need no
change, and anything outside the dictionary is passed through to the API with a
warning — Copernicus serves far more than this catalog covers.

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
| Physics reanalysis | 0.083° (~9 km) | monthly, from 1993 | gap-free |
| Biogeochemistry reanalysis | 0.25° (~28 km) | monthly, from 1993 | gap-free |
| Satellite ocean colour | 4 km | monthly, from 1997 | **cloud gaps** |
| Analysis-and-forecast | 0.083° / 0.25° | monthly, to ~10 days ahead | gap-free |

Satellite is the finest and the only observed source, but it is also the only
one with holes — and those holes are not random, clustering in the seasons and
latitudes where cloud is persistent. `fill_satellite_gaps()` substitutes the
model equivalent where the satellite saw nothing, and records the source of
every value.

**`accessEnvDat()` fetches one dataset per call**, on that dataset's native grid.
It does not resample, and it refuses to fetch variables from different datasets
together rather than quietly reconciling them.

**`matchData()` is resolution-agnostic.** Observations are matched to the nearest
environmental cell, so a 0.083-degree and a 0.25-degree product each attach
correctly to the same stations — the observation simply lands in a bigger or
smaller cell. Temporally it matches at the environmental data's own resolution,
inferred from its time steps: a monthly product matches by month, a daily one by
day. Matching a monthly mean on exact dates would match nothing, since the mean
carries one time step per month while observations fall on arbitrary days.

**Combining two products onto one grid is the caller's decision**, because
neither answer is free. Keeping the finer grid means each coarse cell's value is
repeated across the fine cells inside it: fine-scale structure survives in the
fine variables, but the coarse one is blocky rather than detailed, and a spatial
gradient computed from it measures the source grid rather than the ocean. Keeping
the coarser grid replicates nothing but discards resolution the fine variables
really had. `taupatch` exposes this as a `covariates.grid` setting.

`upscale_grid()` and `downscale_grid()` are how you act on that decision.

## Resampling

Four functions, one pair per axis. Each takes a `method`, because there is no
single right way to change resolution:

| | Coarser | Finer |
|---|---|---|
| **Space** | `upscale_grid()` | `downscale_grid()` |
| **Time** | `upscale_time()` | `downscale_time()` |


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

The target is either a resolution or **another object whose grid to adopt** —
the second form is what puts two products on one grid. A resolution is anchored
to the origin rather than to your data's corner, so two products upscaled to
0.25° land on the *same* cells instead of half a cell apart.

### Aggregating loses detail, which is the safe direction

`mean` is the default. The others exist because "the value of this coarse cell"
is not one question: `median` resists the retrieval outliers at satellite cloud
edges, `min` of depth is the shallowest point a cell contains rather than its
average, `sum` is for per-cell totals and meaningless for a concentration, and
`sd` over a period is variability as a covariate in its own right. Pass one
method for everything, or a named vector per variable:


``` r
upscale_grid(env, to = 0.25, method = c(CHL = "median", DEPTH = "min"))
```

**Partly-covered periods and cells come back `NA` by default.** A mean over the
four days of January you happened to fetch is not a January mean, and nothing in
the number itself says so. `min_coverage` defaults to 0.5, measured against the
steps a period *has* — 31 for January — not the steps that were downloaded. Set
`min_coverage = 0` to aggregate whatever is present, and `keep_counts = TRUE` to
see what was behind each value.

### Interpolating adds cells, not information

This is the direction to be careful in. A 0.25° field rendered at 4 km has 4 km
*cells*, but it still resolves nothing below 0.25°, and none of these methods
consult any other data source — so there is nowhere for real fine-scale
structure to come from.

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

`idw` is the exception worth reaching for: alone among the spatial methods it
fills across holes rather than propagating them, which makes it useful on gappy
satellite data where `fill_satellite_gaps()` is not an option.

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

The two sources are different measurements of the same quantity, not
interchangeable ones, so the seam is left visible rather than smoothed: nothing
is rescaled by default, and a `<var>_source` column records where each value came
from. `rescale = TRUE` matches the model's mean and variance to the satellite's
over the cells where both exist, which reduces the step at the cost of altering
the model values.

## Looking at the data

Four plots, in the order they are usually wanted. All use base graphics, so they
need no extra packages, and each returns the data it drew so the numbers behind a
picture are always available.


``` r
env <- accessEnvDat(vars = c("SST", "CHL"), years = 2010, months = 1:12,
                    bounding_box = bb)

plot_env(env)                                # first variable, first time step
plot_env(env, "CHL", time = c(MONTH = 6))    # June chlorophyll
```

`plot_env()` maps one variable for one time step. It is the first thing worth
doing after a download and the fastest way to catch a bounding box that came out
somewhere unintended, a variable that is entirely `NA`, or a depth range that
returned the wrong level. Data are drawn as a raster, so gaps read as holes
rather than as absent dots. The time step is named in the title, so a map is
never ambiguous about which month it shows.


``` r
plot_coverage(env)
```

`plot_coverage()` is the one to run before trusting a satellite series. It plots
the fraction of cells carrying a value in each time step, and on ocean colour the
shape is stark: near-complete in summer, a quarter of the grid in winter. That
picture is what decides whether a monthly mean is worth having, whether
`fill_satellite_gaps()` is worth the seam it introduces, and where to set
`min_coverage` when aggregating.


``` r
plot_series(env)                     # one panel per variable
plot_series(env, "SST", fun = max)   # the warmest cell each month
```

`plot_series()` reduces each time step to one number over the study area, which
is how a seasonal cycle, a trend, or a step change at a product boundary becomes
visible. The interquartile range across cells is shaded behind the line, because
a mean alone hides the difference between a uniformly warm month and one that is
warm inshore and cold offshore.


``` r
matched <- matchData(speciesDat = observations, envDat = env)

plot_matched(matched[matched$MONTH == 7, ], "SST")
```

`plot_matched()` shows what the join actually produced. Observations that matched
nothing are drawn as open circles rather than dropped — a cluster of them is
usually the real finding, marking observations outside the environmental data's
extent or in a period it does not cover.

Subset to one period first, as above. The colour scale spans everything passed
in, so plotting a whole year of a seasonal variable mixes the seasons together
and the map reads as noise: a warm February inshore point and a cool August
offshore one can take the same colour.

## Static and basin-scale covariates

Not everything useful is a gridded Copernicus variable on a monthly time step.
Two other kinds are available, and they behave differently from the Copernicus
data and from each other.

### Seafloor terrain

Static — it does not vary by month or year — so it is fetched once for a study
area and attached to every time step. Sourced from NOAA ETOPO via `marmap`,
which is a suggested package rather than a hard dependency:


``` r
bathy <- fetch_bathymetry(
  bounding_box = list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
)

observations <- attach_bathymetry(observations, bathy, c("DEPTH", "SLOPE", "TPI"))
```

`bathymetry_variables()` lists them: `DEPTH`, `SLOPE`, `ASPECT`, and `TPI`.

`TPI` — topographic position index — is a cell's depth relative to the mean of
the eight around it, and it answers a question depth cannot. A 100 m bank top
and a 100 m basin floor are the same depth and very different places; TPI is
positive on the first and negative on the second, and near zero on both flat
bottom and uniform slopes. It is scale-dependent by construction, describing
position within the immediate neighbourhood, so its meaning follows the
resolution of the grid it was computed on.

`attach_bathymetry()` takes either a plain data frame with coordinate columns or
an `sf` object, so it works on observations and on `accessEnvDat()` output alike.

### Climate indices

Monthly, and with **no spatial dimension** — one value describes the whole basin,
so every observation in a month receives the same number:


``` r
observations <- attach_climate_index(observations, c("NAO", "AMO"))

index_dictionary()          # NAO, AO, AMO, PDO, LCR
```

That makes them a different kind of covariate from local temperature. They carry
information about *when* — what year and season it was — and none about *where*
within a region conditions are better. Useful for interannual questions ("was
this a warm-regime year?"), useless for spatial ones: a model given only indices
cannot produce a map.

#### The Labrador Current retroflection index

`LCR` is the odd one out and often the most directly useful of the five. The
other four are atmospheric patterns; this one describes a *current* — how much
of the Labrador Current turns eastward at the Grand Banks instead of continuing
southwest along the shelf. Positive values mean stronger retroflection, so less
cold, fresh, oxygen-rich Labrador water reaching the Scotian Shelf and Gulf of
Maine. For shelf water properties that is a shorter causal chain than the NAO.


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

Two limits worth knowing. It **covers 1993–2014 only**, so it cannot be attached
to recent observations. And the series is fetched from the paper's published
source data rather than recomputed — the authors derived it by tracking virtual
particles through GLORYS12V1 with
[OceanParcels](https://oceanparcels.org/), which is a Lagrangian modelling
exercise rather than something this package reproduces. Extending the record
past 2014 means redoing that computation, not calling a different function.

One interaction to know: `attach_climate_index()` joins on year and month, and
`upscale_time(to = "year")` stamps its output `MONTH = 1`. Attaching an index to
annual data would therefore give every year January's value. Aggregate the index
to a year first instead.

## Matching to observations

`matchData()` joins environmental data to species observations at the
environmental data's own temporal resolution, inferred from its time steps. This
matters for monthly products: a monthly mean carries one time step per month
while observations fall on arbitrary days, so matching on exact dates would
match nothing.


``` r
matched <- matchData(speciesDat = observations, envDat = env)
```

Observations falling in a period with no environmental data are returned with
`NA` values and a warning naming the periods, rather than being dropped silently.

## Related packages

- [derivoce](https://github.com/chross22/derivoce) — derived covariates
  (gradients, FTLE/FSLE, front and isobath distances, lags, integrals) computed
  from what `accessEnvDat()` returns
