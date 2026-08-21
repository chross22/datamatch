# Printable dictionary of OB.DAAC variables

Printable dictionary of OB.DAAC variables

## Usage

``` r
obdaac_dictionary()
```

## Value

a data frame of class `datamatch_dictionary`

## See also

[`obdaac_variables()`](https://chross22.github.io/datamatch/reference/obdaac_variables.md),
[`obdaac_sensors()`](https://chross22.github.io/datamatch/reference/obdaac_sensors.md)

## Examples

``` r
obdaac_dictionary()
#> NASA OB.DAAC variables available by name
#> ------------------------------------------------------------------
#>  name      variable label                                   units          
#>  CHL       chlor_a  Chlorophyll-a concentration (satellite) mg/m3          
#>  KD490     Kd_490   Diffuse attenuation at 490 nm           1/m            
#>  PAR       par      Photosynthetically available radiation  einstein/m2/day
#>  POC       poc      Particulate organic carbon              mg/m3          
#>  PIC       pic      Particulate inorganic carbon            mol/m3         
#>  SST       sst      Sea surface temperature (daytime)       degrees C      
#>  SST_NIGHT sst      Sea surface temperature (night)         degrees C      
#>  NFLH      nflh     Normalized fluorescence line height     W/m2/um/sr     
#>  suite                                          
#>  CHL SEAWIFS MODIST MODISA VIIRS VIIRSJ1 VIIRSJ2
#>  KD SEAWIFS MODIST MODISA VIIRS VIIRSJ1 VIIRSJ2 
#>  PAR SEAWIFS MODIST MODISA VIIRS VIIRSJ1 VIIRSJ2
#>  POC SEAWIFS MODIST MODISA VIIRS VIIRSJ1 VIIRSJ2
#>  PIC SEAWIFS MODIST MODISA VIIRS VIIRSJ1 VIIRSJ2
#>  SST MODIST MODISA VIIRS VIIRSJ1                
#>  NSST MODIST MODISA VIIRS VIIRSJ1               
#>  FLH MODIST MODISA                              
#> 
#> `suite` is the OB.DAAC product suite the value comes from, and which
#> sensors carry it - see ?obdaac_sensors. Every fetch needs an Earthdata
#> Login; ?accessOBDAAC says how to set one up.
#> Full descriptions: as.data.frame(obdaac_dictionary())$description
```
