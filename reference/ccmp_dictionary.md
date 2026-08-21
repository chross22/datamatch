# Printable dictionary of CCMP variables

Printable dictionary of CCMP variables

## Usage

``` r
ccmp_dictionary()
```

## Value

a data frame of class `datamatch_dictionary`

## See also

[`ccmp_variables()`](https://camilleross.org/datamatch/reference/ccmp_variables.md)

## Examples

``` r
ccmp_dictionary()
#> CCMP variables available by name
#> ------------------------------------------------------------------
#>  name variable label                  units source
#>  WSPD ws       Wind speed             m/s   CCMP  
#>  UWND uwnd     Eastward wind          m/s   CCMP  
#>  VWND vwnd     Northward wind         m/s   CCMP  
#>  NOBS nobs     Satellite observations count CCMP  
#> Full descriptions: as.data.frame(ccmp_dictionary())$description
```
