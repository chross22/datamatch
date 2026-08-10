# Build the argument vector for a `copernicusmarine subset` call

Kept separate from the call itself so the arguments can be inspected and
tested without contacting the API.

## Usage

``` r
build_copernicus_args(
  dataset_id,
  vars,
  bb,
  depth,
  time,
  ofile,
  overwrite = TRUE,
  dry_run = FALSE,
  log_level = "ERROR"
)
```

## Arguments

- dataset_id:

  Copernicus dataset identifier

- vars:

  variable codes to request

- bb:

  bounding box: a named list or vector with `xmin`, `xmax`, `ymin`,
  `ymax`, or an `sf`/`sfc` object to take the bounding box of

- depth:

  length-2 depth range in metres

- time:

  or length 1 or 2; a single value requests one instant

- ofile:

  full path of the file to write

- overwrite:

  pass `--overwrite`

- dry_run:

  pass `--dry-run`, which validates the request against the API without
  downloading anything

- log_level:

  one of the client's levels: DEBUG, INFO, WARN, ERROR, CRITICAL, QUIET.
  `ERROR` is the default rather than `QUIET`, because the client says
  *why* a request failed at ERROR and says nothing at all at QUIET. A
  date past the end of a reanalysis, for instance, exits non-zero with
  no output under QUIET, leaving the caller an empty failure to explain.

## Value

character vector of arguments, suitable for
[`system2()`](https://rdrr.io/r/base/system2.html)

## Details

Long-form flags are used throughout (`--dataset-id` rather than `-i`).
The short forms are aliases the client has changed before, and a renamed
flag fails as an unrecognised option rather than as anything
self-explanatory.
