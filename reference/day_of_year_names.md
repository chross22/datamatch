# Column names that mean day-of-year, not year or day-of-month

[`standardize_time_columns()`](https://camilleross.org/datamatch/reference/standardize_time_columns.md)
finds a table's time columns by prefix, which sweeps in names that look
right and mean something else: `yearday` begins with `year`, `dayofyear`
with `day`. Both hold an ordinal day, so accepting either would put
every row in a period no `source` covers - an all-NA join behind a vague
warning rather than an error.

## Usage

``` r
day_of_year_names
```

## Value

lower-case day-of-year column names

## Details

Names here are never candidates for any time column. They are still
reported as near misses when nothing else matches, so a caller who did
mean one of them is told to rename it rather than left guessing.

Compared lower-case, so casing in the data does not matter. Extend it
when another convention turns up; the only effect of a name being listed
is that
[`matchData()`](https://camilleross.org/datamatch/reference/matchData.md)
declines to guess.
