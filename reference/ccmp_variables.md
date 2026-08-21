# Catalog of CCMP wind variables

CCMP is the Cross-Calibrated Multi-Platform ocean surface wind analysis
from Remote Sensing Systems: scatterometer and radiometer retrievals
combined with a model background onto a uniform grid. Names match the
Copernicus wind catalog where the quantity is the same, so a covariate
lands in a column of the same name whichever source supplied it.

## Usage

``` r
ccmp_variables()
```

## Value

a named list, one entry per variable, each with `variable`, `label`,
`units`, and `description`

## What it does not carry

**There is no wind stress.** CCMP publishes winds only, where the
Copernicus L4 product also carries `TAUX`, `TAUY` and `TAU`. Stress is
what actually enters the ocean and is roughly quadratic in speed, so it
cannot be recovered from these by rescaling — computing it means
choosing a drag coefficient, which is a modelling decision this package
does not make for you.

## NOBS is diagnostic, not a covariate

`NOBS` counts the satellite retrievals behind each cell and hour. Zero
means the value there is the model background alone rather than an
observation — which is worth knowing before treating CCMP as observed
data in a region or period with poor coverage.

## See also

[`accessCCMP()`](https://camilleross.org/datamatch/reference/accessCCMP.md),
[`ccmp_versions()`](https://camilleross.org/datamatch/reference/ccmp_versions.md)

## Examples

``` r
names(ccmp_variables())
#> [1] "WSPD" "UWND" "VWND" "NOBS"
```
