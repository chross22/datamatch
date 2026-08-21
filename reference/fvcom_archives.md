# FVCOM archives this package ships with

NECOFS is served over OPeNDAP from a THREDDS server at UMass Dartmouth.
Each entry names one mesh and one archive on it.

## Usage

``` r
fvcom_archives()
```

## Value

a named list, one entry per archive, each with `url`, `mesh`,
`frequency`, `start`, `end`, `nodes`, `elements`, and `reference`

## This list is a convenience, not the limit

FVCOM is a model rather than a data product, so there is no global FVCOM
archive to point at. Different groups run it for their own regions on
their own servers, and what is built in here is only what one server
publishes for the Northeast US shelf.

Any other FVCOM output can be read by describing it with
[`fvcom_archive()`](https://camilleross.org/datamatch/reference/fvcom_archive.md)
and passing that to
[`accessFVCOM()`](https://camilleross.org/datamatch/reference/accessFVCOM.md),
which is the intended route for every region this package does not ship.
FVCOM output shares one structure wherever it is run — values on mesh
nodes and element centroids, sigma layers, `lon`/`lat` and
`lonc`/`latc`, an `Itime` day count — and that structure is what the
reader depends on, not the region.

## Why only the monthly means

The 30-year GOM3 hindcast is published as hourly fields and as monthly
means of them. Only the monthly aggregation is listed here, because the
hourly one cannot be opened at all: it carries 342,348 time steps, and
`nc_open()` reads the whole time coordinate before returning anything,
so the DAP request for it times out. The failure takes upwards of ten
minutes to arrive and reads as `NetCDF: DAP failure`, which says nothing
about the cause.

## See also

[`accessFVCOM()`](https://camilleross.org/datamatch/reference/accessFVCOM.md)

## Examples

``` r
names(fvcom_archives())
#> [1] "GOM3" "GOM7"
fvcom_archives()$GOM3$url
#> [1] "http://www.smast.umassd.edu:8080/thredds/dodsC/fvcom/hindcasts/30yr_gom3/mean"
```
