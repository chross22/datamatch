# Read one HYCOM variable over a window at one time step

Read one HYCOM variable over a window at one time step

## Usage

``` r
hycom_read_variable(handle, entry, step, lon_window, lat_window)
```

## Arguments

- handle:

  an open `ncdf4` handle

- entry:

  one entry of
  [`hycom_variables()`](https://camilleross.org/datamatch/reference/hycom_variables.md)

- step:

  the time index

- lon_window, lat_window:

  output of
  [`hycom_window()`](https://camilleross.org/datamatch/reference/hycom_window.md)

## Value

a numeric matrix, longitude by latitude
