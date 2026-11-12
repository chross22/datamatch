# A uniquely named working file beside a cache file

The name carries the process id and a random suffix so that two
processes writing the same cache entry do not write into each other's
working file. It sits in the same directory as `path` so that the final
rename stays on one filesystem.

## Usage

``` r
partial_path(path)
```

## Arguments

- path:

  the cache file the working file will become

## Value

a path
