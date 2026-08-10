# Resolve variable names to Copernicus codes

Accepts either a catalog name (`"SST"`) or a raw Copernicus code
(`"thetao"`), so existing calls that pass codes keep working unchanged.

## Usage

``` r
resolve_variables(vars, mode = c("reanalysis", "forecast"))
```

## Arguments

- vars:

  variable names or codes

- mode:

  `"reanalysis"` or `"forecast"`

## Value

a list with `codes` (Copernicus codes, in the given order) and `names`
(what each should be called in the result)
