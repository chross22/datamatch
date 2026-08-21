# A list name for one ensemble member

The hindcast is a single run and carries `NA` where a forecast carries a
member number. `as.character(NA_integer_)` is `NA_character_`, which
cannot name a list element, so the single-run case is named rather than
converted.

## Usage

``` r
member_key(m)
```

## Arguments

- m:

  a member number, or `NA`

## Value

a usable list name
