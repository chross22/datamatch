# What is cached, how old it is, and whether it is due a refresh

Reports without downloading anything, so it is safe to call offline.

## Usage

``` r
climate_index_status()

# S3 method for class 'datamatch_index_status'
print(x, ...)
```

## Arguments

- x:

  a `datamatch_index_status`

- ...:

  ignored

## Value

a data frame, one row per index, of class `datamatch_index_status`

## See also

[`refresh_climate_index()`](https://chross22.github.io/datamatch/reference/refresh_climate_index.md)

## Examples

``` r
climate_index_status()
#> Cached climate indices
#> ----------------------------------------------------
#>  index updates cached age_days refresh_due
#>  NAO   monthly FALSE  NA       FALSE      
#>  AO    monthly FALSE  NA       FALSE      
#>  AMO   monthly FALSE  NA       FALSE      
#>  PDO   monthly FALSE  NA       FALSE      
#>  LCR   none    FALSE  NA       FALSE      
#>  AMOC  annual  FALSE  NA       FALSE      
#> 
#> Nothing is overdue. Living indices re-download on their own once the 
#> cached copy passes its age limit.
#> 
#> Cache location: /home/runner/.cache/R/datamatch/indices
```
