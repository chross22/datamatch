# Human-readable labels for time steps

Drops components that never vary, so a single year's monthly data is
labelled by month rather than by a repeated year.

## Usage

``` r
step_labels(steps, time_cols)
```

## Arguments

- steps:

  a data frame of unique time steps

- time_cols:

  which time columns are present

## Value

character vector
