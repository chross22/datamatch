# About how large one global Level-3 mapped file is

Used to say what a request is about to transfer before it starts, in the
way
[`accessCCMP()`](https://chross22.github.io/datamatch/reference/accessCCMP.md)
does, because nothing in the call hints at the cost and the difference
between the two resolutions is a factor of three.

## Usage

``` r
obdaac_typical_bytes(resolution)
```

## Arguments

- resolution:

  `"4km"` or `"9km"`

## Value

bytes

## Details

These are measured from the archive rather than derived from the grid: a
4 km daily chlorophyll field is about 15 MB and its 9 km counterpart
about 5, and the temperature suites are somewhat smaller than the colour
ones. One number per resolution is enough for a warning about order of
magnitude.
