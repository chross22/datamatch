# Everything the catalogs know about a variable name

Each source catalog holds a label and units for the names it offers, and
EML wants both for every column. Gathered here so a matched table can be
described without the caller repeating what the package already knows.

## Usage

``` r
known_variables()
```

## Value

a named list, one entry per known variable, each with `label` and
`units`

## Details

Every catalog has to be listed here, and nothing enforces that: a source
added without being added here still fetches, still joins, and then
writes EML in which its columns have no definition and no units. The
unit table test catches a unit with no mapping, not a catalog with no
entry.

Where two sources define the same name — which is the whole point of the
shared vocabulary — the first found wins. They agree on units by
construction; a test checks that.
