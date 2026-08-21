# Attach climate indices to observations

Joins one or more monthly indices by year and month. Because an index
has no spatial dimension, every observation in a month receives the same
value.

## Usage

``` r
attach_climate_index(
  dat,
  indices,
  years = NULL,
  year_col = "YEAR",
  month_col = "MONTH"
)
```

## Arguments

- dat:

  a data frame or `sf` object with year and month columns

- indices:

  index names to attach, or a data frame from
  [`fetch_climate_index()`](https://camilleross.org/datamatch/reference/fetch_climate_index.md)

- years:

  years to fetch; defaults to those present in `dat`

- year_col, month_col:

  names of the year and month columns

## Value

`dat` with one column per index. Months with no published value are
`NA`.

## Examples

``` r
if (FALSE) { # \dontrun{
observations <- attach_climate_index(observations, c("NAO", "AMO"))
} # }
```
