# Turn cached OB.DAAC subsets into the object a fetch returns

Separate from
[`accessOBDAAC()`](https://camilleross.org/datamatch/reference/accessOBDAAC.md)
because a call that finds everything already cached returns here without
touching the network, credentials or the file search - and that path has
to build exactly the same object as the one that downloaded it.

## Usage

``` r
obdaac_assemble(paths, sensor, resolution, frequency)
```

## Arguments

- paths:

  cached subset files

- sensor, resolution, frequency:

  what produced them

## Value

one row per grid cell per time step, stamped with its step and its
source
