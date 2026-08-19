# Catalog of HYCOM variables under the same names as the Copernicus ones

HYCOM is the HYbrid Coordinate Ocean Model, and GOFS is the global
forecast system built on it by the US Naval Research Laboratory. This
maps the package's usual short names onto the HYCOM variables that
supply them, so a covariate fetched from HYCOM lands in a column with
the same name it would have had from Copernicus or FVCOM.

## Usage

``` r
hycom_variables()
```

## Value

a named list, one entry per variable, each with `variable`, `label`,
`units`, `surface` (whether it needs a depth index), and `description`

## Bottom fields are published outright

HYCOM serves `salinity_bottom` and `water_temp_bottom` as variables in
their own right, so `BOTS` and `BOTT` are ordinary requests here. That
is the one place HYCOM is plainly easier than the Copernicus reanalysis,
which publishes bottom temperature but no bottom salinity and makes
[`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md)
derive one from the full depth column. If bottom salinity over 1994–2015
is what you need, this is the cheapest source for it.

## Surface is a depth level, not a separate field

HYCOM is on 40 fixed z-levels rather than sigma layers, so `SST` and
`SSS` are the 0 m level of the three-dimensional field. That is a
genuine surface value, unlike FVCOM's uppermost sigma layer, which is a
fraction of the local column.

## See also

[`accessHYCOM()`](https://chross22.github.io/datamatch/reference/accessHYCOM.md),
[`hycom_archives()`](https://chross22.github.io/datamatch/reference/hycom_archives.md)

## Examples

``` r
names(hycom_variables())
#> [1] "SST"       "SSS"       "BOTT"      "BOTS"      "SSH"       "UO"       
#> [7] "VO"        "UO_BOTTOM" "VO_BOTTOM"
hycom_variables()$BOTS$variable
#> [1] "salinity_bottom"
```
