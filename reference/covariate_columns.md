# Covariate column names in an environmental data object

Everything that is not a time column or the geometry.

## Usage

``` r
covariate_columns(env_dat)
```

## Arguments

- env_dat:

  an `sf` POINT object from any access function -
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md),
  [`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md),
  [`accessHYCOM()`](https://chross22.github.io/datamatch/reference/accessHYCOM.md),
  [`accessCCMP()`](https://chross22.github.io/datamatch/reference/accessCCMP.md)
  or
  [`accessERDDAP()`](https://chross22.github.io/datamatch/reference/accessERDDAP.md)

## Value

character vector of covariate column names

## Examples

``` r
if (FALSE) { # \dontrun{
covariate_columns(env)
} # }
```
