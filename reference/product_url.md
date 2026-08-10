# Copernicus Marine product page for a product identifier

Where to check a product's coverage, resolution, revision history, and
citation. Dataset identifiers change from time to time, and this is the
page that says what the current one is.

## Usage

``` r
product_url(product_id)
```

## Arguments

- product_id:

  a Copernicus product identifier

## Value

the product page URL

## Examples

``` r
product_url("GLOBAL_MULTIYEAR_PHY_001_030")
#> [1] "https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description"
```
