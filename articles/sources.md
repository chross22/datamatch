# Choosing a data source

datamatch fetches from five sources and joins any of them to your
observations the same way. This is about which one to reach for, and
what changes when you do.

Nothing here is downloaded when the vignette is built — the fetches are
shown but not run, because each needs a network and some need several
gigabytes.

## The five, side by side

|  | [`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md) | [`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md) | [`accessHYCOM()`](https://chross22.github.io/datamatch/reference/accessHYCOM.md) | [`accessCCMP()`](https://chross22.github.io/datamatch/reference/accessCCMP.md) | [`accessERDDAP()`](https://chross22.github.io/datamatch/reference/accessERDDAP.md) |
|----|----|----|----|----|----|
| Source | Copernicus Marine | NECOFS / any FVCOM | HYCOM GOFS 3.1 | RSS CCMP v3.1 | NOAA ERDDAP |
| Kind | global reanalysis, forecast, satellite | regional coastal model | global model | wind analysis | satellite analysis |
| Grid | 0.083°–4 km, regular | unstructured mesh | 0.08° regular | 0.25° regular | 0.01°–0.04° regular |
| Steps | monthly, daily, hourly | monthly (GOM3), hourly (GOM7) | 3-hourly | 6-hourly | daily |
| Record | 1993– | 1978–2013, then 2025– | 1994–2024 across archives | 1993–present | 2002– (SST), 2012– (chl) |
| Bottom salinity | derived | free | free | — | — |
| Wind stress | yes | GOM3 only | — | — | — |
| Subsetting | server-side | client-side | server-side | **whole globe** | server-side |
| Account needed | yes | no | no | no | no |

Two of those records are chains rather than one run, and the gaps matter
more than the endpoints. **FVCOM has nothing between 2014 and 2024** —
the GOM3 hindcast stops in 2013 and the GOM7 forecast archive starts in
2025, on a different mesh. **HYCOM reaches 2024 only by crossing from
the reanalysis into a series of operational experiments**, which is a
seam in how the values were produced. `hycom_covering(date)` says which
archives hold a given day.

``` r

variable_dictionary()   # Copernicus
fvcom_dictionary()      # FVCOM
hycom_dictionary()      # HYCOM
ccmp_dictionary()       # CCMP
erddap_dictionary()     # MUR and VIIRS
```

## They share variable names on purpose

A covariate arrives in a column of the same name whichever source
supplied it, so everything downstream —
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md),
resampling, plotting, and whatever model you fit — works unchanged:

``` r

bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

copernicus <- accessCopernicus(vars = "SST", years = 2010, months = 1:12, bounding_box = bb)
fvcom      <- accessFVCOM(vars = "SST", years = 2010, months = 1:12, bounding_box = bb)
hycom      <- accessHYCOM(vars = "SST", years = 2010, months = 1:12, bounding_box = bb)
```

All three produce an `SST` column. **They are three different models and
three different numbers.** Sharing the name makes them mechanically
interchangeable, which is the point; it does not make them
scientifically interchangeable, which is why it is worth recording which
you used.

That property is useful deliberately. Fetching the same variable from
two sources and comparing them is a real check on a result:

``` r

matched <- matchData(observations, copernicus)          # SST
matched <- matchData(matched, hycom)                    # SST.matched

plot(matched$SST, matched$SST.matched)
```

A colliding name is suffixed `.matched` rather than overwriting yours,
so both survive the join and the disagreement is visible.

## Which to reach for

**Start with Copernicus.** It has the widest variable list — physics,
biogeochemistry, satellite ocean colour, wind and stress — the longest
record with a forecast, and server-side subsetting. Everything else here
is for something Copernicus does not do well.

**Reach for FVCOM when the coast is the point.** A Gulf of Maine box
holding 1,742 GLORYS cells holds 6,579 GOM3 nodes, concentrated where
the bathymetry is complicated. If your question is about a shelf, a
bank, or a channel rather than a basin, that resolution is the reason.
The hindcast ends in 2013; the GOM7 forecast archive picks up in 2025 on
a different mesh, with nothing in between.

