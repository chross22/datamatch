# Read an FVCOM mesh on its own, with no data on it

[`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md)
returns values at points — nodes for scalars, element centroids for
velocities. That is what
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
needs, but it is not the mesh: it is a scatter of the mesh's points, and
drawing it shows dots where the grid is triangles. This returns the
triangles themselves, so the grid can actually be plotted.

## Usage

``` r
fvcom_mesh(
  archive = "GOM3",
  bounding_box = NULL,
  what = c("polygons", "nodes", "elements"),
  date = NULL
)
```

## Arguments

- archive:

  which archive's mesh: a name from
  [`fvcom_archives()`](https://chross22.github.io/datamatch/reference/fvcom_archives.md),
  or a spec from
  [`fvcom_archive()`](https://chross22.github.io/datamatch/reference/fvcom_archive.md)

- bounding_box:

  optional named list with `xmin`, `xmax`, `ymin`, `ymax`, or an
  `sf`/`sfc` object. `NULL` returns the whole mesh, which for GOM3 is
  90,415 triangles.

- what:

  `"polygons"`, `"nodes"`, or `"elements"`

- date:

  the month whose mesh to read, for an archive that remeshes. Ignored
  for a single-mesh archive.

## Value

an `sf` object: `POLYGON` for `"polygons"`, `POINT` otherwise, in
EPSG:4326

## Why the points are not enough

An FVCOM mesh is a triangulation, and which nodes form each triangle
lives in a connectivity array (`nv`) that a point fetch never reads.
Without it there is no way to draw a cell boundary, shade a cell by its
value, or show how the resolution changes across a shelf — all of which
are the usual reasons for looking at an unstructured model in the first
place.

The result carries no time dimension and no covariates. It is the grid.

## What comes back

- `"polygons"` (the default) — one `POLYGON` per element, with the
  element index and `DEPTH`, the mean of its three nodes' bathymetry.
  This is what to plot.

- `"nodes"` — the mesh nodes as `POINT`s, with `DEPTH`. Scalars such as
  `SST` and `BOTS` live here.

- `"elements"` — the element centroids as `POINT`s. Velocities and
  stresses live here.

## Bounding box

A triangle is kept when **any** of its three vertices falls inside the
box, so the returned mesh covers the box rather than stopping short of
it. The edge is therefore ragged, and a triangle may extend a little
beyond what was asked for. Clipping to the box exactly would cut
triangles into shapes the model does not have.

## Meshes that move

`GOM3` has one mesh for its whole record. `GOM7` does not — it is
operational output and remeshes between files, carrying 198,594 nodes in
January 2025 and 207,081 from March. For an archive like that the mesh
belongs to a particular month, so `date` says which; it defaults to the
start of the record.

## See also

[`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md)
for values on the mesh,
[`fvcom_archives()`](https://chross22.github.io/datamatch/reference/fvcom_archives.md)

## Examples

``` r
if (FALSE) { # \dontrun{
bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)

mesh <- fvcom_mesh(bounding_box = bb)
plot(sf::st_geometry(mesh))                 # the grid itself
plot(mesh["DEPTH"], border = NA)            # shaded by bathymetry

# Shade the triangles by a fetched value. Join spatially rather than by
# position: accessFVCOM() returns only the points inside the box, so its row
# order does not correspond to the mesh's element numbering.
currents <- accessFVCOM(vars = "UBAR", years = 2010, months = 6,
                        bounding_box = bb)
shaded <- sf::st_join(mesh, currents["UBAR"], join = sf::st_contains)
plot(shaded["UBAR"], border = NA)
} # }
```
