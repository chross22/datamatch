# Describe any ERDDAP griddap dataset, so it can be read like a built-in one

ERDDAP servers host thousands of gridded datasets, and
[`erddap_datasets()`](https://camilleross.org/datamatch/reference/erddap_datasets.md)
ships three. This is how to reach any of the rest: give it a server and
a dataset id, and it reads the dataset's own metadata to work out the
axes, the variables and the period covered.

## Usage

``` r
erddap_dataset(
  server,
  dataset_id,
  variables = NULL,
  label = NULL,
  reference = NA_character_
)
```

## Arguments

- server:

  the ERDDAP base URL, e.g. `"https://coastwatch.pfeg.noaa.gov/erddap"`

- dataset_id:

  the griddap dataset id

- variables:

  named vector mapping the names you want to this dataset's variable
  names, as `c(SST = "analysed_sst")`. When `NULL`, every data variable
  is offered under its own name.

- label:

  a human-readable name; defaults to the dataset id

- reference:

  the citation for this product, if there is one

## Value

a list in the shape
[`erddap_datasets()`](https://camilleross.org/datamatch/reference/erddap_datasets.md)
entries take, ready to pass to
[`accessERDDAP()`](https://camilleross.org/datamatch/reference/accessERDDAP.md)
as `dataset`

## What it checks

The dataset's `.das` is fetched and parsed once, so a wrong id, an
unreachable server, or a dataset that is tabular rather than gridded
fails here — with the reason — rather than part-way through a fetch.
Whether the dataset carries a singleton `altitude` axis is detected
rather than assumed, because that changes the shape of every request.

## See also

[`accessERDDAP()`](https://camilleross.org/datamatch/reference/accessERDDAP.md),
[`erddap_datasets()`](https://camilleross.org/datamatch/reference/erddap_datasets.md)

## Examples

``` r
if (FALSE) { # \dontrun{
mine <- erddap_dataset("https://coastwatch.pfeg.noaa.gov/erddap",
                       "jplMURSST41", variables = c(SST = "analysed_sst"))
str(mine)
} # }
```
