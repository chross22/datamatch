# Printable dictionary of the ERDDAP datasets and their variables

Printable dictionary of the ERDDAP datasets and their variables

## Usage

``` r
erddap_dictionary()
```

## Value

a data frame of class `datamatch_dictionary`

## See also

[`erddap_datasets()`](https://chross22.github.io/datamatch/reference/erddap_datasets.md)

## Examples

``` r
erddap_dictionary()
#> FVCOM variables available by name
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
#>  on          
#>  MUR         
#>  MUR         
#>  MUR         
#>  VIIRSCHL    
#>  VIIRSCHL2018
#> 
#> `on` is where a value sits: which part of the mesh, and which sigma
#> layer. Node and element variables cannot be fetched together - see
#> ?accessFVCOM. A sigma layer is a fraction of the local depth, not a depth.
#> Full descriptions: as.data.frame(fvcom_dictionary())$description
```
