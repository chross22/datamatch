# Missing-value code declared in a PSL index file

PSL files state their own missing-value code on a line after the data,
rather than using a fixed convention.

## Usage

``` r
psl_missing_code(lines)
```

## Arguments

- lines:

  the file's lines

## Value

the code, or `NULL` if not declared
