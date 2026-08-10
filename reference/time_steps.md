# Distinct time steps, their rows, and their labels

Shared by the plotting functions so they all agree on what a time step
is and order them the same way.

## Usage

``` r
time_steps(env_dat)
```

## Arguments

- env_dat:

  an `sf` POINT object

## Value

a list with `table` (unique steps), `rows` (row indices per step), and
`labels`
