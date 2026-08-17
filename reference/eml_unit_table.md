# Units this package uses, mapped onto the EML vocabulary

EML validates units against a fixed list, and rejects a document using a
name that is not on it. Several of this package's units are not: **`PSU`
and `N/m2` are both invalid as standard units**, which matters because
salinity and wind stress are core variables here. Those are emitted as
*custom* units instead, declared in the document's own `unitList`, which
is the mechanism EML provides for exactly this and is what data
repositories expect.

## Usage

``` r
eml_unit_table()
```

## Value

a data frame with `units` (as this package writes them), `eml`, and
`standard` (whether it is a standard EML unit or needs declaring)

## Details

Which names are valid was established by validating documents against
the schema rather than by reading a list — `milligramsPerCubicMeter` is
accepted and `milligramPerCubicMeter` is not, and there is no way to
tell from the outside which spelling a vocabulary chose.
