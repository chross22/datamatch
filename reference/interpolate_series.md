# Interpolate one cell's series onto the target time steps

Interpolate one cell's series onto the target time steps

## Usage

``` r
interpolate_series(x, y, xout, method, extrapolate, lower = NULL, upper = NULL)
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

- lower, upper:

  the start and (exclusive) end of each source period, as numeric days.
  Used only when a single value is present, to tell which targets lie
  inside its period; `NULL` keeps only an exact time match.

## Value

numeric vector of length `length(xout)`
