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

## Codes shared by two names

A derived entry names the code it is computed *from*, so that code
belongs to two entries: `so` is both `SSS`, which is what Copernicus
publishes under it, and the input to `BOTS`, which is not. Resolving a
raw code therefore considers only the entries that request it directly.
Asking for `"so"` gets surface salinity, which is what the code means;
bottom salinity is reachable by its catalog name, which is the only
thing that distinguishes it.
