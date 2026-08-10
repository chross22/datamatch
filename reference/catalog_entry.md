# Catalog entry for a name or a Copernicus code

Either identifier resolves, so a call that passes raw codes gets the
same dataset inference as one using catalog names.

## Usage

``` r
catalog_entry(var, mode = "reanalysis")
```

## Arguments

- var:

  a catalog name (`"SST"`) or a Copernicus code (`"thetao"`)

- mode:

  `"reanalysis"` or `"forecast"`

## Value

the catalog entry, or `NULL` if the variable is not in the catalog
