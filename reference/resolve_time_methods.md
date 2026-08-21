# Resolve temporal method names, per variable

Mirrors
[`resolve_methods()`](https://camilleross.org/datamatch/reference/resolve_methods.md)
for the time axis. Factor levels for categorical columns are attached to
the result, since the aggregation needs them and recomputing them per
variable would risk two different level orders.

## Usage

``` r
resolve_time_methods(method, vars, env_dat, direction)
```

## Arguments

- method:

  the user's `method` argument

- vars:

  the variables being resampled

- env_dat:

  the source object, for column types

- direction:

  `"up"` or `"down"`

## Value

named character vector of methods, with a `levels` attribute
