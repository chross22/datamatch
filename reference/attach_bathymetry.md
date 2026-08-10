# Attach static bathymetry to a table of points

Bathymetry does not vary in time, so the same value is attached to every
observation at a location regardless of its date.

## Usage

``` r
attach_bathymetry(dat, bathy, vars = NULL, coords = c("lon", "lat"))
```

## Arguments

- dat:

  a data frame with coordinate columns, or an `sf` POINT object

- bathy:

  a `SpatRaster` from
  [`fetch_bathymetry()`](https://chross22.github.io/datamatch/reference/fetch_bathymetry.md)

- vars:

  which layers to attach; `NULL` uses all of them

- coords:

  names of the longitude and latitude columns, ignored for `sf` input

## Value

`dat` with one column per requested bathymetry variable

## Details

Accepts either a plain data frame with coordinate columns or an `sf`
POINT object, so it works on observations and on
[`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
output alike.

## Examples

``` r
if (FALSE) { # \dontrun{
bathy <- fetch_bathymetry(list(xmin = -70, xmax = -66, ymin = 41, ymax = 44))
observations <- attach_bathymetry(observations, bathy, c("DEPTH", "SLOPE"))
} # }
```
