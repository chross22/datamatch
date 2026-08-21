# The OPeNDAP handle for an archive, with a readable failure

`ncdf4` is a `Suggests`, and the server is a remote one that is
sometimes down. Both failures are reported here rather than as a raw
netCDF error, which names a URL and nothing about what to do.

## Usage

``` r
fvcom_open(archive)
```

## Arguments

- archive:

  one entry of
  [`fvcom_archives()`](https://camilleross.org/datamatch/reference/fvcom_archives.md)

## Value

an open `ncdf4` handle; the caller closes it
