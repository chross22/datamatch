# Grid resolution of an environmental data object

Read off the coordinates actually present, as the median spacing between
neighbouring cell centres in each direction. The median rather than the
mean so that a single missing row or column does not shift the answer.

## Usage

``` r
grid_resolution(env_dat)
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

named numeric vector `c(x = , y = )` in the units of the object's CRS,
degrees for every access function here. `NA` in a direction with only
one distinct coordinate, and meaningless on an unstructured FVCOM mesh,
which has no regular spacing to report.

## Details

Useful on its own for deciding which way to resample: compare two
products and the coarser one is the one to bring the other onto, or not,
depending on which trade-off you want. See
[`upscale_grid()`](https://chross22.github.io/datamatch/reference/upscale_grid.md)
for what that choice costs.

## See also

[`upscale_grid()`](https://chross22.github.io/datamatch/reference/upscale_grid.md),
[`downscale_grid()`](https://chross22.github.io/datamatch/reference/downscale_grid.md)

## Examples

``` r
if (FALSE) { # \dontrun{
grid_resolution(env)          # x 0.083  y 0.083
} # }
```
