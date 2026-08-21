# Which source and archive produced a fetched object

Every access function stamps its result with where the values came from,
and this reads it back. The tag is short and stable —
`"copernicus:..."`, `"fvcom:GOM3"`, `"hycom:GLBv53X"`,
`"cefi:NWA12-hindcast-r20250715"`, `"ccmp:v03.1"`, `"erddap:MUR"`,
`"obdaac:MODISA-4km"` — naming the source and the particular archive,
release or dataset within it.

## Usage

``` r
source_of(x)
```

## Arguments

- x:

  an object from
  [`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md),
  [`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md),
  [`accessHYCOM()`](https://chross22.github.io/datamatch/reference/accessHYCOM.md),
  [`accessCEFI()`](https://chross22.github.io/datamatch/reference/accessCEFI.md),
  [`accessCCMP()`](https://chross22.github.io/datamatch/reference/accessCCMP.md),
  [`accessERDDAP()`](https://chross22.github.io/datamatch/reference/accessERDDAP.md)
  or
  [`accessOBDAAC()`](https://chross22.github.io/datamatch/reference/accessOBDAAC.md)

## Value

the source tag, or `NA` if the object carries none — which is the case
for anything built by hand or produced before this was recorded

## Why this exists

The sources deliberately share variable names, so an `SST` column means
the same *quantity* whichever produced it and everything downstream
works unchanged. That is the point of the design and also its hazard:
the column name alone cannot say whether a value came from a global
reanalysis, a regional coastal model, an independent global model or a
satellite retrieval, and those are not the same number.

The detail after the colon is not decoration. A CEFI tag names the
release the values came from, because releases revise the record; an
OB.DAAC tag names the sensor, because two sensors disagree where they
overlap; a HYCOM tag names the archive, because the record crosses from
a reanalysis into operational experiments.

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
