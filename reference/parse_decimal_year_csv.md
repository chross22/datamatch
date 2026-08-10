# Parse a daily index published as decimal years

The format the Jutras et al. retroflection index is published in: a
couple of figure-caption lines, a `Date,<label>` header, then one row
per day with the date as a decimal year.

## Usage

``` r
parse_decimal_year_csv(lines, name)
```

## Arguments

- lines:

  the downloaded file's lines

- name:

  what to call the value column

## Value

a data frame with `YEAR`, `MONTH`, and the named value column

## Two conversions worth stating

**Decimal years use a fixed 365-day year here.** The step between
consecutive rows is 1/365 to eleven significant figures, so leap days
are not represented and a date is recovered as day
`round(fraction * 365)` of its year. Assuming 365.25 instead would walk
the derived dates off by up to several days over the record.

**Daily values are averaged to monthly.** Every other index in this
package is monthly, and
[`attach_climate_index()`](https://chross22.github.io/datamatch/reference/attach_climate_index.md)
joins on year and month, so a daily series has nothing to join to. The
underlying index is already smoothed with a 12-month rolling mean, so
monthly averaging discards very little.

Months backed by fewer than half their days are dropped rather than
reported. The record's first and last months are partial by
construction, and the fixed 365-day year rolls the final record into a
January of its own — which would otherwise surface as a
confident-looking monthly value resting on a single day.
