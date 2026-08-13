# Strip terra's layer-name decorations back to the Copernicus variable code

terra names a NetCDF layer after its variable and then decorates it: a
depth suffix on three-dimensional variables (`so_depth=0.494025`) and a
trailing index when the file holds more than one layer of the same
variable (`eastward_wind_14`, and `so_depth=0.494025_1` with both at
once). Matching names against requested codes means removing both.

## Usage

``` r
layer_codes(x)
```

## Arguments

- x:

  a `SpatRaster` read from a Copernicus download

## Value

one variable code per layer
