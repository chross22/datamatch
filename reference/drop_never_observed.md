# Drop the grid cells that hold no value at any time step

The readers keep cells that are empty at a time step, so that a cloud
gap arrives as an `NA` that
[`fill_satellite_gaps()`](https://camilleross.org/datamatch/reference/fill_satellite_gaps.md)
can fill. A cell that is empty at every time step of the request is a
different case: land, or outside the product's domain. Those are
dropped, as they always were, because
[`matchData()`](https://camilleross.org/datamatch/reference/matchData.md)
joins each observation to the nearest cell. Kept, an observation on the
coast would join to the land cell beside it and take its `NA` instead of
the nearest value at sea.

## Usage

``` r
drop_never_observed(covars, value_columns)
```

## Arguments

- covars:

  a data frame of `x`, `y`, value columns and time columns

- value_columns:

  the value columns

## Value

`covars` without the cells that never hold a value

## Details

The two cannot be told apart from the data alone when a cell is clouded
at every requested time step, as it may be on a one-date request. Such a
cell is dropped like land, which is how every cloud gap was treated
before.
