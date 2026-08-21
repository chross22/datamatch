# The file in a CEFI directory that holds one variable

Matched on the leading segment of the name, which is the variable, so
`tos` does not also match `tossq` — the squared field beside it, which
is a different quantity and would read without complaint.

## Usage

``` r
cefi_file_for(files, variable, init = NULL)
```

## Arguments

- files:

  filenames, as
  [`cefi_catalog_files()`](https://chross22.github.io/datamatch/reference/cefi_catalog_files.md)
  returns

- variable:

  the MOM6 variable name

- init:

  an initialisation tag such as `"i198001"`, for the forecast archives
  that publish one file per initialisation; `NULL` for the hindcast,
  which publishes one file per variable

## Value

one filename, or `NA` if the variable is not published here
