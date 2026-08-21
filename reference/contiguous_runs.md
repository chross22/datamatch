# Group indices into contiguous runs

A fetch usually wants a scattered handful of time steps — survey dates,
or a month from each of ten years. Reading each with its own DAP request
is one round trip per step; reading the whole span between the first and
the last transfers everything in between. Runs are the middle:
contiguous stretches become one request each, and a gap ends a run
rather than being read across.

## Usage

``` r
contiguous_runs(i)
```

## Arguments

- i:

  indices, in any order

## Value

a list of integer vectors, each contiguous and increasing
