# Catalog of OB.DAAC variables under familiar names

Maps the names this package uses onto the product suite and the variable
inside it that supply them.

## Usage

``` r
obdaac_variables()
```

## Value

a named list, one entry per variable, each with `suite`, `variable`,
`label`, `units` and `description`

## Which SST this is

MODIS and VIIRS publish more than one sea surface temperature, and they
are different measurements rather than different names for one:

- **`SST`** is the 11 um retrieval from the daytime pass, which sees the
  skin of the ocean including whatever the sun has warmed that
  afternoon.

- **`SST_NIGHT`** is the same 11 um retrieval from the night pass, with
  that diurnal warming absent. It is the one to use where a comparison
  across days or sensors has to be like for like.

Neither is the foundation temperature that `MUR` in
[`erddap_datasets()`](https://camilleross.org/datamatch/reference/erddap_datasets.md)
analyses, and none of the three is the topmost model level that a
reanalysis calls `SST`. All four arrive in a column called `SST` unless
you ask for the night one, and
[`source_of()`](https://camilleross.org/datamatch/reference/source_of.md)
is what tells them apart.

## Chlorophyll is not gap-free

These are single-sensor Level-3 composites, so a daily field is mostly
cloud outside the tropics and a `CHL` column from one is mostly `NA`.
That is the honest state of the measurement rather than a fault, and
there are three ways through it: composite in time by asking for
`frequency = "8day"` or `"monthly"`, interpolate with
[`fill_satellite_gaps()`](https://camilleross.org/datamatch/reference/fill_satellite_gaps.md),
which records what it filled, or use a gap-free product — the daily
Copernicus `CHL` and the `VIIRSCHL` entry in
[`erddap_datasets()`](https://camilleross.org/datamatch/reference/erddap_datasets.md)
are both already interpolated.

## See also

[`accessOBDAAC()`](https://camilleross.org/datamatch/reference/accessOBDAAC.md),
[`obdaac_dictionary()`](https://camilleross.org/datamatch/reference/obdaac_dictionary.md)
for a printable table

## Examples

``` r
names(obdaac_variables())
#> [1] "CHL"       "KD490"     "PAR"       "POC"       "PIC"       "SST"      
#> [7] "SST_NIGHT" "NFLH"     
obdaac_variables()$CHL$suite
#> [1] "CHL"
```
