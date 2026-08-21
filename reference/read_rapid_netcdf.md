# Read the RAPID overturning series and average it to monthly

The RAPID array publishes a twelve-hourly NetCDF series at a stable URL,
while the ASCII equivalent sits behind a signup form. So this reads the
overturning variable from the downloaded binary and aggregates it to the
monthly step the rest of the indices use. Downloading and caching happen
in
[`cached_index_file()`](https://camilleross.org/datamatch/reference/cached_index_file.md),
which every index shares.

## Usage

``` r
read_rapid_netcdf(file, name)
```

## Arguments

- file:

  a local NetCDF file, already downloaded

- name:

  the index name, for error messages

## Value

a data frame with `YEAR`, `MONTH`, and a column named for the index

## Details

Averaging is the honest direction here. The twelve-hourly series is
dominated by Ekman variability that a monthly covariate cannot represent
anyway, and a monthly mean of it is a well-defined quantity. Months are
not filtered on completeness: the array reports continuously within its
deployment periods, so a short month is a gap in the record rather than
a partial average, and it is more useful to see it than to drop it.
