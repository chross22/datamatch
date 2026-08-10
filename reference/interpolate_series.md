# Interpolate one cell's series onto the target time steps

Interpolate one cell's series onto the target time steps

## Usage

``` r
interpolate_series(x, y, xout, method, extrapolate)
```

## Arguments

- x:

  source times, as numeric days

- y:

  source values

- xout:

  target times, as numeric days

- method:

  `"step"`, `"linear"`, or `"spline"`

- extrapolate:

  hold end values constant beyond the source range

## Value

numeric vector of length `length(xout)`
