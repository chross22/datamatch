# Where an Earthdata Login credential is found

Where an Earthdata Login credential is found

## Usage

``` r
obdaac_credentials()
```

## Value

a list with `kind` and, for an appkey, `key`

## Why this package cannot avoid it

OB.DAAC requires an Earthdata Login on every data access point. There is
no anonymous route, and the failure when you have not got one is
unhelpful in a particular way: the server answers **HTTP 200** with the
login page, so a naive download writes nine kilobytes of HTML into a
file called `.nc` and the error surfaces later as a corrupt netCDF.
[`obdaac_download()`](https://camilleross.org/datamatch/reference/obdaac_download.md)
checks the bytes for this and says what actually happened.

## Setting one up

Register once at <https://urs.earthdata.nasa.gov/users/new>, then
either:

- **An appkey**, which is the simpler of the two. Generate one at
  <https://oceandata.sci.gsfc.nasa.gov/appkey/> and put it in
  `options(datamatch.earthdata_appkey = "...")`, or in the
  `EARTHDATA_APPKEY` environment variable. It is a bearer token, so keep
  it out of scripts you share — `.Renviron` is the usual home.

- **A `~/.netrc`**, which is what NASA's own examples use and what other
  tools on your machine may already read:
  `machine urs.earthdata.nasa.gov login USERNAME password PASSWORD`. Set
  it to mode 600. This needs `curl` on the `PATH`.

The appkey is preferred where both are present, because it needs no
cookie jar and no external program.
