# Everything the catalogs know about a variable name

The five source catalogs each hold a label and units for the names they
offer, and EML wants both for every column. Gathered here so a matched
table can be described without the caller repeating what the package
already knows.

## Usage

``` r
known_variables()
```

## Value

a named list, one entry per known variable, each with `label` and
`units`

## Details

Where two sources define the same name — which is the whole point of the
shared vocabulary — the first found wins. They agree on units by
construction; a test checks that.
