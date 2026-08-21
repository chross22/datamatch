# Read a bounding box out of one OB.DAAC Level-3 mapped file

Read a bounding box out of one OB.DAAC Level-3 mapped file

## Usage

``` r
obdaac_read(path, entry, bounding_box)
```

## Arguments

- path:

  the downloaded file

- entry:

  one entry of
  [`obdaac_variables()`](https://camilleross.org/datamatch/reference/obdaac_variables.md)

- bounding_box:

  the box, negative west

## Value

a data frame of `x`, `y` and the value, or `NULL` if the box selects
nothing

## Latitude runs the other way

These are global equidistant-cylindrical grids with latitude descending
from 90 to -90, where most of this package's sources ascend. It makes no
difference to the indexing — a latitude window is still one contiguous
run — and the coordinates are paired with their values in file order
either way, so nothing downstream sees it. Noted because it looks like a
bug the first time the raw arrays are inspected.
