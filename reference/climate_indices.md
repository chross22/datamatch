# Catalog of basin-scale climate indices

Unlike the gridded variables, these have **no spatial dimension** — one
value per month describes the whole basin. They enter a model as a
shared state every observation in a month experiences, which is a
different kind of covariate from local temperature: they carry no
information about *where* within a region conditions are better, only
about what year and season it was.

## Usage

``` r
climate_indices()
```

## Value

a named list, one entry per index, each with `label`, `units`, `source`,
`url`, and `description`

## Details

That makes them useful for interannual questions ("was this a
warm-regime year?") and useless for spatial ones. A model given only
indices cannot produce a map.

## See also

[`fetch_climate_index()`](https://chross22.github.io/datamatch/reference/fetch_climate_index.md),
[`attach_climate_index()`](https://chross22.github.io/datamatch/reference/attach_climate_index.md)

## Examples

``` r
names(climate_indices())
#> [1] "NAO"  "AO"   "AMO"  "PDO"  "LCR"  "AMOC"
```
