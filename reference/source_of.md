# Which source and archive produced a fetched object

Every access function stamps its result with where the values came from,
and this reads it back. The tag is short and stable —
`"copernicus:..."`, `"fvcom:GOM3"`, `"hycom:GLBv53X"`, `"ccmp:v03.1"` —
naming the source and the particular archive or dataset within it.

## Usage

``` r
source_of(x)
```

## Arguments

- x:

  an object from
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md),
  [`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md),
  [`accessHYCOM()`](https://chross22.github.io/datamatch/reference/accessHYCOM.md)
  or
  [`accessCCMP()`](https://chross22.github.io/datamatch/reference/accessCCMP.md)

## Value

the source tag, or `NA` if the object carries none — which is the case
for anything built by hand or produced before this was recorded

## Why this exists

The four sources deliberately share variable names, so an `SST` column
means the same *quantity* whichever produced it and everything
downstream works unchanged. That is the point of the design and also its
hazard: the column name alone cannot say whether a value came from a
global reanalysis, a regional coastal model, or an independent global
model, and those are not the same number.

The package already records provenance where a value's origin is
ambiguous —
[`fill_satellite_gaps()`](https://chross22.github.io/datamatch/reference/fill_satellite_gaps.md)
writes a `<var>_source` column, and a derived `BOTS` returns
`BOTS_depth`. This extends the same habit to the thing that varies most:
which model the value came from at all.

## See also

[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md),
which carries this into `<var>_source` columns

## Examples

``` r
if (FALSE) { # \dontrun{
env <- accessHYCOM(vars = "BOTS", dates = "2010-06-15", bounding_box = bb)
source_of(env)
#> [1] "hycom:GLBv53X"
} # }
```
