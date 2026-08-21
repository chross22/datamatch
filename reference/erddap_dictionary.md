# Printable dictionary of the ERDDAP datasets and their variables

Printable dictionary of the ERDDAP datasets and their variables

## Usage

``` r
erddap_dictionary()
```

## Value

a data frame of class `datamatch_dictionary`

## See also

[`erddap_datasets()`](https://camilleross.org/datamatch/reference/erddap_datasets.md)

## Examples

``` r
erddap_dictionary()
#> ERDDAP variables available by name
#> ------------------------------------------------------------------
#>  name      variable        
#>  SST       analysed_sst    
#>  SST_ERROR analysis_error  
#>  ICE       sea_ice_fraction
#>  CHL       chlor_a         
#>  CHL       chla            
#>  label                                                           units    
#>  MUR: Multi-scale Ultra-high Resolution SST analysis (GHRSST L4) degrees C
#>  MUR: Multi-scale Ultra-high Resolution SST analysis (GHRSST L4) degrees C
#>  MUR: Multi-scale Ultra-high Resolution SST analysis (GHRSST L4) fraction 
#>  VIIRS NPP/N20 chlorophyll, DINEOF gap-filled, daily             mg/m3    
#>  VIIRS SNPP chlorophyll, 2018 reprocessing, daily                mg/m3    
#>  dataset     
#>  MUR         
#>  MUR         
#>  MUR         
#>  VIIRSCHL    
#>  VIIRSCHL2018
#> 
#> `dataset` is which built-in dataset supplies the value. A name served
#> by more than one appears once per dataset, because they are different
#> products and not the same number - see ?erddap_datasets.
#> Full descriptions: as.data.frame(erddap_dictionary())$description
```
