# The longitude window, in whichever convention the archive uses

HYCOM is not consistent with itself here. The `GLBv0.08` experiments run
-180 to 180 and `GLBy0.08` runs 0 to 360, so a Northwest Atlantic box
that works against the reanalysis selects nothing against the later grid
— which is how this was found.

## Usage

``` r
hycom_lon_window(lon, xmin, xmax)
```

## Arguments

- lon:

  the archive's longitude axis

- xmin, xmax:

  the requested range, negative west

## Value

`list(start =, count =, values =, keep =)`, one-based, with `values`
negative west

## Details

The convention is read off the coordinates rather than recorded per
archive, so a grid this package has not seen is handled by inspection
instead of by a table that can go stale. `bounding_box` is negative west
throughout, as with every other source, and the returned longitudes are
converted back.

## Boxes that wrap

In the 0-360 convention a box straddling the prime meridian is two runs
of indices rather than one, and OPeNDAP wants a contiguous slice. Such a
box is read as the span between its extremes and filtered locally —
correct, but it transfers most of a latitude row to keep two edges of
it. `keep` carries the positions to retain within the slice.
