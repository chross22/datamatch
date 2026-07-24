
<!-- README.md is generated from README.Rmd. Please edit that file -->

# datamatch

<!-- badges: start -->

[![R-CMD-check](https://github.com/chross22/datamatch/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/chross22/datamatch/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of datamatch is to pull environmental data from Copernicus
Marine Service and match spatially and temporally to species occurence
data.

## Installation

You can install the development version of datamatch from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("chross22/datamatch")
```

## Set up

Before installation, you must install the Copernicus Marine toolbox from
Copernicus Marine Service. This requires registering for a Copernicus
account if you don’t already have one, as you will need these
credentials to configure the toolbox.

To install this toolbox, visit the Copernicus website. In brief, …

## Example

This is a basic example which shows you how to solve a common problem:

``` r
library(datamatch)
## basic example code
```

What is special about using `README.Rmd` instead of just `README.md`?
You can include R chunks like so:

``` r
summary(cars)
#>      speed           dist       
#>  Min.   : 4.0   Min.   :  2.00  
#>  1st Qu.:12.0   1st Qu.: 26.00  
#>  Median :15.0   Median : 36.00  
#>  Mean   :15.4   Mean   : 42.98  
#>  3rd Qu.:19.0   3rd Qu.: 56.00  
#>  Max.   :25.0   Max.   :120.00
```

You’ll still need to render `README.Rmd` regularly, to keep `README.md`
up-to-date. `devtools::build_readme()` is handy for this.
