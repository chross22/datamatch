# A short, stable hash of a string

Base R has no string hash, and this needs no cryptographic strength: it
distinguishes cache keys, and a collision would have to occur between
two requests for the same dataset on the same day. Written out rather
than taken from a package so that the cache does not gain a dependency.

## Usage

``` r
short_hash(x)
```

## Arguments

- x:

  a string

## Value

eight hexadecimal characters
