# Access FVCOM output from the NECOFS hindcast

Reads an unstructured-mesh FVCOM archive over OPeNDAP and returns it as
an `sf` point object with one row per mesh point and time step — the
same shape
[`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md)
returns, so
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
joins it unchanged.

## Usage

``` r
accessFVCOM(
  vars,
  years = NULL,
  months = NULL,
  bounding_box,
  dates = NULL,
  frequency = c("daily", "hourly"),
  hour = 12L,
  archive = "GOM3",
  overwrite = FALSE
)
```

## Arguments

- vars:

  variables to read, from
  [`fvcom_variables()`](https://chross22.github.io/datamatch/reference/fvcom_variables.md)

- years:

  years to read. Required unless `dates` is given.

- months:

  months to read. Required unless `dates` is given.

- bounding_box:

  named list with `xmin`, `xmax`, `ymin`, `ymax`, or an `sf`/`sfc`
  object to take the bounding box of

- dates:

  the months to read, named as dates. On a monthly archive any date
  selects the month containing it.

- frequency:

  for a sub-daily archive such as `GOM7`, `"daily"` (the default) for
  one snapshot per day or `"hourly"` for every hour. Ignored, with a
  warning, on a monthly archive.

- hour:

  which UTC hour the daily snapshot takes, 0 to 23.

- archive:

  which archive to read: the name of one from
  [`fvcom_archives()`](https://chross22.github.io/datamatch/reference/fvcom_archives.md),
  or a spec from
  [`fvcom_archive()`](https://chross22.github.io/datamatch/reference/fvcom_archive.md)
  describing any other FVCOM endpoint. The built-in list covers the
  Northeast US shelf only, because that is what one server publishes;
  [`fvcom_archive()`](https://chross22.github.io/datamatch/reference/fvcom_archive.md)
  is how every other region is reached.

- overwrite:

  re-read time steps already cached

## Value

one row per mesh point per time step, with `YEAR`, `MONTH` and `DAY`,
and a column per requested variable

## What this is, and when to prefer it

NECOFS is a regional coastal model on a triangular mesh that refines
toward the coast. Over the Gulf of Maine it resolves structure the
global reanalyses cannot: over -70 to -66 E and 41 to 44 N, GLORYS
resolves 1,742 cells where GOM3 carries 6,579 nodes, concentrated where
the bathymetry is complicated.

That resolution is the reason to use it, and its limits are the reason
not to. It is one regional model rather than a reanalysis assimilating
observations basin-wide, it stops at the mesh boundary, and it ends in
2013. A covariate taken from FVCOM is **not interchangeable** with the
same-named covariate from Copernicus, even though this returns it in a
column of the same name — they are different models on different meshes.
Say which you used.

## Nodes and elements

Scalars (`SST`, `SSS`, `BOTT`, `BOTS`, `SSH`) sit on mesh nodes;
velocities and stresses (`UO`, `VO`, `UBAR`, `VBAR`, `TAUX`, `TAUY`) sit
on element centroids. Those are two different sets of points, so the two
kinds cannot be fetched together — mixing them is an error rather than a
silent interpolation of one onto the other. Fetch each and chain
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md).

## Bottom salinity

`BOTS` costs nothing here. FVCOM's sigma coordinate makes the deepest
layer the sea floor at every node, so bottom salinity is a layer index
rather than the derivation
[`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md)
needs against GLORYS. If bottom properties are the point of the
analysis, this is the cheaper source for them.

## Reading other regions

FVCOM is a model, not a data product, so there is no global archive of
it. Groups run it for their own coastlines and publish on their own
servers, and the archives built in here are only what one server
publishes for the Northeast US. Anything else is reached by describing
it once:

    elsewhere <- fvcom_archive("http://example.org/thredds/dodsC/some_fvcom_run")
    env <- accessFVCOM(vars = "SST", years = 2010, months = 1:12,
                       bounding_box = bb, archive = elsewhere)

Everything this function does depends on FVCOM's structure rather than
on the region, so any FVCOM output should read. What differs between
deployments — the mesh, the period, which fields were saved — is read
from the file, and
[`fvcom_archive()`](https://chross22.github.io/datamatch/reference/fvcom_archive.md)
reports it.

## Hindcast and forecast archive are different products

Two NECOFS archives ship, and the second is not a continuation of the
first:

- **`GOM3`** (the default) is the 30-year **hindcast**, monthly means on
  the 48,451-node GOM3 mesh, 1978–2013. One consistent retrospective
  run.

- **`GOM7`** is the archived **operational forecast**, hourly on the
  207,081-node GOM7 mesh, 2025 onward. It is the model as it was running
  at the time, stitched across whatever versions were current.

Three things change at once between them — the mesh, the time step, and
whether the output is retrospective — so they are offered as separate
archives rather than joined into one series. `GOM7` also saves fewer
fields: it carries no wind stress, so `TAUX` and `TAUY` are unavailable
there.

Between 2014 and 2024 this server publishes neither, which is a gap in
NECOFS rather than in this package.

## Sub-daily archives

`GOM7` is hourly, so `frequency` chooses what to take from it:

- `"daily"` (the default) reads **one snapshot per day**, at `hour`.

- `"hourly"` reads every hour.

The default is the snapshot deliberately. A month of hourly GOM7 is 720
reads of a 207,081-node field, which is a long transfer to keep a
shelf-sized corner of it, and a snapshot is usually what a daily
covariate wants. A snapshot is an instant rather than a daily mean;
[`upscale_time()`](https://chross22.github.io/datamatch/reference/upscale_time.md)
makes a real mean from `frequency = "hourly"` if that is what is needed.

`frequency` does nothing on a monthly archive such as `GOM3`, and saying
so beats silently ignoring it.

## Only monthly means, on the hindcast

The hindcast is published hourly and as monthly means of those hours.
Only the monthly aggregation is offered, because the hourly one cannot
be opened: it carries 342,348 time steps, and reading the time
coordinate — which `nc_open()` does before returning anything — exceeds
the server's DAP timeout. The failure takes over ten minutes to arrive
and says only `NetCDF: DAP failure`.

Sub-monthly FVCOM is therefore not a matter of passing a different
argument here. It would need the per-file datasets behind the
aggregation, read one month at a time.

## See also

[`fvcom_variables()`](https://chross22.github.io/datamatch/reference/fvcom_variables.md)
for what can be read,
[`accessCopernicus()`](https://chross22.github.io/datamatch/reference/accessCopernicus.md),
[`accessHYCOM()`](https://chross22.github.io/datamatch/reference/accessHYCOM.md),
[`accessCCMP()`](https://chross22.github.io/datamatch/reference/accessCCMP.md)
and
[`accessERDDAP()`](https://chross22.github.io/datamatch/reference/accessERDDAP.md)
for the other sources,
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
for joining any of them to observations

## Examples

``` r
if (FALSE) { # \dontrun{
bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

# Scalars live on nodes
fv <- accessFVCOM(vars = c("SST", "BOTT", "BOTS"), years = 2010:2013,
                  months = 1:12, bounding_box = bb)

matched <- matchData(observations, fv)

# Velocities live on elements, so they are a second call
currents <- accessFVCOM(vars = c("UBAR", "VBAR"), years = 2010:2013,
                        months = 1:12, bounding_box = bb)
matched <- matchData(matched, currents)
} # }
```
