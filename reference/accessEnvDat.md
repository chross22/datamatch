# Fetch Copernicus data (deprecated name)

`accessEnvDat()` is the old name for
[`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md).
It still works and warns; it will be removed in a later version.

## Usage

``` r
accessEnvDat(...)
```

## Arguments

- ...:

  passed to
  [`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md)

## Value

whatever
[`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md)
returns

## Why it was renamed

The name dates from when Copernicus was the only source. With five,
"access environmental data" reads as though it fetches from all of them,
sitting beside
[`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md),
[`accessHYCOM()`](https://chross22.github.io/datamatch/reference/accessHYCOM.md),
[`accessCCMP()`](https://chross22.github.io/datamatch/reference/accessCCMP.md)
and
[`accessERDDAP()`](https://chross22.github.io/datamatch/reference/accessERDDAP.md),
which each say what they read.
[`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md)
says the same.

Nothing else changes: the arguments, the result, and the `copernicus:`
source tag are all as they were.

## See also

[`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Both do the same thing; the first warns.
env <- accessEnvDat(vars = "SST", years = 2010, months = 1:12, bounding_box = bb)
env <- accessCopernicus(vars = "SST", years = 2010, months = 1:12, bounding_box = bb)
} # }
```
