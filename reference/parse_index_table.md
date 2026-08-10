# Parse a published climate index table

Both supported layouts are a year label followed by twelve monthly
values. They differ in what surrounds that: CPC tables carry a header
row of month names, PSL tables carry a leading year-range line, a
trailing missing-value code, and provenance footer lines.

## Usage

``` r
parse_index_table(lines, format, name)
```

## Arguments

- lines:

  the downloaded file's lines

- format:

  `"cpc_table"` or `"psl_table"`

- name:

  what to call the value column

## Value

a data frame with `YEAR`, `MONTH`, and the named value column
