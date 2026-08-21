# The OB.DAAC filename that holds one variable for one period

The OB.DAAC filename that holds one variable for one period

## Usage

``` r
obdaac_filename(sensor, entry, when, frequency, resolution)
```

## Arguments

- sensor:

  one entry of
  [`obdaac_sensors()`](https://chross22.github.io/datamatch/reference/obdaac_sensors.md)

- entry:

  one entry of
  [`obdaac_variables()`](https://chross22.github.io/datamatch/reference/obdaac_variables.md)

- when:

  the day, or the first of the month for a composite

- frequency:

  `"daily"` or `"monthly"`

- resolution:

  `"4km"` or `"9km"`

## Value

the filename

## Why the name is constructed rather than looked up

OB.DAAC has a file search that would answer this exactly, report each
file's size, and know which days a sensor missed. It accepts **POST
only**, and
[`utils::download.file()`](https://rdrr.io/r/utils/download.file.html)
cannot POST, so using it would mean adding an HTTP package to reach one
endpoint.

The names are worth constructing instead because they are strictly
regular across every sensor and suite here — verified against the
archive for SeaWiFS, both MODIS instruments and all three VIIRS, for
daily and monthly, for the colour suites and the temperature ones. The
one mission whose names are *not* constructible is PACE, and it is left
out for that reason among others; see
[`obdaac_sensors()`](https://chross22.github.io/datamatch/reference/obdaac_sensors.md).

What is lost is the ability to know, before trying, that a sensor
returned nothing on a given day. That surfaces as a failed download for
that step instead, which
[`accessOBDAAC()`](https://chross22.github.io/datamatch/reference/accessOBDAAC.md)
reports by name and carries on past.
