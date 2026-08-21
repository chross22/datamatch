# Fetch the CEFI time steps that are not already cached

Fetch the CEFI time steps that are not already cached

## Usage

``` r
cefi_fetch(spec, entries, files, plan, bounding_box, frequency, init)
```

## Arguments

- spec:

  an archive spec

- entries:

  the requested entries of
  [`cefi_variables()`](https://chross22.github.io/datamatch/reference/cefi_variables.md)

- files:

  the directory listing

- plan:

  a data frame of `key` and `member`, one row per wanted step

- bounding_box:

  the box, negative west

- frequency:

  `"monthly"` or `"daily"`

- init:

  the initialisation tag, or `NULL`

## Value

a list aligned with `plan`'s rows, each a data frame or `NULL` where the
archive does not cover that step
