# Re-download cached climate indices

Forces a fresh copy, ignoring the cache. Use after a provider publishes,
or when a series looks like it has stopped short.

## Usage

``` r
refresh_climate_index(index = NULL)
```

## Arguments

- index:

  one or more index names, or `NULL` for every living index

## Value

invisibly, a data frame of what was refreshed and where it now ends

## Details

Indices that will never change are skipped rather than re-fetched. `LCR`
was published with a paper and ends at 2014, so downloading it again
cannot produce anything new.

## See also

[`climate_index_status()`](https://chross22.github.io/datamatch/reference/climate_index_status.md),
[`fetch_climate_index()`](https://chross22.github.io/datamatch/reference/fetch_climate_index.md)

## Examples

``` r
if (FALSE) { # \dontrun{
refresh_climate_index()          # every index that is still growing
refresh_climate_index("AMOC")
} # }
```
