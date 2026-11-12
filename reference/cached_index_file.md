# Download an index file, reusing a recent copy

These files are re-read constantly and change slowly, so they are
cached. The hazard in caching a *living* dataset is that it silently
stops being current, so the cache expires on an interval matched to how
often the provider actually publishes.

## Usage

``` r
cached_index_file(url, index, entry, max_age = NULL, refresh = FALSE)
```

## Arguments

- url:

  where to download from. A URL other than the catalog's is cached under
  a name carrying its hash, so it neither reads nor replaces the catalog
  file's copy.

- index:

  the index name, used for the cache path and messages

- entry:

  the catalog entry, for its `updates` cadence

- max_age:

  maximum cache age in days; `NULL` uses the cadence default

- refresh:

  re-download even if a fresh copy exists

## Value

path to a local file
