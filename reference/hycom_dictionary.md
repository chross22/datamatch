# Printable dictionary of HYCOM variables

Printable dictionary of HYCOM variables

## Usage

``` r
hycom_dictionary()
```

## Value

a data frame of class `datamatch_dictionary`

## See also

[`hycom_variables()`](https://camilleross.org/datamatch/reference/hycom_variables.md)

## Examples

``` r
hycom_dictionary()
#> Variables available by name
#> ------------------------------------------------------------------
#>  name      variable          label                      units     source   
#>  SST       water_temp        Sea surface temperature    degrees C 0 m level
#>  SSS       salinity          Sea surface salinity       PSU       0 m level
#>  BOTT      water_temp_bottom Bottom temperature         degrees C own field
#>  BOTS      salinity_bottom   Bottom salinity            PSU       own field
#>  SSH       surf_el           Sea surface height         m         own field
#>  UO        water_u           Eastward current velocity  m/s       0 m level
#>  VO        water_v           Northward current velocity m/s       0 m level
#>  UO_BOTTOM water_u_bottom    Eastward bottom velocity   m/s       own field
#>  VO_BOTTOM water_v_bottom    Northward bottom velocity  m/s       own field
```
