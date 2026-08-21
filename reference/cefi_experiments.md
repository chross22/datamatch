# The CEFI experiments this package can and cannot read

The portal publishes seven experiments for the Northwest Atlantic. Two
are readable, and the other five are refused here rather than being
attempted — each for a reason that has nothing to do with the caller and
would otherwise surface as an obscure failure a long way from its cause.

## Usage

``` r
cefi_experiments()
```

## Value

a named list, one entry per experiment, each with `readable` and `why`

## Why the seasonal forecast is not among them

Its files carry a 64-bit integer coordinate, which DAP2 has no type for,
so the PSL server answers `NcDDS Variable data type = long` with an HTTP
500 to every classic OPeNDAP request for one. The DAP4 endpoint does
describe them — and then reads them wrongly: `ncdf4` transposes the
start and count vectors against the dimension order it reported, and the
read segfaults R rather than returning anything. A reader that crashes
the session is worse than no reader, so this refuses instead.

The files are downloadable whole from the THREDDS `fileServer` endpoint
and open correctly once local, at roughly 260 MB per variable per
initialisation. That is the route if you need them.

## Why the projections are not among them

`long_term_projection` and `multi_decadal_outlook` have directories on
the server and no files in them. The portal announces an experiment
before its output is posted, so this may simply be early;
[`cefi_archive()`](https://camilleross.org/datamatch/reference/cefi_archive.md)
will read them the moment they appear.
