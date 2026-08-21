# Which HYCOM archives cover a given date

The archives overlap, so a date can fall in more than one, and after
2015 the choice between them is a judgement rather than a lookup — the
reanalysis is the more internally consistent, the operational run the
more recent. This reports the candidates instead of picking one.

## Usage

``` r
hycom_covering(dates)
```

## Arguments

- dates:

  one or more `Date` values, or anything
  [`parse_dates()`](https://camilleross.org/datamatch/reference/parse_dates.md)
  accepts

## Value

the names of the archives spanning every date given, in catalog order;
empty if none does

## See also

[`hycom_archives()`](https://camilleross.org/datamatch/reference/hycom_archives.md),
[`accessHYCOM()`](https://camilleross.org/datamatch/reference/accessHYCOM.md)

## Examples

``` r
hycom_covering("2010-06-15")     # the reanalysis alone
#> [1] "GLBv53X"
hycom_covering("2015-06-15")     # reanalysis and an operational run
#> [1] "GLBv53X" "GLBv563"
hycom_covering("2025-06-15")     # none: past the end of the record
#> character(0)
```
