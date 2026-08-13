# Printable dictionary of CCMP variables

Printable dictionary of CCMP variables

## Usage

``` r
ccmp_dictionary()
```

## Value

a data frame of class `datamatch_dictionary`

## See also

[`ccmp_variables()`](https://chross22.github.io/datamatch/reference/ccmp_variables.md)

## Examples

``` r
ccmp_dictionary()
#> FVCOM variables available by name
#> ------------------------------------------------------------------
#>  name variable label                  units on  
#>  WSPD ws       Wind speed             m/s   CCMP
#>  UWND uwnd     Eastward wind          m/s   CCMP
#>  VWND vwnd     Northward wind         m/s   CCMP
#>  NOBS nobs     Satellite observations count CCMP
#> 
#> `on` is where a value sits: which part of the mesh, and which sigma
#> layer. Node and element variables cannot be fetched together - see
#> ?accessFVCOM. A sigma layer is a fraction of the local depth, not a depth.
#> Full descriptions: as.data.frame(fvcom_dictionary())$description
```
