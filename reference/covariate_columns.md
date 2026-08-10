# Covariate column names in an environmental data object

Everything that is not a time column or the geometry.

## Usage

``` r
covariate_columns(env_dat)
```

## Arguments

- env_dat:

  an `sf` POINT object from
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)

## Value

character vector of covariate column names

## Examples

``` r
if (FALSE) { # \dontrun{
covariate_columns(env)
} # }
```
