# Aggregate environmental data onto a coarser grid

Combines the source cells falling inside each target cell into one
value, so a 4 km satellite field can be brought onto a 0.25 degree model
grid. This is the direction that discards detail, which is the safe
direction: every value in the result is a summary of values that were
really measured.

## Usage

``` r
upscale_grid(
  env_dat,
  to,
  vars = NULL,
  method = "mean",
  min_coverage = 0.5,
  keep_counts = FALSE
)
```

## Arguments

- env_dat:

  an `sf` POINT object on a regular grid, from
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md),
  [`accessHYCOM()`](https://chross22.github.io/datamatch/reference/accessHYCOM.md),
  [`accessCCMP()`](https://chross22.github.io/datamatch/reference/accessCCMP.md)
  or
  [`accessERDDAP()`](https://chross22.github.io/datamatch/reference/accessERDDAP.md).
  Not
  [`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md):
  its mesh is unstructured, so there are no rows and columns to
  aggregate over - match it to points, or regrid a regular product onto
  it.

- to:

  the target grid: either a resolution in the CRS's units (one number
  for square cells, or `c(x, y)`), or another `sf` object whose grid to
  adopt — which is the form that puts two products onto one grid.

- vars:

  columns to resample; `NULL` uses all covariate columns, as
  [`covariate_columns()`](https://chross22.github.io/datamatch/reference/covariate_columns.md)
  reports them

- method:

  one of `"mean"`, `"median"`, `"min"`, `"max"`, `"sum"`, `"mode"`;
  length one for all variables, or a named vector per variable

- min_coverage:

  fraction of contributing source cells that must be non-missing, from 0
  to 1

- keep_counts:

  add a `<var>_coverage` column per variable, giving the fraction of
  source cells that carried a value

## Value

an `sf` POINT object on the target grid, with the same
`YEAR`/`MONTH`/`DAY` columns as the input

## Choosing a method

`mean` is the default and is right for most continuous fields. The
others exist because "the value of this coarse cell" is not one
question:

- `mean`, `median` — central tendency. `median` resists a single extreme
  cell, which matters for satellite chlorophyll, where retrieval
  artefacts at cloud edges are high outliers rather than symmetric
  noise.

- `min`, `max` — the extreme within the cell. `min` of depth is the
  shallowest point a coarse cell contains, which is the relevant number
  for whether something can sit on the bottom there; the mean depth of
  the same cell is not.

- `sum` — only for quantities that are per-cell totals rather than
  densities. Summing a concentration produces a number with no meaning.

- `mode` — the commonest value. For categorical fields; applied
  automatically to non-numeric columns.

Pass one method for everything, or a named vector to vary it by
variable: `method = c(CHL = "median", DEPTH = "min")`, in the style
[`fill_satellite_gaps()`](https://chross22.github.io/datamatch/reference/fill_satellite_gaps.md)
takes its `vars`.

## Partial cells

Satellite data has holes, and a coarse cell overlapping one is averaged
from whatever survived. That average is not wrong so much as differently
derived from its neighbours — a cell built from three of sixteen source
values is a much noisier estimate, and nothing in the returned number
says so.

`min_coverage` is the fraction of a target cell's source cells that must
carry a value for the result to be reported at all; below it, the cell
is `NA`. The default of 0.5 is deliberately visible rather than
permissive. Set it to 0 to aggregate whatever is present, and
`keep_counts = TRUE` to get the coverage fraction alongside each
variable and judge for yourself.

## See also

[`downscale_grid()`](https://chross22.github.io/datamatch/reference/downscale_grid.md)
for the other direction,
[`grid_resolution()`](https://chross22.github.io/datamatch/reference/grid_resolution.md)

## Examples

``` r
if (FALSE) { # \dontrun{
chl <- accessEnvDat(vars = "CHL", years = 2010, months = 1:12, bounding_box = bb)
sst <- accessEnvDat(vars = "SST", years = 2010, months = 1:12, bounding_box = bb)

# Satellite CHL (4 km) onto the physics grid (0.083 degrees)
chl_coarse <- upscale_grid(chl, to = sst)

# Or onto a stated resolution, with the median to resist retrieval outliers
chl_quarter <- upscale_grid(chl, to = 0.25, method = "median")
} # }
```