**Reach for HYCOM for bottom fields, or for a second opinion.** It
publishes `salinity_bottom` and `water_temp_bottom` as real fields where
Copernicus has no bottom salinity at all, and being an independent model
it makes agreement meaningful. The reanalysis covers 1994–2015;
operational archives carry it to September 2024.

**Reach for CCMP for winds over a long record.** Six-hourly from 1993 to
within days of the present, where the Copernicus wind is monthly from
mid-1994 or hourly only from 2007. But it carries no stress.

**Reach for ERDDAP for resolution.** MUR is 0.01° — about a kilometre,
against nine for the physics reanalysis — and needs no account, where
the same product at PO.DAAC needs an Earthdata login. It is a satellite
analysis of the *foundation* temperature rather than a model level,
which is a different quantity from a model `SST`, not a better
measurement of the same one.

## Bottom salinity, four ways

`BOTS` is the clearest case of the same name costing different amounts:

``` r

# Copernicus reanalysis: derived. Fetches ~50 depth levels to keep the deepest
# wet one, so it must be fetched alone, and reports the depth it used.
bots <- accessCopernicus(vars = "BOTS", years = 2010, months = 1:12, bounding_box = bb)
bots$BOTS_depth

# Copernicus forecast: published outright as `sob`, no derivation.
accessCopernicus(vars = c("BOTT", "BOTS"), years = 2026, months = 7,
             bounding_box = bb, mode = "forecast")

# FVCOM: the deepest sigma layer is the sea floor everywhere. Free.
accessFVCOM(vars = c("BOTT", "BOTS"), years = 2010, months = 1:12, bounding_box = bb)

# HYCOM: `salinity_bottom` is its own field. Free.
accessHYCOM(vars = c("BOTT", "BOTS"), years = 2010, months = 1:12, bounding_box = bb)
```

Only the first is expensive, and only the first returns `BOTS_depth` —
because only the first had to choose a level. The deepest wet model
level is not the sea floor, and in deep water sits well above it, so the
depth is reported rather than left to assume.

## Sub-daily data, and means that are not means

Four of the five publish below daily somewhere, and none of them
publishes a daily mean:

| Source          | Native step | `frequency`                              |
|-----------------|-------------|------------------------------------------|
| Copernicus wind | hourly      | `"hourly"`                               |
| FVCOM `GOM7`    | hourly      | `"hourly"`, or `"daily"` for a snapshot  |
| HYCOM           | 3-hourly    | `"3hourly"`, or `"daily"` for a snapshot |
| CCMP            | 6-hourly    | `"6hourly"`, or `"daily"` for a snapshot |

