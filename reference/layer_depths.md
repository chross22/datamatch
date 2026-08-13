# Depth of each layer of a three-dimensional download

Read back off the layer names, which is where the only per-layer record
of it survives
[`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html).
Layers of a two-dimensional variable have no depth and come back `NA`.

## Usage

``` r
layer_depths(x)
```

## Arguments

- x:

  a `SpatRaster` read from a Copernicus download

## Value

one depth in metres per layer
