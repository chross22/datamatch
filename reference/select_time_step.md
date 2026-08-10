# Resolve a `time` argument to a set of rows

Resolve a `time` argument to a set of rows

## Usage

``` r
select_time_step(env_dat, time)
```

## Arguments

- env_dat:

  an `sf` POINT object

- time:

  an index, or a named vector of YEAR/MONTH/DAY values

## Value

a list with `rows` and a `label`
