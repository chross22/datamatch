# The aggregation function behind a temporal method name

All of them drop missing values, and all return `NA` rather than the
`Inf` or `NaN` that `min`, `max`, and `mean` produce on an empty vector
— an `Inf` would otherwise travel silently into a model.

## Usage

``` r
time_method_fun(name)
```

## Arguments

- name:

  a method name

## Value

a function taking a numeric vector and returning one number
