# Open a HYCOM archive, or one year of it

The reanalysis is published one dataset per year and the operational
runs each as a single aggregation, so `layout` decides whether the year
is part of the address or ignored.

## Usage

``` r
hycom_open(spec, year)
```

## Arguments

- spec:

  one entry of
  [`hycom_archives()`](https://chross22.github.io/datamatch/reference/hycom_archives.md)

- year:

  the year to open, used only when `layout` is `"per_year"`

## Value

an open `ncdf4` handle; the caller closes it
