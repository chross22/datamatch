# Printable dictionary of climate indices

The `reference` column carries a citation for the indices that have one.
`LCR` and `AMOC` are published output and should be cited when used; the
NOAA indices are operational products with no single paper, and credit
the provider instead. Both are printed by the print method.

## Usage

``` r
index_dictionary()

# S3 method for class 'datamatch_index_dictionary'
print(x, ...)
```

## Arguments

- x:

  a `datamatch_index_dictionary`

- ...:

  ignored

## Value

a data frame of class `datamatch_index_dictionary`

## Examples

``` r
index_dictionary()
#> Climate indices available by name
#> --------------------------------------------------------------
#>  name label                                       units               
#>  NAO  North Atlantic Oscillation                  standardized anomaly
#>  AO   Arctic Oscillation                          standardized anomaly
#>  AMO  Atlantic Multidecadal Oscillation           degrees C           
#>  PDO  Pacific Decadal Oscillation                 standardized anomaly
#>  LCR  Labrador Current retroflection              fraction            
#>  AMOC Atlantic Meridional Overturning Circulation Sv                  
#>  source                                   
#>  NOAA CPC                                 
#>  NOAA CPC                                 
#>  NOAA PSL                                 
#>  NOAA PSL                                 
#>  Jutras et al. 2023, Nature Communications
#>  RAPID-MOCHA-WBTS array at 26.5N          
#> 
#> These have no spatial dimension: one value per month, basin-wide.
#> 
#> Cite when used:
#>   LCR: Jutras M, Dufour CO, Mucci A, Talbot LC (2023) Large-scale control of the retroflection of the Labrador Current. Nature Communications 14:2623. doi:10.1038/s41467-023-38321-y
#>   AMOC: Moat BI, Smeed DA, Rayner D, Johns WE, Smith R, Volkov D, Elipot S, Petit T, Kajtar J, Baringer MO, Collins J (2026). Atlantic meridional overturning circulation observed by the RAPID-MOCHA-WBTS array at 26N from 2004 to 2024 (v2024.1a). British Oceanographic Data Centre, NERC, UK. doi:10.5285/48d0bf43-0598-ceb2-e063-7086abc062f1
#> 
#> Sources: as.data.frame(index_dictionary())$url
```
