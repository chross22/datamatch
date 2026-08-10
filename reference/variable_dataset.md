# Look up the dataset a set of variables comes from

Variables in one Copernicus dataset can be fetched together; variables
from different datasets cannot. This reports which dataset each name
belongs to so a caller can group them.

## Usage

``` r
variable_dataset(
  vars,
  mode = c("reanalysis", "forecast"),
  frequency = c("monthly", "daily")
)
```

## Arguments

- vars:

  variable names from the catalog

- mode:

  `"reanalysis"` (the default) or `"forecast"`

- frequency:

  `"monthly"` (the default) or `"daily"`

## Value

a named character vector of dataset identifiers, `NA` for names not in
the catalog and, when `frequency = "daily"`, for catalog variables that
have no daily dataset

## Examples

``` r
variable_dataset(c("SST", "SSS", "CHL"))
#>                                                 SST 
#>               "cmems_mod_glo_phy_my_0.083deg_P1M-m" 
#>                                                 SSS 
#>               "cmems_mod_glo_phy_my_0.083deg_P1M-m" 
#>                                                 CHL 
#> "cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M" 

# PP and the phytoplankton types are monthly composites only
variable_dataset(c("SST", "CHL", "PP"), frequency = "daily")
#>                                                         SST 
#>                       "cmems_mod_glo_phy_my_0.083deg_P1D-m" 
#>                                                         CHL 
#> "cmems_obs-oc_glo_bgc-plankton_my_l4-gapfree-multi-4km_P1D" 
#>                                                          PP 
#>                                                          NA 
```
