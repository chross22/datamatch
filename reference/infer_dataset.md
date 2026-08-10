# Infer the product and dataset from a set of variable names

When every requested variable is in the catalog, the product and dataset
are implied, so a call need not repeat identifiers that are already
known.

## Usage

``` r
infer_dataset(
  vars,
  mode = c("reanalysis", "forecast"),
  frequency = c("monthly", "daily")
)
```

## Arguments

- vars:

  variable names

- mode:

  `"reanalysis"` or `"forecast"`

- frequency:

  `"monthly"` or `"daily"`

## Value

`list(product_id =, dataset_id =)`

## Details

Variables from different datasets cannot be fetched in one request, so
mixing them is an error here rather than a confusing failure at the API.
