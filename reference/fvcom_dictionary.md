# Printable dictionary of FVCOM variables

Printable dictionary of FVCOM variables

## Usage

``` r
fvcom_dictionary(mesh = c("all", "node", "element"))
```

## Arguments

- mesh:

  filter to `"node"`, `"element"`, or `"all"`

## Value

a data frame of class `datamatch_dictionary`

## See also

[`fvcom_variables()`](https://chross22.github.io/datamatch/reference/fvcom_variables.md)

## Examples

``` r
fvcom_dictionary()
#> FVCOM variables available by name
#> ------------------------------------------------------------------
#>  name  variable      label                             units    
#>  SST   temp          Sea surface temperature           degrees C
#>  BOTT  temp          Bottom temperature                degrees C
#>  SSS   salinity      Sea surface salinity              PSU      
#>  BOTS  salinity      Bottom salinity                   PSU      
#>  SSH   zeta          Sea surface height                m        
#>  DEPTH h             Water depth                       m        
#>  SWRAD short_wave    Downward shortwave radiation      W/m2     
#>  NHF   net_heat_flux Net surface heat flux             W/m2     
#>  UO    u             Eastward current velocity         m/s      
#>  VO    v             Northward current velocity        m/s      
#>  UBAR  ua            Eastward depth-averaged velocity  m/s      
#>  VBAR  va            Northward depth-averaged velocity m/s      
#>  TAUX  uwind_stress  Eastward wind stress              N/m2     
#>  TAUY  vwind_stress  Northward wind stress             N/m2     
#>  on             
#>  node surface   
#>  node bottom    
#>  node surface   
#>  node bottom    
#>  node           
#>  node           
#>  node           
#>  node           
#>  element surface
#>  element surface
#>  element        
#>  element        
#>  element        
#>  element        
#> 
#> `on` is where a value sits: which part of the mesh, and which sigma
#> layer. Node and element variables cannot be fetched together - see
#> ?accessFVCOM. A sigma layer is a fraction of the local depth, not a depth.
#> Full descriptions: as.data.frame(fvcom_dictionary())$description
fvcom_dictionary("element")
#> FVCOM variables available by name
#> ------------------------------------------------------------------
#>  name variable     label                             units on             
#>  UO   u            Eastward current velocity         m/s   element surface
#>  VO   v            Northward current velocity        m/s   element surface
#>  UBAR ua           Eastward depth-averaged velocity  m/s   element        
#>  VBAR va           Northward depth-averaged velocity m/s   element        
#>  TAUX uwind_stress Eastward wind stress              N/m2  element        
#>  TAUY vwind_stress Northward wind stress             N/m2  element        
#> 
#> `on` is where a value sits: which part of the mesh, and which sigma
#> layer. Node and element variables cannot be fetched together - see
#> ?accessFVCOM. A sigma layer is a fraction of the local depth, not a depth.
#> Full descriptions: as.data.frame(fvcom_dictionary())$description
```
