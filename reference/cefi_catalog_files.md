# The filenames one CEFI directory publishes

The filenames one CEFI directory publishes

## Usage

``` r
cefi_catalog_files(path, frequency, grid, release)
```

## Arguments

- path:

  the catalog path, as in a
  [`cefi_archives()`](https://camilleross.org/datamatch/reference/cefi_archives.md)
  entry

- frequency:

  `"monthly"` or `"daily"`

- grid:

  `"regrid"` or `"raw"`

- release:

  a release directory, or `"latest"`

## Value

the `.nc` filenames in that directory, possibly empty

## Why the server is asked rather than the name constructed

A CEFI filename carries the release and the period it covers —
`tos.nwa.full.hcast.monthly.regrid.r20250715.199301-202312.nc` — so
constructing one means hard-coding both. Both move: the hindcast has
been released twice already, and each release extends the record, so a
name built from last year's constants fetches nothing the moment CEFI
publishes again.

The directory listing is read instead, which costs one request and is
right by construction. It is memoised for the session, because a fetch
of eight variables would otherwise read the same listing eight times.
