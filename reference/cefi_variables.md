# Catalog of CEFI variables under familiar names

Maps the names this package uses everywhere else onto the MOM6-COBALT
variable each comes from. The model's own names are terse and easy to
confuse — `tos` is the surface temperature and `tob` the sea-floor one,
`sos` and `sob` the salinities beside them — and a wrong one fetches a
real field of the wrong quantity rather than failing.

## Usage

``` r
cefi_variables()
```

## Value

a named list, one entry per variable, each with `variable`, `label`,
`units`, `scale`, `daily`, `surface_of` and `description`

## Units are converted, and that is the point

A covariate is only interchangeable across sources if it arrives in the
same units, so four of these are converted on the way out rather than
passed through:

- **`CHL`** — COBALT writes `chlos` in kg m-3. Multiplied by 1e6 to give
  mg/m3, which is what Copernicus and the satellite products use.

- **`NO3`, `PO4`, `O2`** — written in mol m-3, multiplied by 1000 to
  give mmol/m3.

- **`BOTO2`** — `btm_o2` is mol kg-1, multiplied by 1e6 to give umol/kg,
  which is what oxygen per unit mass is conventionally reported in and
  puts it on the same scale as `O2`'s mmol/m3. Note the basis: this is
  **per kilogram of seawater**, where `O2` is per cubic metre. Seawater
  is about 1025 kg/m3, so the two are close but not equal, and
  converting between them needs a density. That is why they are
  deliberately not given the same name.

The conversion factor is in each entry's `scale`, so what was done to a
value is readable rather than buried in the reader.

## What is monthly and what is also daily

The NWA12 hindcast saves everything monthly. Its **daily** output is
biogeochemistry only — `CHL`, `NO3`, `PH`, `PCO2`, `PHYC`, `MESOZOO` and
`BOTO2` — and carries no temperature, salinity, sea surface height,
mixed layer depth, ice or velocity at all. `daily` in each entry records
that, and
[`accessCEFI()`](https://chross22.github.io/datamatch/reference/accessCEFI.md)
refuses a daily request for a monthly-only variable rather than
returning an empty join.

## Primary production is not here

COBALT writes `intpp`, which is production integrated over the water
column in mol m-2 s-1. The package's `PP` is the satellite product's
volumetric rate in mg/m2/day. They are different quantities measured on
different bases, and giving them one name would make a nonsense of any
comparison, so CEFI simply has no `PP`. `MESOZOO` has the same shape of
caveat — it is a 200 m integral, in mol m-2 — and is given its own name
for that reason.

## See also

[`accessCEFI()`](https://chross22.github.io/datamatch/reference/accessCEFI.md),
[`cefi_dictionary()`](https://chross22.github.io/datamatch/reference/cefi_dictionary.md)
for a printable table

## Examples

``` r
names(cefi_variables())
#>  [1] "SST"     "SSS"     "BOTT"    "BOTS"    "SSH"     "MLD"     "SIC"    
#>  [8] "UO"      "VO"      "CHL"     "NO3"     "PO4"     "O2"      "PH"     
#> [15] "BOTO2"   "PCO2"    "PHYC"    "MESOZOO"
cefi_variables()$BOTS$variable
#> [1] "sob"
```
