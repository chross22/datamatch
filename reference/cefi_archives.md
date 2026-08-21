# The CEFI regional MOM6 runs this package ships with

CEFI is NOAA's Changing Ecosystems and Fisheries Initiative, and the
part of it this package reads is the regional MOM6-COBALT output
published by the Physical Sciences Laboratory. What is built in here is
the **Northwest Atlantic** domain (NWA12) — the US east coast, the Gulf
of Mexico and the Caribbean, at a twelfth of a degree.

## Usage

``` r
cefi_archives()
```

## Value

a named list, one entry per archive, each with `path`, `domain`,
`experiment`, `frequency`, `grid`, `release`, `kind`, `start`, `end`,
`variables`, `label` and `reference`

## Why reach for it

Every other model in this package is global, run once for the whole
ocean and sampled wherever you happen to work. NWA12 is the opposite: a
regional configuration built for this shelf, with a coupled
biogeochemistry (COBALT) that carries nutrients, oxygen, carbonate
chemistry and plankton biomass on the same grid as the physics. The
Copernicus biogeochemical reanalysis is a quarter degree; this is a
twelfth, and it resolves the Gulf of Maine and the Scotian Shelf rather
than smoothing across them.

It also publishes **sea-floor salinity directly** as `sob`, where
GLORYS12V1 does not — so `BOTS` from CEFI is the model's own diagnostic
rather than the deepest-wet-level derivation
[`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md)
has to fall back on.

## The regridded product is what is read

MOM6 runs on a curvilinear grid, and CEFI publishes both that (`raw`)
and a regular latitude-longitude interpolation of it (`regrid`). This
package reads the regridded files, because a regular grid is what
everything downstream here expects and what makes an NWA12 field overlay
a Copernicus one.

That is a real choice and not a free one: the regridding is bilinear, so
values near the coast and near the ice edge have been interpolated
across cells the model treated separately. Where that matters, read the
`raw` files yourself rather than through this.

The velocities are the exception worth naming. CEFI publishes
`uo_rotate` and `vo_rotate`, already rotated onto true east and north,
so `UO` and `VO` here are in the same frame as every other source rather
than in the model's own grid directions.

## Hindcast and forecast are different products

`hindcast` is a reconstruction forced by reanalysis and is the entry to
reach for. `decadal_forecast` is a ten-year prediction initialised each
January, with ten ensemble members, and is a fundamentally different
kind of number — see the Forecasts are experimental section of
[`accessCEFI()`](https://chross22.github.io/datamatch/reference/accessCEFI.md).

## See also

[`accessCEFI()`](https://chross22.github.io/datamatch/reference/accessCEFI.md),
[`cefi_archive()`](https://chross22.github.io/datamatch/reference/cefi_archive.md)
for any other CEFI path

## Examples

``` r
names(cefi_archives())
#> [1] "NWA12"         "NWA12_DECADAL"
cefi_archives()$NWA12$path
#> [1] "Projects/CEFI/regional_mom6/cefi_portal/northwest_atlantic/full_domain/hindcast"
```
