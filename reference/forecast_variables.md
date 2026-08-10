# Forecast equivalents of the catalog variables

Where the reanalysis has a hindcast, the analysis-and-forecast products
have a near-real-time equivalent running to about ten days ahead. This
maps each catalog name onto the forecast product, dataset, and code that
supply it.

## Usage

``` r
forecast_variables()
```

## Value

a named list keyed by catalog name, each with `variable`, `product_id`,
`dataset_id`, and `daily_dataset_id`

## Details

Two things make this a real mapping rather than a substitution of one
identifier for another:

- **The forecast products split variables across datasets.** The
  reanalysis serves all its physics from one dataset; the forecast has
  separate ones for temperature, salinity, and currents. So a forecast
  fetch of SST and SSS is two requests where the reanalysis is one.

- **Some codes differ.** Bottom temperature is `bottomT` in the
  reanalysis and `tob` in the forecast. Reusing the reanalysis code
  would produce a failed download.

Satellite variables have no forecast: ocean colour is observation, and
an observation of the future does not exist. `CHL`, `PP`, `DIATO`, and
`DINO` are therefore absent here, and asking for them in forecast mode
says so.

## See also

[`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md),
which takes `mode = "forecast"`

## Examples

``` r
names(forecast_variables())
#>  [1] "SST"       "SSS"       "UO"        "VO"        "SSH"       "MLD"      
#>  [7] "SIC"       "BOTT"      "NO3"       "PO4"       "O2"        "NPP_MODEL"
#> [13] "CHL_MODEL" "PH"       
forecast_variables()$BOTT$variable   # "tob", not "bottomT"
#> [1] "tob"
```
