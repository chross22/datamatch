
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

## Variable names

Copernicus variable codes are terse and easy to misremember — `thetao` for
temperature, `mlotst` for mixed layer depth, `zos` for sea surface height — and
getting one wrong produces a failed download rather than an obvious mistake. So
variables can be requested by name instead, and the dictionary lists what is
available:

``` r
library(datamatch)

variable_dictionary()
```

#> Copernicus variables available by name
#> --------------------------------------------------------------
#>  name variable label                       units    
#>  SST  thetao   Sea surface temperature     degrees C
#>  SSS  so       Sea surface salinity        PSU      
#>  BOTT bottomT  Bottom temperature          degrees C
#>  UO   uo       Eastward current velocity   m/s      
#>  VO   vo       Northward current velocity  m/s      
#>  SSH  zos      Sea surface height          m        
#>  MLD  mlotst   Mixed layer depth           m        
#>  SIC  siconc   Sea ice concentration       fraction 
#>  CHL  chl      Chlorophyll-a concentration mg/m3    
#>  NO3  no3      Nitrate concentration       mmol/m3  
#>  PO4  po4      Phosphate concentration     mmol/m3  
#>  O2   o2       Dissolved oxygen            mmol/m3  
#>  NPP  nppv     Net primary production      mg/m3/day
#>  PH   ph       pH                          1        
#> 
#> Pass a name to accessEnvDat(vars = ...), or the Copernicus code.
#> Full descriptions: as.data.frame(variable_dictionary())$description

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

`product_id` and `dataset_id` can be omitted when every variable is in the
dictionary, since the catalog already knows where they live. Variables from
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

``` r
variable_dictionary("biogeochemical")        # filter by product
variable_dataset(c("SST", "CHL"))            # which dataset each comes from
as.data.frame(variable_dictionary())$description  # full descriptions
```

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
