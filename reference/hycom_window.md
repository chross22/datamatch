# The contiguous index window covering a bounding box

HYCOM is a regular grid whose coordinates increase monotonically, so a
box is a contiguous run of indices on each axis and can be asked for as
a slice. That is the opposite of FVCOM, whose mesh numbering is not
spatially coherent and has to be read whole — see
[`fvcom_in_box()`](https://camilleross.org/datamatch/reference/fvcom_in_box.md).

## Usage

``` r
hycom_window(values, lower, upper, axis)
```

## Arguments

- values:

  the axis coordinates, increasing

- lower, upper:

  the requested range

- axis:

  the axis name, for the error

## Value

`list(start =, count =, values =)`, one-based

## Details

Computed from the coordinate values rather than from a step, because
HYCOM's latitude spacing is not uniform: it is finer near the equator
than toward the poles, so anything derived from `lat[2] - lat[1]` would
be wrong at most latitudes.
