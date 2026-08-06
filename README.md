
<!-- README.md is generated from README.Rmd. Please edit that file -->

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

Before installation, you must install the Copernicus Marine toolbox from Copernicus Marine Service. This requires registering for a Copernicus account if you don't already have one, as you will need these credentials to configure the toolbox. 

To install this toolbox, visit the Copernicus website. In brief, ...

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
```

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
#>  DIATO     DIATO    Diatom chlorophyll                      mg/m3    
#>  DINO      DINO     Dinophyte chlorophyll                   mg/m3    
#>  NO3       no3      Nitrate concentration                   mmol/m3  
#>  PO4       po4      Phosphate concentration                 mmol/m3  
#>  O2        o2       Dissolved oxygen                        mmol/m3  
#>  PH        ph       pH                                      1        
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
| DIATO     | DIATO    | Diatom chlorophyll                      | mg/m3     |
| DINO      | DINO     | Dinophyte chlorophyll                   | mg/m3     |
| NO3       | no3      | Nitrate concentration                   | mmol/m3   |
| PO4       | po4      | Phosphate concentration                 | mmol/m3   |
| O2        | o2       | Dissolved oxygen                        | mmol/m3   |
| PH        | ph       | pH                                      | 1         |
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

Products do not share a grid — the global physics reanalysis is 0.083 degrees
and biogeochemistry 0.25 — so how resolution is handled matters.

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
