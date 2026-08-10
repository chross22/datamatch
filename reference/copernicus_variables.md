# Catalog of Copernicus variables under familiar names

Maps short names people actually use (`SST`, `CHL`, ...) onto the
Copernicus Marine product, dataset, and variable code that supply them.
Copernicus codes are terse and easy to misremember — `thetao` for
temperature, `mlotst` for mixed layer depth, `zos` for sea surface
height — and getting one wrong produces a failed download rather than an
obvious mistake.

## Usage

``` r
copernicus_variables()
```

## Value

a named list, one entry per variable, each with `variable`, `label`,
`units`, `product_id`, `dataset_id`, `daily_dataset_id`, and
`description`

## Details

Entries come from the global reanalyses: physical variables from
`GLOBAL_MULTIYEAR_PHY_001_030` (GLORYS12V1) and biogeochemical ones from
`GLOBAL_MULTIYEAR_BGC_001_029`.

## Monthly and daily

`dataset_id` is the monthly mean; `daily_dataset_id` is the daily one,
which
[`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
uses when given `frequency = "daily"`. It is `NA` where no daily
equivalent exists, and those gaps are not incidental:

- **`PH`** — the daily biogeochemical reanalysis carries `chl`, `no3`,
  `nppv`, `o2`, `po4` and `si`, but not `ph`. Only the monthly mean has
  it.

- **`PP`** — Copernicus-GlobColour serves primary production as a
  monthly composite only.

- **`DIATO`, `DINO`** — the daily ocean colour dataset carries total
  chlorophyll alone. The phytoplankton functional types are monthly.

`CHL` is the case worth reading twice. Daily ocean colour is not the
monthly product at a finer step: it is `l4-gapfree`, the space-time
interpolated field, because a single day of a single sensor is mostly
cloud. The daily values are therefore already gap-filled by Copernicus,
and running
[`fill_satellite_gaps()`](https://chross22.github.io/datamatch/reference/fill_satellite_gaps.md)
over them fills nothing.
[`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
says so when it makes the substitution.

Copernicus revises dataset identifiers periodically. If a fetch fails
with an unknown-dataset error, check the current identifier on the
Copernicus Marine Data Store and pass `dataset_id` explicitly.

## See also

[`variable_dictionary()`](https://chross22.github.io/datamatch/reference/variable_dictionary.md)
for a printable table

## Examples

``` r
names(copernicus_variables())
#>  [1] "SST"       "SSS"       "BOTT"      "UO"        "VO"        "SSH"      
#>  [7] "MLD"       "SIC"       "CHL"       "PP"        "DIATO"     "DINO"     
#> [13] "NO3"       "PO4"       "O2"        "PH"        "CHL_MODEL" "NPP_MODEL"
copernicus_variables()$SST$variable
#> [1] "thetao"
```
