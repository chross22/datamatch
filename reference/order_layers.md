# Put a downloaded raster's layers into the order they were requested

Copernicus returns layers in the NetCDF's own order, which is
alphabetical by variable code and has nothing to do with the order they
were asked for. Column names are assigned from `vars`, so the two have
to be reconciled before naming or the names land on the wrong layers.

## Usage

``` r
order_layers(x, vars)
```

## Arguments

- x:

  a `SpatRaster` read from a Copernicus download

- vars:

  variable codes, in the order they were requested

## Value

`x`, with one layer per requested code, in that order

## Details

That failure is silent and severe: requesting `c("SST", "SSS")` sends
`c("thetao", "so")`, gets back `so` then `thetao`, and would label
salinity as temperature and temperature as salinity with nothing to
indicate it. Matching by name rather than position is the whole point of
this function.

## Layer names

Three-dimensional variables come back as `thetao_depth=0.494025`, so the
depth suffix is stripped before matching. Two-dimensional ones such as
`mlotst` and `zos` carry no suffix.

A code appearing on more than one layer means the depth range spanned
several model levels. That is reported as such, rather than left to be
caught later by a column count that cannot say which variable caused it.
