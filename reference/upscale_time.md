# Aggregate environmental data onto a coarser time step

Combines the time steps falling inside each target period into one
value, so a daily product becomes monthly means, or a monthly one
becomes annual. The grid is untouched — every cell keeps its own series,
aggregated in place.

## Usage

``` r
upscale_time(
  env_dat,
  to = c("month", "year"),
  vars = NULL,
  method = "mean",
  min_coverage = 0.5,
  keep_counts = FALSE
)
```

## Arguments

- env_dat:

  an `sf` POINT object from
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)

- to:

  the target period: `"month"` or `"year"`

- vars:

  columns to aggregate; `NULL` uses all covariate columns

- method:

  one of `"mean"`, `"median"`, `"min"`, `"max"`, `"sum"`, `"sd"`,
  `"mode"`; length one for all variables, or a named vector per variable

- min_coverage:

  fraction of the period's expected steps that must carry a value, from
  0 to 1

- keep_counts:

  add a `<var>_n` column per variable, giving the number of steps behind
  each value

## Value

an `sf` POINT object with one row per cell per target period. Monthly
output is stamped `DAY = 1`; annual output `MONTH = 1, DAY = 1`,
matching what
[`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
returns for non-daily products so that
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
reads the resolution back correctly.

## Choosing a method

As with
[`upscale_grid()`](https://chross22.github.io/datamatch/reference/upscale_grid.md),
the summary that belongs in a period depends on the question:

- `mean`, `median` — the typical condition over the period.

- `min`, `max` — the extreme reached within it. The coldest month of a
  year is often what determines whether something overwinters somewhere;
  the annual mean at the same cell can look perfectly hospitable.

- `sum` — for per-step totals, such as daily primary production summing
  to a seasonal total. Meaningless for a concentration.

- `sd` — variability within the period, which is a covariate in its own
  right: a stable month and a volatile one can share a mean.

- `mode` — the commonest value, for categorical columns. Applied to them
  automatically.

Pass one method for everything, or a named vector to vary it by
variable.

## Periods that were only partly downloaded

A mean over the four days of January someone happened to fetch is not a
January mean, but nothing in the number itself says so. `min_coverage`
is the fraction of the period's *expected* steps that must carry a value
— 31 for January, 12 months for a year — not the fraction of the steps
that were downloaded. A partly-fetched period therefore fails the check
rather than passing it trivially.

The default of 0.5 will return `NA` for periods at the edges of a
request. That is the intended behaviour; set `min_coverage = 0` to
aggregate whatever is present, and `keep_counts = TRUE` to see how many
steps were behind each value.

## See also

[`downscale_time()`](https://chross22.github.io/datamatch/reference/downscale_time.md)
for the other direction,
[`upscale_grid()`](https://chross22.github.io/datamatch/reference/upscale_grid.md)
for the spatial equivalent

## Examples

``` r
if (FALSE) { # \dontrun{
daily <- accessEnvDat(vars = "SST", years = 2010, months = 1:12,
                      dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1D-m",
                      bounding_box = bb)

monthly <- upscale_time(daily, to = "month")

# The coldest day in each month, which the monthly mean hides
coldest <- upscale_time(daily, to = "month", method = "min")
} # }
```
