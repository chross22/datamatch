# Where downloaded Copernicus files are kept

Copernicus subsets are slow to fetch and rarely change, so
[`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
writes each one to disk and reads it back on later calls. This resolves
where that cache lives.

## Usage

``` r
copernicus_cache(...)
```

## Arguments

- ...:

  path components appended to the cache root, as
  [`file.path()`](https://rdrr.io/r/base/file.path.html)

## Value

the resolved path, with its parent directory created if needed

## Details

The location is taken from the first of these that is set:

1.  `getOption("datamatch.cache")`

2.  the `DATAMATCH_CACHE` environment variable

3.  [`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html), the
    per-package location R reserves for exactly this purpose

The third is a working default, so nothing has to be configured before
the first download. Set one of the first two to put the cache on a
larger disk, or to share one cache between projects:

    options(datamatch.cache = "~/data/copernicus")   # in .Rprofile

## Moving an existing cache

Earlier versions of this package took the cache root from a
`~/.copernicusdata` file, by way of the `copernicus` package. That file
is no longer read. To keep using files downloaded under the old scheme,
point the option at the same directory rather than moving anything:

    options(datamatch.cache = readLines("~/.copernicusdata"))
