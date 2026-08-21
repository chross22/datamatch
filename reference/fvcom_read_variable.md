# Read one variable at one time step

Read one variable at one time step

## Usage

``` r
fvcom_read_variable(handle, entry, step, layers, keep)
```

## Arguments

- handle:

  an open `ncdf4` handle

- entry:

  one entry of
  [`fvcom_variables()`](https://camilleross.org/datamatch/reference/fvcom_variables.md)

- step:

  the time index to read

- layers:

  how many sigma layers the archive has

- keep:

  mesh indices to retain

## Value

one value per kept point
