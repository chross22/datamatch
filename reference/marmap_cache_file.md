# Where marmap would have cached this grid

Rebuilds the filename
[`marmap::getNOAA.bathy()`](https://rdrr.io/pkg/marmap/man/getNOAA.bathy.html)
writes, so an existing download can be read directly instead of
requested again.

## Usage

``` r
marmap_cache_file(bounding_box, resolution, path)
```

## Arguments

- bounding_box:

  named list with `xmin`, `xmax`, `ymin`, `ymax`

- resolution:

  grid resolution in arc-minutes

- path:

  the cache directory

## Value

the path marmap would use, or `NULL` where the convention does not apply

## Details

The convention is marmap's, not this package's: `marmap_coord_` then the
bounding box as `x1;y1;x2;y2` with the lower corner first, then `_res_`
and the resolution. Requests that cross the antimeridian get an `_anti`
suffix, and are not claimed here — returning `NULL` for them means
falling back to `getNOAA.bathy()`, which is the correct answer either
way.

Should marmap ever change the convention, this stops matching and every
fetch goes back through `getNOAA.bathy()`. That is slower and chattier,
not wrong.
