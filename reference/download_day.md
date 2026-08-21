# Download one day's subset, returning any failure rather than raising it

Defined at the top level rather than as a closure inside
[`accessCopernicus()`](https://camilleross.org/datamatch/reference/accessCopernicus.md)
so that its enclosing environment is this package's namespace. A closure
would carry
[`accessCopernicus()`](https://camilleross.org/datamatch/reference/accessCopernicus.md)'s
whole evaluation frame — including the cluster object itself — to every
worker when it is serialised.

## Usage

``` r
download_day(item, dataset_id, vars, bounding_box, depth, hourly = FALSE)
```

## Arguments

- item:

  one work item: `ofile`, `time`, and the calendar fields

- dataset_id:

  Copernicus dataset identifier

- vars:

  variable codes to request

- bounding_box:

  passed to `bb`

- depth:

  length-2 depth range in metres

- hourly:

  whether the dataset is hourly, in which case the request covers the
  whole day rather than one instant. A bare date means midnight to
  midnight, which on an hourly dataset selects the first hour and
  silently discards the other 23.

## Value

`NULL` on success, or a one-line description of the failure

## Details

Errors are caught and returned as text. Under
[`parallel::parLapplyLB()`](https://rdrr.io/r/parallel/clusterApply.html)
an error thrown in a worker aborts the entire batch, so a single bad day
would discard the days still in flight. Collecting failures instead lets
every day be attempted, and lets the caller be told about all of them at
once rather than about whichever one happened to fail first.
