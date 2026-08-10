# Inverse distance weighting onto a target grid

Split out because it takes source *points* rather than a source raster,
and so does not go through
[`terra::resample()`](https://rspatial.github.io/terra/reference/resample.html)
like every other method.

## Usage

``` r
idw_layer(layer, target, radius, power)
```

## Arguments

- layer:

  a single-layer `SpatRaster` of source values

- target:

  the target `SpatRaster` template

- radius:

  search radius in the CRS's units

- power:

  distance exponent

## Value

a `SpatRaster` on the target grid
