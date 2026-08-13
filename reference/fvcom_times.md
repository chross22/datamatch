# Time steps of an FVCOM archive, as dates

Computed from `Itime`, the integer day count, and not from the `Times`
character axis beside it. Both are present and `Times` is the more
obvious choice, but on the 30-year GOM3 mean it is corrupt: the first
step reads `1878-01-14T03:009//-500000`, a century out with a mangled
time. Parsing it would silently place the whole record in the wrong era.

## Usage

``` r
fvcom_times(handle)
```

## Arguments

- handle:

  an open `ncdf4` handle

## Value

a `Date` vector, one per time step

## Details

`Itime` is sound, and its `units` attribute declares the epoch
(`days since 1858-11-17`, the Modified Julian Day epoch). The epoch is
read from that attribute rather than assumed, so an archive counting
from some other origin is handled rather than misread.
