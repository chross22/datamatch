# Match a model series' mean and variance to the satellite's

Computed over the cells where both sources have a value in this time
step, so the correction reflects conditions at the time rather than a
global average. Falls back to the uncorrected values when too few
overlapping cells exist to estimate a spread.

## Usage

``` r
rescale_to(values, model_step, model_var, satellite_step, satellite_var)
```

## Arguments

- values:

  model values to correct

- model_step:

  model data for this time step

- model_var:

  model column name

- satellite_step:

  satellite data for this time step

- satellite_var:

  satellite column name

## Value

the corrected values
