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

- **`BOTS` stops being derived.** The forecast publishes sea-floor
  salinity as `sob`, so what the reanalysis has to compute from the
  three-dimensional field is a plain variable request here.

Satellite variables have no forecast: ocean colour is observation, and
an observation of the future does not exist. `CHL`, `PP`, `DIATO`, and
`DINO` are therefore absent here, and asking for them in forecast mode
says so.

Neither do the wind variables, for a different reason. Copernicus
publishes a near-real-time wind analysis, but it is hourly only and
reaches the present rather than past it, so there is no monthly forecast
field to map onto. It is an analysis of what the wind has just done, not
a prediction.

## See also

[`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md),
which takes `mode = "forecast"`

## Examples

``` r
names(forecast_variables())
#>  [1] "SST"       "SSS"       "UO"        "VO"        "SSH"       "MLD"      
#>  [7] "SIC"       "BOTT"      "BOTS"      "NO3"       "PO4"       "O2"       
#> [13] "NPP_MODEL" "CHL_MODEL" "PH"       
forecast_variables()$BOTT$variable   # "tob", not "bottomT"
#> [1] "tob"
```
