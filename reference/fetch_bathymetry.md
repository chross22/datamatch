# Fetch static bathymetry for a study area

Downloads NOAA ETOPO bathymetry via
[`marmap::getNOAA.bathy()`](https://rdrr.io/pkg/marmap/man/getNOAA.bathy.html)
and derives slope and aspect from it.

## Usage

``` r
fetch_bathymetry(
  bounding_box,
  resolution = 4,
  path = copernicus_cache("bathymetry"),
  keep = TRUE
)
```

## Arguments

- bounding_box:

  named list with `xmin`, `xmax`, `ymin`, `ymax`

- resolution:

  grid resolution in arc-minutes, as `marmap` defines it; smaller is
  finer and slower. 4 is roughly 7 km at mid latitudes.

- path:

  directory for the download cache; created if absent. Defaults to a
  `bathymetry` folder under
  [`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html), so
  downloads persist between sessions.

- keep:

  whether `marmap` should cache the downloaded grid for reuse. With
  `FALSE` nothing is written, so nothing can be read back later either.

## Value

a
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with one layer per variable in
[`bathymetry_variables()`](https://camilleross.org/datamatch/reference/bathymetry_variables.md),
in EPSG:4326

## Citation

The grid is NOAA NCEI ETOPO 2022, requested at 60 arc-second bedrock
resolution through `marmap`. Both want citing when the result is
published:

- NOAA National Centers for Environmental Information (2022). ETOPO 2022
  15 Arc-Second Global Relief Model.
  [doi:10.25921/fd45-gt74](https://doi.org/10.25921/fd45-gt74)

- Pante E, Simon-Bouhet B, Irisson J (2025). marmap: Import, Plot and
  Analyze Bathymetric and Topographic Data.
  [doi:10.32614/CRAN.package.marmap](https://doi.org/10.32614/CRAN.package.marmap)

The bounding box takes the same shape as
[`accessCopernicus()`](https://camilleross.org/datamatch/reference/accessCopernicus.md)'s,
so a single definition of the study area serves both.

## Caching

`marmap` caches downloads into the working directory by default, which
scatters them wherever R happened to be started. This puts them beside
the Copernicus cache instead, under
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html), so a
study area downloaded once stays downloaded across sessions. `path`
overrides that.

A grid already on disk is read with
[`marmap::read.bathy()`](https://rdrr.io/pkg/marmap/man/read.bathy.html)
rather than re-requested through
[`marmap::getNOAA.bathy()`](https://rdrr.io/pkg/marmap/man/getNOAA.bathy.html).
Both return the same object, but the second announces itself — "Querying
NOAA database", then "File already exists ; loading ..." — and there is
no reason to narrate a local file read. Reading directly also skips the
NOAA round trip entirely.

## Examples

``` r
if (FALSE) { # \dontrun{
bathy <- fetch_bathymetry(
  bounding_box = list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
)
terra::plot(bathy[["DEPTH"]])
} # }
```
