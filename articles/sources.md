# Choosing a data source

datamatch fetches from four sources and joins any of them to your
observations the same way. This is about which one to reach for, and
what changes when you do.

Nothing here is downloaded when the vignette is built — the fetches are
shown but not run, because each needs a network and some need several
gigabytes.

## The four, side by side

|  | [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md) | [`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md) | [`accessHYCOM()`](https://chross22.github.io/datamatch/reference/accessHYCOM.md) | [`accessCCMP()`](https://chross22.github.io/datamatch/reference/accessCCMP.md) |
|----|----|----|----|----|
| Source | Copernicus Marine | NECOFS / any FVCOM | HYCOM GOFS 3.1 | RSS CCMP v3.1 |
| Kind | global reanalysis, forecast, satellite | regional coastal model | global model | wind analysis |
| Grid | 0.083°–4 km, regular | unstructured mesh | 0.08° regular | 0.25° regular |
| Steps | monthly, daily, hourly | monthly | 3-hourly | 6-hourly |
| Record | 1993– | 1978–2013 | 1994–2015 | 1993–present |
| Bottom salinity | derived | free | free | — |
| Wind stress | yes | yes (model forcing) | — | — |
| Subsetting | server-side | client-side | server-side | **whole globe** |

``` r

variable_dictionary()   # Copernicus
fvcom_dictionary()      # FVCOM
hycom_dictionary()      # HYCOM
ccmp_dictionary()       # CCMP
```

## They share variable names on purpose

A covariate arrives in a column of the same name whichever source
supplied it, so everything downstream —
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md),
resampling, plotting, and whatever model you fit — works unchanged:

``` r

bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

copernicus <- accessEnvDat(vars = "SST", years = 2010, months = 1:12, bounding_box = bb)
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
holding about 2,700 GLORYS cells holds some 19,000 GOM3 nodes,
concentrated where the bathymetry is complicated. If your question is
about a shelf, a bank, or a channel rather than a basin, that resolution
is the reason. It ends in 2013.

**Reach for HYCOM for bottom fields, or for a second opinion.** It
publishes `salinity_bottom` and `water_temp_bottom` as real fields where
Copernicus has no bottom salinity at all, and being an independent model
it makes agreement meaningful.

**Reach for CCMP for winds over a long record.** Six-hourly from 1993 to
within days of the present, where the Copernicus wind is monthly from
mid-1994 or hourly only from 2007. But it carries no stress.

## Bottom salinity, four ways

`BOTS` is the clearest case of the same name costing different amounts:

``` r

# Copernicus reanalysis: derived. Fetches ~50 depth levels to keep the deepest
# wet one, so it must be fetched alone, and reports the depth it used.
bots <- accessEnvDat(vars = "BOTS", years = 2010, months = 1:12, bounding_box = bb)
bots$BOTS_depth

# Copernicus forecast: published outright as `sob`, no derivation.
accessEnvDat(vars = c("BOTT", "BOTS"), years = 2026, months = 7,
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

Three of the four publish below daily, and none of them publishes a
daily mean:

| Source          | Native step | `frequency`                              |
|-----------------|-------------|------------------------------------------|
| Copernicus wind | hourly      | `"hourly"`                               |
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

matched <- matchData(observations, accessEnvDat(vars = c("SST", "MLD"),
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

## Citing what you used

Every source here is somebody else’s work, and the obligation travels
with the data rather than with this package:

``` r

fvcom_archives()$GOM3$reference
hycom_archives()$GLBv53X$reference
ccmp_versions()$`v03.1`$reference
index_dictionary()          # carries the climate index references
```

The README’s References section lists the Copernicus product DOIs. Cite
whichever you actually fetched from.
