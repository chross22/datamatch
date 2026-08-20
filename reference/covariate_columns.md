# Covariate column names in an environmental data object

Everything that is not a time column, the geometry, or bookkeeping.

## Usage

``` r
covariate_columns(env_dat)
```

## Arguments

- env_dat:

  an `sf` POINT object from any access function -
  [`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md),
  [`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md),
  [`accessHYCOM()`](https://chross22.github.io/datamatch/reference/accessHYCOM.md),
  [`accessCCMP()`](https://chross22.github.io/datamatch/reference/accessCCMP.md)
  or
  [`accessERDDAP()`](https://chross22.github.io/datamatch/reference/accessERDDAP.md)

## Value

character vector of covariate column names

## Details

`<var>_source` columns are included. They are provenance, but they
travel with the variable they describe:
[`upscale_grid()`](https://chross22.github.io/datamatch/reference/upscale_grid.md)
and
[`upscale_time()`](https://chross22.github.io/datamatch/reference/upscale_time.md)
carry a non-numeric column as a categorical, so a resampled object keeps
the record of which source each value came from. `<var>_depth` is
excluded, because the mean of two depths is not the depth any value came
from.

## Examples

``` r
if (FALSE) { # \dontrun{
covariate_columns(env)
} # }
```
