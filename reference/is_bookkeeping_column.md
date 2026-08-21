# Columns that are bookkeeping rather than data

`<var>_depth` records which model level a derived bottom value was taken
from, and `.datamatch_source` is the per-row source tag a fetch spanning
several archives carries. Neither measures anything: the mean of two
depths is not the depth any value came from, and the internal tag is
consumed by
[`matchData()`](https://camilleross.org/datamatch/reference/matchData.md)
rather than kept. So
[`covariate_columns()`](https://camilleross.org/datamatch/reference/covariate_columns.md)
leaves both out, and nothing resamples or plots them as though they were
covariates.

## Usage

``` r
is_bookkeeping_column(names)
```

## Arguments

- names:

  column names to inspect

## Value

one per name

## Why `<var>_source` is not here

It is provenance too, but it travels with the variable it describes
rather than being left behind by it.
[`upscale_grid()`](https://camilleross.org/datamatch/reference/upscale_grid.md)
and
[`upscale_time()`](https://camilleross.org/datamatch/reference/upscale_time.md)
carry a non-numeric column as a categorical - the commonest value when
aggregating, the nearest when interpolating - which is exactly what a
source tag needs, and both were written expecting one to ride along.
Excluding it here meant it never did, so the record of which source a
value came from was lost at the first resample, which is the point at
which it matters most.
