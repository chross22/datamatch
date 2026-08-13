# Parse the text of an ERDDAP `.das` document

Kept separate from fetching it so the parsing can be tested without a
server, which is the half that breaks silently: a format change here
would produce an empty catalog rather than an error.

## Usage

``` r
erddap_parse_das(text)
```

## Arguments

- text:

  the lines of a `.das` document

## Value

a named list, one entry per variable, each with `units` and
`actual_range` where present
