# Printable dictionary of CEFI variables

Printable dictionary of CEFI variables

## Usage

``` r
cefi_dictionary()
```

## Value

a data frame of class `datamatch_dictionary`

## See also

[`cefi_variables()`](https://camilleross.org/datamatch/reference/cefi_variables.md)

## Examples

``` r
cefi_dictionary()
#> CEFI variables available by name
#> ------------------------------------------------------------------
#>  name    variable    label                               units    
#>  SST     tos         Sea surface temperature             degrees C
#>  SSS     sos         Sea surface salinity                PSU      
#>  BOTT    tob         Bottom temperature                  degrees C
#>  BOTS    sob         Bottom salinity                     PSU      
#>  SSH     ssh         Sea surface height                  m        
#>  MLD     MLD_003     Mixed layer depth                   m        
#>  SIC     siconc      Sea ice concentration               fraction 
#>  UO      uo_rotate   Eastward current velocity           m/s      
#>  VO      vo_rotate   Northward current velocity          m/s      
#>  CHL     chlos       Chlorophyll-a concentration (model) mg/m3    
#>  NO3     no3os       Nitrate concentration               mmol/m3  
#>  PO4     po4os       Phosphate concentration             mmol/m3  
#>  O2      o2os        Dissolved oxygen                    mmol/m3  
#>  PH      phos        pH                                  unitless 
#>  BOTO2   btm_o2      Bottom dissolved oxygen             umol/kg  
#>  PCO2    pco2surf    Surface partial pressure of CO2     uatm     
#>  PHYC    phycos      Phytoplankton carbon                mol/m3   
#>  MESOZOO mesozoo_200 Mesozooplankton biomass             mol/m2   
#>  step               
#>  CEFI monthly       
#>  CEFI monthly       
#>  CEFI monthly       
#>  CEFI monthly       
#>  CEFI monthly       
#>  CEFI monthly       
#>  CEFI monthly       
#>  CEFI monthly       
#>  CEFI monthly       
#>  CEFI monthly, daily
#>  CEFI monthly, daily
#>  CEFI monthly       
#>  CEFI monthly       
#>  CEFI monthly, daily
#>  CEFI monthly, daily
#>  CEFI monthly, daily
#>  CEFI monthly, daily
#>  CEFI monthly, daily
#> 
#> `step` is which frequencies publish the variable. The NWA12 hindcast
#> saves everything monthly and only biogeochemistry daily - see
#> ?cefi_variables. CEFI is one region, not a global product.
#> Full descriptions: as.data.frame(cefi_dictionary())$description
```
