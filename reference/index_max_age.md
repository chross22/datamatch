# How long a cached index may be reused, in days

Matched to how often the provider publishes. Re-downloading a monthly
index every day is pointless traffic, and re-downloading a finished one
is pointless full stop.

## Usage

``` r
index_max_age(updates)
```

## Arguments

- updates:

  `"monthly"`, `"annual"`, or `"none"`

## Value

a number of days, possibly `Inf`
