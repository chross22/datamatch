# Which catalog names are wind variables

Wind comes from its own product and behaves unlike the ocean variables
at several points — no daily step, no forecast, its own grid — so the
error messages that explain those need to know which names are winds.
Derived from the catalog rather than listed again, so a wind entry added
later is covered without touching this.

## Usage

``` r
wind_variables()
```

## Value

the catalog names served by the wind product
