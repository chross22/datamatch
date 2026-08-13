# CCMP versions this package can read

Remote Sensing Systems publishes CCMP as a plain directory tree over
HTTPS, one file per day. No account is needed for it: the registration
RSS asks for covers their FTP service, and the HTTPS archive is open.

## Usage

``` r
ccmp_versions()
```

## Value

a named list, one entry per version, each with `root`, `pattern`,
`step_hours`, `start`, `resolution`, and `reference`

## See also

[`accessCCMP()`](https://chross22.github.io/datamatch/reference/accessCCMP.md)

## Examples

``` r
names(ccmp_versions())
#> [1] "v03.1"
ccmp_versions()$v03.1$step_hours
#> [1] 6
```
