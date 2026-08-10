# Download a Copernicus subset through the command line client

Wraps one `copernicusmarine subset` call. Arguments are passed to
[`system2()`](https://rdrr.io/r/base/system2.html) as a character vector
rather than pasted into a shell string, so paths containing spaces are
handled by the process boundary instead of by quoting.

## Usage

``` r
download_copernicus_subset(
  dataset_id,
  vars,
  bb,
  depth,
  time,
  ofile,
  overwrite = TRUE,
  tries = 3,
  wait = 10,
  verbose = FALSE,
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

- tries:

  number of attempts before giving up

- wait:

  seconds to wait between attempts

- verbose:

  echo the command and the client's output

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

`0`, invisibly, on success; errors otherwise

## Retries

The API is intermittently unavailable under load, and a failed request
is usually transient. Failures are retried `tries` times with a pause
between, and only a run of failures is raised as an error.

That error carries the client's own output. A download that fails and
returns quietly would surface later as an unreadable file, at the point
of
[`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html),
with nothing left to say why.
