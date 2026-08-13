# Read one day of an ERDDAP dataset over a bounding box

Read one day of an ERDDAP dataset over a bounding box

## Usage

``` r
erddap_read_day(spec, vars, day, bounding_box)
```

## Arguments

- spec:

  one entry of
  [`erddap_datasets()`](https://chross22.github.io/datamatch/reference/erddap_datasets.md)

- vars:

  catalog names to read

- day:

  the day to read

- bounding_box:

  the box, negative west

## Value

a data frame of `x`, `y`, the variables, and `YEAR`/`MONTH`/`DAY`

## Why the returned times are filtered

griddap wants a time that exists on the axis, and these products are
stamped at a nominal hour that differs between them — MUR at 09:00 UTC,
others at midnight. So a range covering the day is requested rather than
an instant, which avoids having to know the hour in advance.

But **griddap snaps a range's endpoints to the nearest step rather than
the enclosing ones**, so asking for 00:00:00 to 23:59:59 on a MUR day
returns that day's 09:00 field *and the next day's*: 23:59:59 is nearer
to tomorrow at 09:00 than to today's. Taking what came back would have
silently mixed two days into one.

The time axis of the returned file is therefore read and only the steps
actually falling on the requested day are kept. A day with no step of
its own yields nothing rather than borrowing its neighbour's.