Where a source has no mean, none is invented. `frequency = "daily"` on
HYCOM and CCMP takes one **snapshot** at a chosen hour — an instant, not
an average. A real mean is
[`upscale_time()`](https://chross22.github.io/datamatch/reference/upscale_time.md)’s
job, which keeps the aggregation visible and the choice of summary
yours:

``` r

steps <- accessCCMP(vars = c("UWND", "VWND"), frequency = "6hourly",
                    dates = "2010-06-15", bounding_box = bb)

mean_wind <- upscale_time(steps, to = "day")
peak_wind <- upscale_time(steps, to = "day", method = "max")
```

The coverage check knows each source’s own step, so a complete CCMP day
scores 4/4 rather than 4/24.

One caution that is easy to miss: **a mean of the components is not a
mean speed.** Averaging `UWND` and `VWND` over a day and taking the
magnitude gives the net displacement of air; averaging `WSPD` gives how
hard it blew. On a day the wind reversed, the first is near zero and the
second is not.

## Longitude, and one trap handled for you

Pass `bounding_box` with longitudes **negative west** to every function
here. CCMP is stored on a 0–360 grid and is converted on the way in and
back on the way out, so its results overlay the others without
adjustment. You should never have to think about it — but if you fetch
CCMP by hand elsewhere, that is the difference between the Gulf of Maine
and the Indian Ocean.

## Putting several together

The pattern is the same as chaining two Copernicus products: each call
adds columns and leaves the row count alone.

``` r

matched <- matchData(observations, accessCopernicus(vars = c("SST", "MLD"),
                                                years = 2010, months = 1:12,
                                                bounding_box = bb))
matched <- matchData(matched, accessHYCOM(vars = "BOTS", years = 2010,
                                          months = 1:12, bounding_box = bb))
matched <- matchData(matched, accessCCMP(vars = "WSPD", years = 2010,
                                         months = 1:12, bounding_box = bb))

matched <- attach_bathymetry(matched, fetch_bathymetry(bounding_box = bb),
                             c("DEPTH", "SLOPE"))
matched <- attach_climate_index(matched, "NAO")

colSums(is.na(sf::st_drop_geometry(matched)))
```

Each source fails differently at the edges of its record — FVCOM after
2013, HYCOM after 2015, `LCR` after 2014 — so that last line is worth
running before fitting anything.

## What to cite

Every source here is somebody else’s work, and the obligation to cite
travels with the data rather than with this package. **Cite whichever
products you actually fetched from.** Several catalogs carry their
references at runtime:

``` r

fvcom_archives()$GOM3$reference
hycom_archives()$GLBv53X$reference
ccmp_versions()$`v03.1`$reference
index_dictionary()          # carries the climate index references
```

### Copernicus Marine Service

[Copernicus asks for a specific
form](https://help.marine.copernicus.eu/en/articles/4444611-how-to-cite-copernicus-marine-products-and-services),
including the access date:

> *Product Title*. E.U. Copernicus Marine Service Information (CMEMS).
> Marine Data Store (MDS). DOI: 10.48670/moi-xxxxx (Accessed on DD MMM
> YYYY)

Reanalysis products, used by default:

| Product | Supplies | DOI |
|----|----|----|
| Global Ocean Physics Reanalysis (GLORYS12V1) | `SST`, `SSS`, `BOTT`, `BOTS`, `UO`, `VO`, `SSH`, `MLD`, `SIC` | [10.48670/moi-00021](https://doi.org/10.48670/moi-00021) |
| Global Ocean Biogeochemistry Hindcast | `CHL_MODEL`, `NPP_MODEL`, `NO3`, `PO4`, `O2`, `PH` | [10.48670/moi-00019](https://doi.org/10.48670/moi-00019) |
| Global Ocean Colour (Copernicus-GlobColour) | satellite `CHL`, `PP`, `DIATO`, `DINO` | [10.48670/moi-00281](https://doi.org/10.48670/moi-00281) |
| Global Ocean Monthly Mean Sea Surface Wind and Stress | `WSPD`, `UWND`, `VWND`, `TAUX`, `TAUY`, `TAU` | [10.48670/moi-00181](https://doi.org/10.48670/moi-00181) |
| Global Ocean Hourly Reprocessed Sea Surface Wind and Stress | the same, with `frequency = "hourly"` | [10.48670/moi-00185](https://doi.org/10.48670/moi-00185) |

`BOTS` is derived from GLORYS’s salinity field rather than published by
it, so it carries that product’s citation like any other variable taken
from it.

The two wind products are separate records with separate DOIs. A study
using monthly wind cites the first; one using hourly wind, or a daily
field aggregated from it, cites the second.

Analysis-and-forecast products, used with `mode = "forecast"`:

| Product | DOI |
|----|----|
| Global Ocean Physics Analysis and Forecast | [10.48670/moi-00016](https://doi.org/10.48670/moi-00016) |
| Global Ocean Biogeochemistry Analysis and Forecast | [10.48670/moi-00015](https://doi.org/10.48670/moi-00015) |

[`variable_dataset()`](https://chross22.github.io/datamatch/reference/variable_dataset.md)
says which product a variable came from, so only the ones you used need
citing. Downloads go through the [Copernicus Marine
Toolbox](https://toolbox-docs.marine.copernicus.eu/), which publishes no
DOI of its own — cite the products.

### Ocean and wind models

- **FVCOM / NECOFS** — Chen C, Beardsley RC, Cowles G (2006). An
  unstructured grid, finite-volume coastal ocean model (FVCOM) system.
  *Oceanography* **19**(1):78–89.
  <https://doi.org/10.5670/oceanog.2006.92>

- **HYCOM / GOFS 3.1** — Chassignet EP, Hurlburt HE, Smedstad OM,
  Halliwell GR, Hogan PJ, Wallcraft AJ, Baraille R, Bleck R (2007). The
  HYCOM (HYbrid Coordinate Ocean Model) data assimilative system.
  *Journal of Marine Systems* **65**:60–83.
  <https://doi.org/10.1016/j.jmarsys.2005.09.016>

- **CCMP** — Mears C, Lee T, Ricciardulli L, Wang X, Wentz F (2022).
  Improving the Accuracy of the Cross-Calibrated Multi-Platform (CCMP)
  Ocean Vector Winds. *Remote Sensing* **14**(17):4230.
  <https://doi.org/10.3390/rs14174230>

- **MUR** — Chin TM, Vazquez-Cuervo J, Armstrong EM (2017). A
  multi-scale high-resolution analysis of global sea surface
  temperature. *Remote Sensing of Environment* **200**:154–169.
  <https://doi.org/10.1016/j.rse.2017.07.029>

- **VIIRS gap-filled chlorophyll** — Liu X, Wang M (2018). Gap filling
  of missing data for VIIRS global ocean color products using the DINEOF
  method. *IEEE Transactions on Geoscience and Remote Sensing*
  **56**:4464–4476. <https://doi.org/10.1109/TGRS.2018.2820423>

Say which archive as well as which model — a value from the HYCOM
reanalysis and one from an operational experiment are not the same run,
and
[`source_of()`](https://chross22.github.io/datamatch/reference/source_of.md)
records exactly that.

### Seafloor terrain

- NOAA National Centers for Environmental Information (2022). *ETOPO
  2022 15 Arc-Second Global Relief Model*.
  <https://doi.org/10.25921/fd45-gt74>
- Pante E, Simon-Bouhet B, Irisson J (2025). *marmap: Import, Plot and
  Analyze Bathymetric and Topographic Data*.
  <https://doi.org/10.32614/CRAN.package.marmap>

[`fetch_bathymetry()`](https://chross22.github.io/datamatch/reference/fetch_bathymetry.md)
requests the 60 arc-second bedrock grid (`ETOPO_2022_v1_60s_bed`)
through `marmap`.

### Climate indices

Two are the published output of specific work and **should be cited when
used**:

- **`LCR`** — Jutras M, Dufour CO, Mucci A, Talbot LC (2023).
  Large-scale control of the retroflection of the Labrador Current.
  *Nature Communications* **14**:2623.
  <https://doi.org/10.1038/s41467-023-38321-y>

- **`AMOC`** — Moat BI, Smeed DA, Rayner D, Johns WE, Smith R, Volkov D,
  Elipot S, Petit T, Kajtar J, Baringer MO, Collins J (2026). *Atlantic
  meridional overturning circulation observed by the RAPID-MOCHA-WBTS
  array at 26°N from 2004 to 2024 (v2024.1a)*. British Oceanographic
  Data Centre, NERC, UK.
  <https://doi.org/10.5285/48d0bf43-0598-ceb2-e063-7086abc062f1>

  BODC mints a new DOI for each release and retires the old one, so this
  changes when RAPID publishes a new version.
  [`index_dictionary()`](https://chross22.github.io/datamatch/reference/index_dictionary.md)
  carries the current reference.

The other four are operational products with no single paper behind
them. Credit the provider:

- **`NAO`**, **`AO`** — NOAA Climate Prediction Center.
  <https://www.cpc.ncep.noaa.gov/>
- **`AMO`**, **`PDO`** — NOAA Physical Sciences Laboratory.
  <https://psl.noaa.gov/data/climateindices/>

### Software this is built on

- Pebesma E, Bivand R (2023). *Spatial Data Science: With Applications
  in R*. Chapman and Hall/CRC. <https://doi.org/10.1201/9780429459016> —
  the `sf` reference
- Hijmans R, Brown A, Barbosa M (2026). *terra: Spatial Data Analysis*.
  <https://doi.org/10.32614/CRAN.package.terra>
- Pierce D (2025). *ncdf4: Interface to Unidata netCDF Format Data
  Files*. <https://doi.org/10.32614/CRAN.package.ncdf4> — needed for
  `AMOC`

`citation("datamatch")` gives this package’s own entry, and
[`citation()`](https://rdrr.io/r/utils/citation.html) works on any of
the above.

### Keeping these current

Citations go stale without anyone touching them. Data centres reissue a
DOI when a record is superseded and retire the old one, so a reference
that was correct when written stops resolving on its own. The `AMOC`
entry here has already been through that once, when BODC published a
newer RAPID release.

Two scheduled workflows watch for it, and open an issue rather than
editing anything, since choosing a replacement is a judgement about
which version to track:

- **Citation check**, quarterly, resolves every DOI cited in the README,
  the catalogs, and `NEWS.md`.
- **Copernicus catalog check**, monthly, compares the variable catalog
  against the live Copernicus catalogue, since dataset identifiers are
  revised too.

Both run on demand from the Actions tab, and locally:

``` r

# from the package root
system("Rscript inst/scripts/check_citations.R")
system("Rscript inst/scripts/check_catalog.R")
```

## Satellite or model?

Copernicus serves chlorophyll and primary production from two very
different sources, and both are available:

| Name | Source | Resolution | Trade-off |
|----|----|----|----|
| `CHL`, `PP` | Copernicus-GlobColour, satellite | 4 km | Observed, finer — but surface-only and gappy under persistent cloud |
| `CHL_MODEL`, `NPP_MODEL` | Biogeochemistry reanalysis | 0.25° | Gap-free and depth-resolved — but simulated, and coarser |

The plain names default to satellite, since the values are observed
rather than simulated. Switch to the model versions where cloud gaps
would matter more than resolution.

One caution: **satellite `PP` and model `NPP_MODEL` are not the same
quantity.** `PP` is depth-integrated (mg/m2/day), `NPP_MODEL` volumetric
(mg/m3/day). Substituting one for the other is a units error, not a
resolution difference.

Phytoplankton functional types come from the same satellite plankton
dataset as `CHL`, so they can be fetched together:

``` r

env <- accessCopernicus(
  vars = c("CHL", "DIATO", "DINO"),   # one request, one dataset
  years = 2003:2017, months = 1:12,
  bounding_box = list(xmin = -76, xmax = -65, ymin = 35, ymax = 45)
)
```

`DIATO` and `DINO` are diatom and dinophyte chlorophyll — the
spring-bloom species large copepods prefer, and the later
stratified-water group respectively.

## Bottom salinity

`BOTS` pairs with `BOTT`, but it is not fetched the same way, because
**GLORYS12V1 does not publish it.** The reanalysis has temperature at
the sea floor and no salinity counterpart. So it is derived: the full
salinity column is fetched and the deepest wet level in each cell kept.

``` r

bots <- accessCopernicus(vars = "BOTS", years = 2010:2014, months = 1:12,
                     bounding_box = bb)
#> BOTS is not published by this product. Deriving it from the full 'so' column
#> and keeping the deepest wet level in each cell; the depth used comes back as
#> BOTS_depth.
```

The depth each value came from is returned as `BOTS_depth` rather than
left to be assumed. That matters because the deepest wet *model level*
is not the sea floor: level spacing coarsens with depth, so in deep
water the value can sit a long way above the bottom. In shelf water it
is within a few metres.

Two consequences, both deliberate:

- **It must be fetched on its own.** The whole depth column is a
  different request from the single level `SST` wants, so mixing them is
  an error rather than a quiet second download. Call twice and chain
  [`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md).
- **It costs far more.** Roughly fifty levels are downloaded over the
  same box to keep one, so a large box is much slower than the same box
  of `SST`.

In forecast mode none of this applies. The analysis-and-forecast product
publishes sea-floor salinity outright, so `BOTS` is an ordinary variable
there, fetches alongside `BOTT`, and returns no `BOTS_depth`:

``` r

accessCopernicus(vars = c("BOTT", "BOTS"), years = 2026, months = 8,
             bounding_box = bb, mode = "forecast")
```

The two are the same quantity by construction but not the same number —
one is the deepest level of a 50-level grid, the other Copernicus’s own
diagnostic — so a record spanning both modes has a seam in it.

``` r

variable_dictionary("biogeochemical")        # filter by product
variable_dictionary("wind")                  # or just the winds
fvcom_dictionary()                           # the FVCOM catalog, for accessFVCOM()
fvcom_archives()                             # which FVCOM archives are built in
hycom_dictionary()                           # the HYCOM catalog, for accessHYCOM()
hycom_archives()                             # which HYCOM archives can be read
hycom_covering("2019-06-15")                 # which of them span a given date
ccmp_dictionary()                            # the CCMP catalog, for accessCCMP()
ccmp_versions()                              # which CCMP versions can be read
erddap_dictionary()                          # MUR and VIIRS, for accessERDDAP()
erddap_datasets()                            # which ERDDAP datasets ship
variable_dataset(c("SST", "CHL"))            # which dataset each comes from
as.data.frame(variable_dictionary())$description  # full descriptions
```

## Error messages

Most of what this package refuses to do, it refuses deliberately. These
are the messages you are most likely to meet, and what each one means.

**`Could not find the Copernicus Marine client`**

R cannot see `copernicusmarine` on its `PATH`. Common when it lives in a
conda environment that RStudio does not inherit. Point at it directly:

``` r

options(datamatch.copernicusmarine = "~/miniconda3/bin/copernicusmarine")
```

**`These variables come from different Copernicus datasets`**

Expected, not a fault. `SST` is physics and `CHL` is biogeochemistry, on
different grids. Fetch them separately and chain
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md),
as in [Putting several together](#putting-several-together).
[`variable_dataset()`](https://chross22.github.io/datamatch/reference/variable_dataset.md)
shows which dataset each variable comes from.

In forecast mode this happens more often, because the forecast products
split variables across more datasets than the reanalysis does. `SST` and
`UO` share a dataset as reanalysis but not as forecast.

**`Copernicus publishes no daily dataset for: UWND, VWND`**

Expected. This wind is published hourly or monthly and nothing between.
Fetch `frequency = "hourly"` and aggregate with
`upscale_time(to = "day")`. The same message for `PH`, `PP`, `DIATO` or
`DINO` means the opposite — those are monthly composites, so fetch them
monthly.

**`Copernicus publishes no hourly dataset for: WSPD`**

`WSPD` and `TAU` are magnitudes the hourly wind product does not carry.
Fetch `UWND` and `VWND` hourly and compute the magnitude, or take these
monthly.

**`BOTS must be fetched on its own`**

Bottom salinity is derived from the whole depth column, which is a
different request from the single level a surface variable wants. Call
[`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md)
once for `BOTS` and once for the rest, then chain
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md).
See [Bottom salinity](#bottom-salinity).

**`These variables sit on different parts of the FVCOM mesh`**

Scalars sit on mesh nodes and velocities on element centroids, so the
two kinds cannot be read together. Call
[`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md)
once for each and chain
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md).

**`The download did not return: uo, vo`**

Those variables were requested but are not in the returned file. Either
the dataset does not serve them, or they are unavailable at the
requested depth or date. The message lists what did arrive.

**`The depth range returned several model levels`**

`depth` spanned more than one model level, so a variable came back on
several layers and there is no way to know which was wanted. Request a
single level with `depth = c(0, 1)`.

**`Copernicus download failed after 3 attempt(s)`**

The request was retried and kept failing. The message carries the
client’s own output. Rapid repeated downloads can also be rate-limited,
in which case waiting and re-running works.

**`Expected N variable column(s) but the download returned M`**

From a version before the layer-matching fix. Update the package: this
message blamed the depth range for causes it could not distinguish, and
the two real ones now report themselves. See `NEWS.md`.

**Values in the wrong range for their column name**

Salinity around 32 in an `SST` column means you are on a version
predating the layer-ordering fix, where multi-variable downloads could
be mislabelled silently. Update and re-fetch. `NEWS.md` describes what
was affected and how to check.
