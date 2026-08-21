# Static seafloor variables

Bathymetry and the terrain measures derived from it. These are *static*
— they do not vary by month or year — so they are fetched once for a
study area and attached to every time step, unlike the Copernicus
variables.

## Usage

``` r
bathymetry_variables()
```

## Value

a named list, one entry per variable, each with `label`, `units`, and
`description`

## Details

Sourced from NOAA ETOPO via
[`marmap::getNOAA.bathy()`](https://rdrr.io/pkg/marmap/man/getNOAA.bathy.html).

## See also

[`fetch_bathymetry()`](https://camilleross.org/datamatch/reference/fetch_bathymetry.md),
[`variable_dictionary()`](https://camilleross.org/datamatch/reference/variable_dictionary.md)

## Examples

``` r
names(bathymetry_variables())
#> [1] "DEPTH"  "SLOPE"  "ASPECT" "TPI"   
```
