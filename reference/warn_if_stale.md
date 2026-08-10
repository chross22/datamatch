# Warn when a living index has stopped being current

A fresh download of a stale file is still stale. This checks the data
rather than the cache: if a series that is supposed to keep growing ends
well before now, that is worth knowing whether the cause is a cache, a
provider pause, or a publication lag.

## Usage

``` r
warn_if_stale(series, index, entry)
```

## Arguments

- series:

  the parsed monthly series

- index:

  the index name

- entry:

  the catalog entry

## Value

invisibly `NULL`
