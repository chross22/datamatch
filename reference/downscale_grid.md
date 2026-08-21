# Interpolate environmental data onto a finer grid

Puts a coarse field onto a finer grid, so a 0.25 degree model variable
can join 4 km satellite data without the satellite being coarsened to
meet it.

## Usage

``` r
downscale_grid(
  env_dat,
  to,
  vars = NULL,
  method = "nearest",
  idw_radius = NULL,
  idw_power = 2
)
```

## Arguments

- env_dat:

  an `sf` POINT object on a regular grid, from
  [`accessCopernicus()`](https://camilleross.org/datamatch/reference/accessCopernicus.md),
  [`accessHYCOM()`](https://camilleross.org/datamatch/reference/accessHYCOM.md),
  [`accessCCMP()`](https://camilleross.org/datamatch/reference/accessCCMP.md)
  or
  [`accessERDDAP()`](https://camilleross.org/datamatch/reference/accessERDDAP.md).
  Not
  [`accessFVCOM()`](https://camilleross.org/datamatch/reference/accessFVCOM.md):
  its mesh is unstructured, so there are no rows and columns to
  aggregate over - match it to points, or regrid a regular product onto
  it.

- to:

  the target grid: either a resolution in the CRS's units (one number
  for square cells, or `c(x, y)`), or another `sf` object whose grid to
  adopt — which is the form that puts two products onto one grid.

- vars:

  columns to resample; `NULL` uses all covariate columns, as
  [`covariate_columns()`](https://camilleross.org/datamatch/reference/covariate_columns.md)
  reports them

- method:

  one of `"nearest"`, `"bilinear"`, `"cubic"`, `"idw"`; length one for
  all variables, or a named vector per variable

- idw_radius:

  search radius for `method = "idw"`, in the CRS's units. Defaults to
  twice the source cell size, which reaches the immediate neighbours;
  larger draws from further away and smooths more.

- idw_power:

  distance exponent for `method = "idw"`. Higher concentrates weight on
  the nearest points, approaching `nearest` in the limit.

## Value

an `sf` POINT object on the target grid, with the same
`YEAR`/`MONTH`/`DAY` columns as the input

## What this does and does not do

Downscaling adds cells, not information. A 0.25 degree field rendered at
4 km has 4 km *cells*, but it still resolves nothing below 0.25 degrees,
and no method here changes that — none of them consult any other data
source, so there is nowhere for real fine-scale structure to come from.

That distinction is easy to lose downstream, which is why `nearest` is
the default. It replicates each coarse value across the fine cells
inside it, so the result is visibly blocky at the source resolution: the
output looks like what it is. `bilinear` and `cubic` return a smooth
field that looks like a finely-resolved measurement and is not one. They
are the better choice when the field really is smooth at the source
scale and blockiness would be an artefact — sea surface height, say —
and the worse choice when someone later computes a gradient from the
result, because that gradient is then a property of the interpolator.

- `nearest` — the value of the containing coarse cell. Invents nothing;
  blocky. Required for categorical fields, and applied to them
  automatically.

- `bilinear` — weighted by the four surrounding cell centres. Smooth,
  and `NA` anywhere a contributing neighbour is `NA`, so gaps grow by a
  cell.

- `cubic` — smoother again, over sixteen cells. Can overshoot past the
  source range near sharp edges, which for a bounded quantity like
  chlorophyll can produce negatives.

- `idw` — inverse distance weighting over the source points within
  `idw_radius`. Unlike the others it fills across holes rather than
  propagating them, which makes it the one to use on gappy satellite
  data where
  [`fill_satellite_gaps()`](https://camilleross.org/datamatch/reference/fill_satellite_gaps.md)
  is not an option.

## See also

[`upscale_grid()`](https://camilleross.org/datamatch/reference/upscale_grid.md)
for the other direction,
[`fill_satellite_gaps()`](https://camilleross.org/datamatch/reference/fill_satellite_gaps.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Model chlorophyll (0.25 deg) onto the satellite grid, blockiness intact
fine <- downscale_grid(chl_model, to = chl_satellite)

# Smooth, for a field that really is smooth at the source scale
ssh <- downscale_grid(ssh_model, to = 0.04, method = "bilinear")
} # }
```
