# Describe any FVCOM archive, so it can be read like a built-in one

[`fvcom_archives()`](https://camilleross.org/datamatch/reference/fvcom_archives.md)
ships the NECOFS Gulf of Maine hindcast because that is what one server
publishes. FVCOM itself is run for coastlines everywhere, by groups who
publish on their own THREDDS servers, and this is how to reach any of
them: point it at an OPeNDAP endpoint and it works out the rest.

## Usage

``` r
fvcom_archive(
  url,
  label = NULL,
  reference = NA_character_,
  frequency = "monthly"
)
```

## Arguments

- url:

  the OPeNDAP endpoint, as a THREDDS `dodsC` URL

- label:

  a human-readable name; defaults to the URL

- reference:

  the citation for this model run, if there is one. FVCOM output is
  somebody's work, and this is where to record whose.

- frequency:

  what one time step represents, for documentation

## Value

a list in the shape
[`fvcom_archives()`](https://camilleross.org/datamatch/reference/fvcom_archives.md)
entries take, ready to pass to
[`accessFVCOM()`](https://camilleross.org/datamatch/reference/accessFVCOM.md)
as `archive`

## Details

The reader depends on FVCOM's structure rather than on the region, so
anything written by FVCOM should work — values on nodes and element
centroids, sigma layers, `lon`/`lat` and `lonc`/`latc`, and an `Itime`
day count. What differs between deployments is the mesh, the period, and
which variables were saved, all of which are read from the file.

## What it checks

The endpoint is opened and inspected once, so a URL that is wrong,
blocked, or not FVCOM fails here — with the reason — rather than
part-way through a fetch. The mesh size, time span, and variable list
come back in the returned spec, so
[`str()`](https://rdrr.io/r/utils/str.html) on it says what the archive
actually holds.

## A caution about aggregations

Point this at an aggregation of hourly output and it may not open at
all. `nc_open()` reads the whole time coordinate first, and a decade of
hourly fields is enough time steps to exceed a server's DAP timeout —
which is exactly why the built-in GOM3 entry is the monthly mean. Prefer
a monthly aggregation, or a single file, over a long hourly one.

## See also

[`accessFVCOM()`](https://camilleross.org/datamatch/reference/accessFVCOM.md),
[`fvcom_archives()`](https://camilleross.org/datamatch/reference/fvcom_archives.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Any FVCOM endpoint, not just the built-in ones
mine <- fvcom_archive(
  "http://www.smast.umassd.edu:8080/thredds/dodsC/fvcom/hindcasts/30yr_gom3/mean",
  label = "GOM3 monthly means")

str(mine)   # mesh size, period, and variables actually present

env <- accessFVCOM(vars = "SST", years = 2010, months = 1:12,
                   bounding_box = bb, archive = mine)
} # }
```
