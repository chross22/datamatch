# Write an object to the cache so that a reader never sees half a file

[`saveRDS()`](https://rdrr.io/r/base/readRDS.html) writes straight to
its destination, so an interrupted run (a killed worker, Ctrl-C) or two
sessions fetching the same day at once can leave a truncated file that
every later run trusts. The object is written to a uniquely named file
in the same directory and renamed into place, which is atomic on one
filesystem: a reader sees either no file or the whole of one.

## Usage

``` r
save_rds_atomic(object, path)
```

## Arguments

- object:

  the object to save

- path:

  the cache file to write

## Value

`path`, invisibly
