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
`GLOBAL_MULTIYEAR_PHY_001_030` (GLORYS12V1), biogeochemical ones from
`GLOBAL_MULTIYEAR_BGC_001_029`, and surface wind from
`WIND_GLO_PHY_CLIMATE_L4_MY_012_003`.

## Monthly, daily and hourly

`dataset_id` is the monthly mean; `daily_dataset_id` is the daily one,
which
[`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md)
uses when given `frequency = "daily"`, and `hourly_dataset_id` the
hourly one. Either is `NA` where no such equivalent exists, and those
gaps are not incidental:

- **`PH`** — the daily biogeochemical reanalysis carries `chl`, `no3`,
  `nppv`, `o2`, `po4` and `si`, but not `ph`. Only the monthly mean has
  it.

- **`PP`** — Copernicus-GlobColour serves primary production as a
  monthly composite only.

- **`DIATO`, `DINO`** — the daily ocean colour dataset carries total
  chlorophyll alone. The phytoplankton functional types are monthly.

- **The wind variables** — have no daily dataset at all. Copernicus
  publishes this wind monthly or hourly and nothing between, so
  `frequency = "daily"` is refused for them. Aggregate the hourly field
  with
  [`upscale_time()`](https://chross22.github.io/datamatch/reference/upscale_time.md)
  if a daily mean is what you need.

- **`WSPD`, `TAU`** — the hourly wind product carries the vector
  components but not the two magnitudes, which it leaves to be computed
  from them. Both are monthly only.

Only the wind variables are hourly, so `hourly_dataset_id` is `NA`
throughout the ocean catalog. The ocean reanalyses are published no
finer than daily.

## Bottom salinity

`BOTS` is the one entry that is not a straight variable request.
GLORYS12V1 publishes potential temperature at the sea floor (`bottomT`)
but no salinity counterpart, so in reanalysis mode `BOTS` is *derived*:
the salinity field is fetched over the full depth range and the deepest
wet level in each cell is kept. Its `derived` element records that. In
forecast mode no derivation is needed — the analysis-and-forecast
product publishes `sob` directly — so
[`forecast_variables()`](https://chross22.github.io/datamatch/reference/forecast_variables.md)
overrides it with the real variable.

The two are the same quantity by construction but not the same number:
one is the deepest wet level of a 50-level grid, the other Copernicus's
own sea-floor diagnostic.
[`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md)
says which it used.

`CHL` is the case worth reading twice. Daily ocean colour is not the
monthly product at a finer step: it is `l4-gapfree`, the space-time
interpolated field, because a single day of a single sensor is mostly
cloud. The daily values are therefore already gap-filled by Copernicus,
and running
[`fill_satellite_gaps()`](https://chross22.github.io/datamatch/reference/fill_satellite_gaps.md)
over them fills nothing.
[`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md)
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
#>  [1] "SST"       "SSS"       "BOTT"      "BOTS"      "UO"        "VO"       
#>  [7] "SSH"       "MLD"       "SIC"       "CHL"       "PP"        "DIATO"    
#> [13] "DINO"      "NO3"       "PO4"       "O2"        "PH"        "CHL_MODEL"
#> [19] "NPP_MODEL" "WSPD"      "UWND"      "VWND"      "TAUX"      "TAUY"     
#> [25] "TAU"      
copernicus_variables()$SST$variable
#> [1] "thetao"
```
