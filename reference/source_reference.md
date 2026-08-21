# The citation for a source tag such as `"hycom:GLBv53X"`

The citation for a source tag such as `"hycom:GLBv53X"`

## Usage

``` r
source_reference(tag)
```

## Arguments

- tag:

  a tag as
  [`source_of()`](https://camilleross.org/datamatch/reference/source_of.md)
  returns

## Value

the reference, or `NA` when the source carries none

## Every source family needs a branch here

A family with none returns `NA`, and
[`eml_methods()`](https://camilleross.org/datamatch/reference/eml_methods.md)
then writes a methods section that names the source and cites nothing —
which is the failure the methods section exists to prevent, arriving
silently. A test walks the families rather than trusting this list to
stay complete.

## Where the citation is a pointer rather than a reference

Copernicus and OB.DAAC both mint a DOI per dataset per reprocessing, and
those move: OB.DAAC's version token differs by suite and by mission, so
a `PAR` DOI ending 2022 resolves where the matching `SST` one ending
2019 does not. A table of them hard-coded here would be wrong at the
next reprocessing and wrong silently, so both name the dataset precisely
and say where its DOI lives instead. The mission or model paper is given
alongside, because it is stable and is a different obligation from the
data citation.
