# Missing-value code declared in a PSL index file

PSL files state their own missing-value code on a line after the data,
rather than using a fixed convention. The code is whatever number stands
alone on the first such line, however small: `amon.us.long.data`
declares `-99.99`, but `pdo.data` declares `-9.90`, which is well inside
the range of real values and so cannot be recognised by its size.

## Usage

``` r
psl_missing_code(lines)
```

## Arguments

- lines:

  the file's lines, trimmed and with blank lines removed

## Value

the code, or `NULL` if not declared
