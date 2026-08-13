# Read and parse an ERDDAP dataset's attribute document

`.das` is a small text document rather than JSON, so it is parsed here
rather than by pulling in a dependency for one format. Only what this
package needs is extracted: which variables exist, their units, and the
time range.

## Usage

``` r
erddap_metadata(server, dataset_id)
```

## Arguments

- server, dataset_id:

  the ERDDAP server and dataset

## Value

a named list, one entry per variable, each with `units` and
`actual_range` where present
