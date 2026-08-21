# Convert a marmap bathy object into terrain layers

Split from
[`fetch_bathymetry()`](https://camilleross.org/datamatch/reference/fetch_bathymetry.md)
so the conversion can be tested without a network call.

## Usage

``` r
bathymetry_layers(bathy)
```

## Arguments

- bathy:

  a `marmap` `bathy` object

## Value

a
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with `DEPTH`, `SLOPE`, `ASPECT`, and `TPI` layers
