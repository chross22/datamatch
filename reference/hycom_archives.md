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

a named list, one entry per archive, each with `url` (a template taking
the year), `years`, `step_hours`, `label`, and `reference`

## Coverage and the gap after 2015

Only the GOFS 3.1 reanalysis, `GLBv0.08/expt_53.X`, is listed. It runs
1994–2015, which overlaps GLORYS well. HYCOM's later record is split
across several short experiments with differing grids and variable sets,
and picking between them is a judgement about which to track rather than
a lookup — so this offers the one long consistent record and says
nothing about the rest.

## See also

[`accessHYCOM()`](https://chross22.github.io/datamatch/reference/accessHYCOM.md)

## Examples

``` r
names(hycom_archives())
#> [1] "GLBv53X"
hycom_archives()$GLBv53X$years
#>  [1] 1994 1995 1996 1997 1998 1999 2000 2001 2002 2003 2004 2005 2006 2007 2008
#> [16] 2009 2010 2011 2012 2013 2014 2015
```
