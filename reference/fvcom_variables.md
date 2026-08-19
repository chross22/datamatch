# Catalog of FVCOM variables under the same names as the Copernicus ones

FVCOM is an unstructured-mesh coastal model, and NECOFS is the Northeast
Coastal Ocean Forecast System built on it at UMass Dartmouth. This maps
the package's usual short names onto the FVCOM variables that supply
them, so a covariate fetched from FVCOM lands in a column with the same
name it would have had from Copernicus and everything downstream works
unchanged.

## Usage

``` r
fvcom_variables()
```

## Value

a named list, one entry per variable, each with `variable`, `label`,
`units`, `mesh` (`"node"` or `"element"`), `layer`, and `description`

## Where a value sits in the vertical

FVCOM uses **sigma coordinates**: each of the 45 layers is a fixed
*fraction* of the local water column rather than a fixed depth, so layer
1 is the surface everywhere and layer 45 the sea floor everywhere. That
is why `SST` and `BOTT` are two entries reading one variable at two
layers, and why bottom salinity costs nothing here — `BOTS` is simply
`salinity` at the bottom layer, where in GLORYS it has to be derived.
See
[`copernicus_variables()`](https://chross22.github.io/datamatch/reference/copernicus_variables.md).

The flip side is that a sigma layer is not a depth. Layer 45 sits at
98.9% of the local depth, which is a metre off the bottom on the shelf
and fifty metres off it in the Northeast Channel.

## Nodes and elements

An FVCOM mesh carries scalars on triangle **nodes** and velocities on
triangle **elements** (the centroids). These are two different sets of
points — 48,451 and 90,415 on GOM3 — so a variable of each kind cannot
land in one table without interpolating one onto the other.

[`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md)
refuses to fetch the two together rather than interpolating on your
behalf, in the same spirit as
[`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md)
refusing to mix two Copernicus grids. Fetch each and chain
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md),
which matches to the nearest point whichever mesh it belongs to.

## See also

[`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md),
[`fvcom_archives()`](https://chross22.github.io/datamatch/reference/fvcom_archives.md)

## Examples

``` r
names(fvcom_variables())
#>  [1] "SST"   "BOTT"  "SSS"   "BOTS"  "SSH"   "DEPTH" "SWRAD" "NHF"   "UO"   
#> [10] "VO"    "UBAR"  "VBAR"  "TAUX"  "TAUY" 
fvcom_variables()$BOTS$variable
#> [1] "salinity"
```
