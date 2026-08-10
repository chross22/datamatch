# Locate the Copernicus Marine command line tool

Downloads go through `copernicusmarine`, the official Python client. It
is not an R package and is not installed with this one.

## Usage

``` r
copernicus_app()
```

## Value

the path to the executable

## Details

The executable is taken from `getOption("datamatch.copernicusmarine")`
when set, and otherwise looked up on the `PATH`. Setting the option
explicitly is worth doing when it lives in a conda environment that
RStudio does not inherit the `PATH` of — a common source of "works in
the terminal, fails in R":

    options(datamatch.copernicusmarine = "~/miniconda3/bin/copernicusmarine")
