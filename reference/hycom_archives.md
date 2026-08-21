# HYCOM archives this package can read

Served over OPeNDAP from the HYCOM THREDDS server at the Naval Research
Laboratory. Unlike the Copernicus and FVCOM sources, HYCOM publishes
**one dataset per year** rather than one aggregation, so a request
spanning years opens several.

## Usage

``` r
hycom_archives()
```

## Value

a named list, one entry per archive, each with `url`, `layout`, `start`,
`end`, `step_hours`, `kind`, `label`, and `reference`

## One reanalysis, then a chain of operational experiments

`GLBv53X` is the GOFS 3.1 **reanalysis**: one internally consistent run
over 1994–2015, which is what makes it the default. Everything after it
is **operational** output — the model as it was running at the time,
reassigned an experiment number whenever it changed — so the later
archives are short, they overlap each other, and they are not a
reanalysis.

Together they reach the present:

|           |                          |                         |
|-----------|--------------------------|-------------------------|
| `GLBv53X` | 1994-01-01 to 2015-12-31 | reanalysis              |
| `GLBv563` | 2014-07-01 to 2016-09-30 | operational             |
| `GLBv572` | 2016-05-01 to 2017-02-01 | operational             |
| `GLBv928` | 2017-02-01 to 2017-06-01 | operational             |
| `GLBv577` | 2017-06-01 to 2017-10-01 | operational             |
| `GLBv929` | 2017-10-01 to 2018-03-20 | operational             |
| `GLBv930` | 2018-01-01 to 2020-02-19 | operational             |
| `GLBy930` | 2018-12-04 to 2024-09-05 | operational, finer grid |

## Two seams to know about

**They overlap.** `GLBv563` starts eighteen months before `GLBv53X`
ends, and several of the 2017 experiments abut or overlap. Nothing here
picks between them, because which one to prefer where they overlap is a
judgement: the reanalysis is the more consistent, the operational run
the more recent.

**The seam that matters is the run, not the grid.** Crossing from
`GLBv53X` into an operational archive means changing from a reanalysis
to the model as it was running at the time, which is a genuine
discontinuity in how the values were produced.

The grid difference is smaller than it looks. `GLBv0.08` carries 3251
latitudes and `GLBy0.08` carries 4251, but both span -80 to 90 and both
are spaced 0.04 degrees through the middle latitudes — `GLBv0.08`
stretches toward the poles where `GLBy0.08` stays uniform. Between 40
and 45 N the two hold the same 126 latitudes, identically, so on a
mid-latitude shelf the cells *do* correspond and a series spanning the
seam is on one grid. They diverge at high latitude, where a polar study
would be comparing different cells.

The longitude convention differs too — `GLBv0.08` runs -180 to 180 and
`GLBy0.08` runs 0 to 360 — but that is handled internally. Give
`bounding_box` negative west for either.

[`accessHYCOM()`](https://camilleross.org/datamatch/reference/accessHYCOM.md)
reads one archive per call and names the others when a request falls
outside the one asked for, rather than stitching them silently.

## See also

[`accessHYCOM()`](https://camilleross.org/datamatch/reference/accessHYCOM.md),
[`hycom_covering()`](https://camilleross.org/datamatch/reference/hycom_covering.md)

## Examples

``` r
names(hycom_archives())
#> [1] "GLBv53X" "GLBv563" "GLBv572" "GLBv928" "GLBv577" "GLBv929" "GLBv930"
#> [8] "GLBy930"
hycom_archives()$GLBv53X$end
#> [1] "2015-12-31"

# Which archives cover a given day
hycom_covering(as.Date("2019-06-15"))
#> [1] "GLBv930" "GLBy930"
```
