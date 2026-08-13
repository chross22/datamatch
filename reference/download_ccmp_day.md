# Download one day's CCMP file into the cache

Download one day's CCMP file into the cache

## Usage

``` r
download_ccmp_day(spec, day, destination)
```

## Arguments

- spec:

  one entry of
  [`ccmp_versions()`](https://chross22.github.io/datamatch/reference/ccmp_versions.md)

- day:

  the day to fetch

- destination:

  where to write the file

## Value

`NULL` on success, or a one-line description of the failure

## Why the whole globe is downloaded

RSS serves CCMP as static files over HTTPS, with no OPeNDAP endpoint and
no server-side subsetting. There is no way to ask for a region: a day is
one 33 MB global file whether one cell of it is wanted or the whole
grid. The subset is extracted locally and cached, and the global file is
discarded.

That makes CCMP much heavier per day than any other source here, and a
long record genuinely expensive — a year is roughly 12 GB of transfer to
keep a few megabytes.
[`accessCCMP()`](https://chross22.github.io/datamatch/reference/accessCCMP.md)
says so before starting a large request.
