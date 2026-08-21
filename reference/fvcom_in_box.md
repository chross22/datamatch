# Which points of a mesh fall inside a bounding box

The mesh is subset here rather than in the request. FVCOM numbers its
points in mesh-generation order, which is not spatially coherent: on
GOM3 a Gulf of Maine box needs 94% of the index range to reach 40% of
its points, so asking the server for a contiguous slice saves almost
nothing over reading the field whole. A field is 388 KB, which is
cheaper to fetch entire than to negotiate.

## Usage

``` r
fvcom_in_box(coords, bounding_box)
```

## Arguments

- coords:

  output of
  [`fvcom_coordinates()`](https://camilleross.org/datamatch/reference/fvcom_coordinates.md)

- bounding_box:

  a named list or vector with `xmin`, `xmax`, `ymin`, `ymax`

## Value

the indices inside the box
