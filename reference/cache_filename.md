# The cache filename for one day's download

A cached file is only reusable by a request that would have produced the
same file, so everything that changes the file has to be in its name:
the variables, the bounding box and the depth as well as the product,
dataset and date.

## Usage

``` r
cache_filename(product_id, dataset_id, time, vars, bb, depth)
```

## Arguments

- product_id, dataset_id:

  the Copernicus product and dataset

- time:

  the day, as a `Date`

- vars:

  variable codes requested

- bb:

  the bounding box

- depth:

  the depth range

## Value

a filename

## Details

Leaving them out was a real bug rather than a theoretical one. A request
for `thetao` over a small box wrote a file that a later request for
`thetao, so` over a large one then reused - and the second request
either failed for the missing variable, which is the lucky case, or
silently returned a grid covering the wrong area, which is not. Two
people sharing a cache, or one person narrowing a study area between
runs, hit this without doing anything unusual.

The identifying part is a short hash rather than the values spelled out.
A dozen variables and four coordinates make a filename longer than some
file systems accept, and the date and dataset stay readable at the front
so the cache can still be browsed.
