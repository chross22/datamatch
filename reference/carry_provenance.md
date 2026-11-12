# Carry a fetched object's provenance onto something derived from it

Resampling builds a new object from columns, and a new object starts
with none of the attributes the access function left on the old one.
Without this, an upscaled or retimed grid answered
[`source_of()`](https://camilleross.org/datamatch/reference/source_of.md)
with `NA`, and
[`matchData()`](https://camilleross.org/datamatch/reference/matchData.md)
wrote no `<var>_source` columns for it - so the record of which source a
value came from was lost at the first resample.

## Usage

``` r
carry_provenance(to, from, step = attr(from, "datamatch_step"))
```

## Arguments

- to:

  the derived object

- from:

  the object it was derived from

- step:

  the time step `to` is on, or `NULL` to carry `from`'s

## Value

`to`, with `datamatch_source` and `datamatch_step` set
