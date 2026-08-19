# Map covariates on an unstructured mesh, or anywhere else

[`plot_env()`](https://chross22.github.io/datamatch/reference/plot_env.md)
rasterises, which is right for a regular grid and wrong for an FVCOM
mesh: a triangulation has no rows and columns to rasterise onto, so the
result is either blocky or interpolated over cells the model does not
have. This draws the geometry it is given.

## Usage

``` r
plot_mesh(
  x,
  var = NULL,
  values = NULL,
  time = 1,
  palette = "viridis",
  border = NA,
  main = NULL,
  ...
)
```

## Arguments

- x:

  an `sf` object with polygon or point geometry — typically from
  [`fvcom_mesh()`](https://chross22.github.io/datamatch/reference/fvcom_mesh.md),
  but any `sf` object works

- var:

  which column to shade by; `NULL` draws the bare geometry

- values:

  optional `sf` object holding the values, from
  [`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md)
  or any access function. Joined to `x` spatially.

- time:

  which time step of `values` to use, as an index or a named vector of
  `YEAR`/`MONTH`/`DAY`. Only needed when `values` carries more than one.

- palette:

  a
  [`grDevices::hcl.colors()`](https://rdrr.io/r/grDevices/palettes.html)
  palette name

- border:

  colour for cell edges. `NA` hides them, which is what you want on a
  fine mesh where the edges would otherwise be all you see.

- main:

  plot title

- ...:

  passed to [`plot()`](https://rdrr.io/r/graphics/plot.default.html)

## Value

the `sf` object that was drawn, invisibly, with the joined column if
`values` was given

## What it is for

Two jobs. With a mesh from
[`fvcom_mesh()`](https://chross22.github.io/datamatch/reference/fvcom_mesh.md)
and nothing else, it draws the grid itself — which is how you see where
a model resolves a shelf finely and where it does not. With `var` naming
a column, it shades each cell by that value.

## Shading a mesh with fetched values

[`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md)
returns points and
[`fvcom_mesh()`](https://chross22.github.io/datamatch/reference/fvcom_mesh.md)
returns triangles, so the two are joined spatially rather than by
position — a fetch is subset to the bounding box, so its row order says
nothing about the mesh's own numbering. Pass `values` and that join is
done for you:

    mesh <- fvcom_mesh(bounding_box = bb)
    sst  <- accessFVCOM(vars = "SST", years = 2010, months = 6, bounding_box = bb)
    plot_mesh(mesh, "SST", values = sst)

Element-centred values (`UO`, `UBAR`, `TAUX`) sit at the centroid, one
per triangle. Node-centred ones (`SST`, `BOTS`) sit at the *corners*,
shared between the triangles meeting there, so each triangle takes the
mean of its three — which is why the join tests intersection rather than
containment: a corner is on the boundary, and nothing contains it.

## See also

[`fvcom_mesh()`](https://chross22.github.io/datamatch/reference/fvcom_mesh.md)
for the grid,
[`plot_env()`](https://chross22.github.io/datamatch/reference/plot_env.md)
for regular grids

## Examples

``` r
if (FALSE) { # \dontrun{
bb <- list(xmin = -70, xmax = -66, ymin = 41, ymax = 44)
mesh <- fvcom_mesh(bounding_box = bb)

plot_mesh(mesh)                      # the grid itself
plot_mesh(mesh, "DEPTH")             # shaded by bathymetry

sst <- accessFVCOM(vars = "SST", years = 2010, months = 6, bounding_box = bb)
plot_mesh(mesh, "SST", values = sst)
} # }
```
