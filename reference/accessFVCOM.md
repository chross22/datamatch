# Access FVCOM output from the NECOFS hindcast

Reads an unstructured-mesh FVCOM archive over OPeNDAP and returns it as
an `sf` point object with one row per mesh point and time step — the
same shape
[`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
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

  the months to read, named as dates. Any date selects the month
  containing it, since the archive is monthly.

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
global reanalyses cannot: a box that holds about 2,700 GLORYS cells
holds some 19,000 GOM3 nodes, concentrated where the bathymetry is
complicated.

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
[`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
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

## Only monthly means

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
[`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
for the Copernicus equivalent,
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
for joining either to observations

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
