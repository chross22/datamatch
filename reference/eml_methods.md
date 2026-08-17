# A methods section naming the sources that went into a table

The point of recording `<var>_source` on every join is that a table can
say where it came from afterwards. This turns that record into prose,
with the citation for each source that actually contributed — which is
otherwise the most tedious part of depositing a derived dataset, and the
easiest to get wrong once several fetches are chained.

## Usage

``` r
eml_methods(flat, x)
```

## Arguments

- flat:

  the table without geometry

- x:

  the original, for its own source stamp when no columns carry one

## Value

a list in EML `methods` shape
