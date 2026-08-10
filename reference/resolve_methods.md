# Resolve method names to terra's, per variable

Accepts one method for everything or a named vector per variable,
validates it against the direction, and forces non-numeric columns onto
the only methods that mean anything for them.

## Usage

``` r
resolve_methods(method, vars, env_dat, direction)
```

## Arguments

- method:

  the user's `method` argument

- vars:

  the variables being resampled

- env_dat:

  the source object, for column types

- direction:

  `"up"` or `"down"`

## Value

named character vector of terra method names, one per variable
