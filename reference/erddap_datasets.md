# Satellite datasets read through ERDDAP

ERDDAP is NOAA's data server, and several satellite products this
package wants are on one. It matters here for a practical reason: the
same products at PO.DAAC need an Earthdata login, and ERDDAP serves them
with **no account at all**, subsetting server-side by longitude,
latitude and time.

## Usage

``` r
erddap_datasets()
```

## Value

a named list, one entry per dataset, each with `server`, `dataset_id`,
`variables`, `has_altitude`, `start`, `end`, `resolution`, `label` and
`reference`

## What is built in, and what is not

Three datasets ship. They are the ones that are global, current, and
relevant to a shelf study:

|                |                     |                    |
|----------------|---------------------|--------------------|
| `MUR`          | SST, 0.01 deg daily | 2002-06 onward     |
| `VIIRSCHL`     | chlorophyll, daily  | 2020-05 onward     |
| `VIIRSCHL2018` | chlorophyll, daily  | 2012-01 to 2022-07 |

**There is no global VIIRS SST here.** The VIIRS SST dataset on these
servers covers the US West Coast only (-128 to -115 E), which is no use
on the Atlantic shelf, and nothing global turned up in its place. MUR is
the SST to use instead — it is a blended analysis that takes VIIRS among
its inputs, so it carries the same sensor's information at higher
resolution and over a much longer record.

The two chlorophyll entries are the same instrument processed twice.
`VIIRSCHL2018` is the 2018 reprocessing, which stops in July 2022;
`VIIRSCHL` is the current gap-filled product, which starts in May 2020.
They overlap for two years and are not the same numbers, so a series
spanning both has a seam in it.

## MUR is not a model SST

`MUR` is a satellite analysis of the *foundation* temperature — the
temperature below the daily warming layer — where a model `SST` is the
topmost model level. On a calm sunny afternoon those differ by a degree
or more. Both arrive in a column called `SST`, and
[`source_of()`](https://camilleross.org/datamatch/reference/source_of.md)
is what distinguishes them.

## See also

[`accessERDDAP()`](https://camilleross.org/datamatch/reference/accessERDDAP.md),
[`erddap_dataset()`](https://camilleross.org/datamatch/reference/erddap_dataset.md)
for any other ERDDAP dataset

## Examples

``` r
names(erddap_datasets())
#> [1] "MUR"          "VIIRSCHL"     "VIIRSCHL2018"
erddap_datasets()$MUR$dataset_id
#> [1] "jplMURSST41"
```
