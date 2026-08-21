# The derived variable in a request, if there is one

Most variables are a straight request for a Copernicus code. A derived
one is computed here instead, from a field the dataset does serve —
`BOTS` from the full salinity column — which makes it a different kind
of download rather than another variable in the same one.

## Usage

``` r
derived_request(vars, mode = "reanalysis")
```

## Arguments

- vars:

  variable names, as the caller wrote them

- mode:

  `"reanalysis"` or `"forecast"`

## Value

`NULL` when nothing is derived, or `list(name =, code =, how =)`

## Why it has to be fetched alone

A derived variable needs a depth range no surface variable wants: the
whole column, roughly fifty levels, where `SST` wants one. Honouring
both in a single request is not possible, and the alternatives are each
worse than refusing. Fetching the column and taking its surface for the
other variables would download fifty times the data to discard it.
Issuing a second, quieter download behind one call would break the rule
the rest of the package holds to, that one
[`accessCopernicus()`](https://camilleross.org/datamatch/reference/accessCopernicus.md)
call is one dataset request.

So it is an error, in the same spirit as mixing two products, and the
fix is the same: call twice and chain
[`matchData()`](https://camilleross.org/datamatch/reference/matchData.md).
