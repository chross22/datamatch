# Put a table's coordinates into a raster's coordinate system

Put a table's coordinates into a raster's coordinate system

## Usage

``` r
positions_in_crs(dat, target, coords)
```

## Arguments

- dat:

  a data frame with coordinate columns, or an `sf` object

- target:

  a `SpatRaster` whose CRS the coordinates should end up in

- coords:

  names of the longitude and latitude columns, for data frames

## Value

a two-column matrix in `target`'s coordinate system

## Why this is not just `st_coordinates()`

`st_coordinates()` returns coordinates in whatever system the object
carries. Handing those to
[`terra::extract()`](https://rspatial.github.io/terra/reference/extract.html)
treats them as the raster's own, so a set of observations in a projected
CRS is read as though its metres were degrees. Every point then lands
outside the grid and comes back `NA` — observations with no depth, in an
area that plainly has depth, with nothing said about it.

The CRS is reconciled here instead, so the caller does not have to know
that bathymetry arrives in EPSG:4326 while their stations might be in a
UTM zone.
