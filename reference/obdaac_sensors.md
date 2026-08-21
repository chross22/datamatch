# Ocean colour sensors read through NASA OB.DAAC

OB.DAAC is NASA's Ocean Biology Distributed Active Archive Center, and
it holds the ocean colour record — every mission from SeaWiFS in 1997 to
PACE, all reprocessed together so that a series crossing from one sensor
to the next is crossing between consistent products rather than between
eras.

## Usage

``` r
obdaac_sensors()
```

## Value

a named list, one entry per sensor, each with `id`, `prefix`, `start`,
`end`, `suites`, `resolutions`, `label` and `reference`

## Why reach for it, and why not

[`accessERDDAP()`](https://chross22.github.io/datamatch/reference/accessERDDAP.md)
serves satellite chlorophyll with no account at all, which is genuinely
easier, and it is the right first stop. What it cannot give you is
**length**: its VIIRS entries begin in 2012 at the earliest. OB.DAAC has
SeaWiFS from September 1997, which is the difference between a decade of
chlorophyll and nearly three, and it has the sensors either side of any
gap you need to bridge.

It also carries what ocean colour measures besides chlorophyll — diffuse
attenuation, photosynthetically available radiation, particulate organic
and inorganic carbon — on the same grid, from the same retrieval.

Against that: **every fetch needs an Earthdata Login**, which is the one
place in this package where a download will not work until you have gone
and created an account.
[`accessOBDAAC()`](https://chross22.github.io/datamatch/reference/accessOBDAAC.md)
says how.

## The sensors are not interchangeable

They overlap, and where they overlap they disagree. Two sensors' `CHL`
on the same day are two retrievals with different bands, different
atmospheric corrections and different calibration histories, and
stitching a series across a mission boundary puts a step in it that is
instrumental rather than oceanographic.
[`source_of()`](https://chross22.github.io/datamatch/reference/source_of.md)
records which sensor produced a fetch for exactly this reason.

Where a long consistent record matters more than any one sensor, prefer
a merged product — the Copernicus-GlobColour entries in
[`copernicus_variables()`](https://chross22.github.io/datamatch/reference/copernicus_variables.md)
are multi-sensor and built for that.

## What each carries

|           |                  |                    |
|-----------|------------------|--------------------|
| `SEAWIFS` | colour only      | 1997-09 to 2010-12 |
| `MODIST`  | colour, SST, FLH | 2000-02 onward     |
| `MODISA`  | colour, SST, FLH | 2002-07 onward     |
| `VIIRS`   | colour, SST      | 2012-01 onward     |
| `VIIRSJ1` | colour, SST      | 2017-12 onward     |
| `VIIRSJ2` | colour only      | 2023-03 onward     |

Every start and end above was read out of the archive rather than taken
from a mission description, so they are the first and last day OB.DAAC
actually publishes a Level-3 field for.

## Why PACE is not here

PACE is the newest ocean colour mission and its absence is deliberate,
for two reasons that compound.

Its standard Level-3 mapped catalog publishes inherent optical
properties, diffuse attenuation, PAR and surface reflectance — and **no
chlorophyll suite**. PACE chlorophyll exists, but not on this path, so
the one variable most people would come to it for is not what this route
would give them.

What is left could still be read, except that PACE names a processing
version where every older sensor names a product —
`PACE_OCI.20250615.L3m.DAY.KD.V3_2.4km.nc` against
`AQUA_MODIS.20200601.L3m.DAY.KD.Kd_490.4km.nc`. That version changes
with each reprocessing and cannot be constructed, only looked up, and
looking it up needs OB.DAAC's file search, which accepts POST only.
Hard-coding a version would work until the next reprocessing and then
fail silently.

Read PACE directly with `earthdatalogin` or `rsi` where you need it.

## See also

[`accessOBDAAC()`](https://chross22.github.io/datamatch/reference/accessOBDAAC.md),
[`obdaac_variables()`](https://chross22.github.io/datamatch/reference/obdaac_variables.md)

## Examples

``` r
names(obdaac_sensors())
#> [1] "SEAWIFS" "MODIST"  "MODISA"  "VIIRS"   "VIIRSJ1" "VIIRSJ2"
obdaac_sensors()$MODISA$start
#> [1] "2002-07-04"
```
