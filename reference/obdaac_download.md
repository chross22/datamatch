# Download one OB.DAAC file, refusing the login page

Download one OB.DAAC file, refusing the login page

## Usage

``` r
obdaac_download(file, destination, credentials)
```

## Arguments

- file:

  the filename to fetch

- destination:

  where to write it

- credentials:

  from
  [`obdaac_credentials()`](https://camilleross.org/datamatch/reference/obdaac_credentials.md)

## Value

`NULL` on success, or a one-line description of the failure

## Why the status code is not enough

An unauthenticated request is answered with **HTTP 200 and the Earthdata
Login page**, not with a 401. A download that trusts the status code
therefore writes nine kilobytes of HTML into a file named `.nc`, and the
mistake surfaces much later as a corrupt netCDF, naming neither the
credential nor the file.

The first bytes are checked instead. Every file here is netCDF, which
begins either `CDF` or the HDF5 signature, and an HTML document begins
with neither.
