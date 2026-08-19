# The per-row source tags of a fetch, where it has them

`NULL` for the usual case of a fetch from a single archive, whose source
is one value for the whole object and is held as an attribute instead.

## Usage

``` r
row_sources(x)
```

## Arguments

- x:

  a fetched object

## Value

one tag per row, or `NULL`
