# Refuse days that have not happened yet

A date in the future cannot have been observed, and outside a forecast
horizon it cannot have been modelled either. Left unchecked, a request
for one costs a download attempt per day and then an error from the
server about exceeding the dataset coordinates, which says nothing about
the actual mistake - usually a typo in a year, or a projection window
that ran past the end of the record.

## Usage

``` r
stop_if_future(days, source, ahead = 0L)
```

## Arguments

- days:

  the days a call is about to fetch

- source:

  the source name, for the message

- ahead:

  how many days past today this source can legitimately reach. Zero for
  anything observational; about ten for a Copernicus
  analysis-and-forecast product.

## Value

invisibly `NULL`; called for the error

## Details

Checked before anything is fetched, so the cost is a second rather than
however long the failed downloads took to give up.
