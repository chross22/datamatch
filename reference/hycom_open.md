# Open one year of a HYCOM archive

Open one year of a HYCOM archive

## Usage

``` r
hycom_open(spec, year)
```

## Arguments

- spec:

  one entry of
  [`hycom_archives()`](https://chross22.github.io/datamatch/reference/hycom_archives.md)

- year:

  the year to open

## Value

an open `ncdf4` handle; the caller closes it
