# Describe any CEFI directory, so it can be read like a built-in one

[`cefi_archives()`](https://chross22.github.io/datamatch/reference/cefi_archives.md)
ships the Northwest Atlantic hindcast and its decadal forecast, because
that is the domain this package was written for. CEFI also publishes the
Northeast Pacific, the Arctic, the Pacific Islands and the Great Lakes,
on the same server in the same layout, and this is how to reach them:
give it a catalog path and it reads the directory to work out the rest.

## Usage

``` r
cefi_archive(
  path,
  frequency = c("monthly", "daily"),
  grid = c("regrid", "raw"),
  release = "latest",
  label = NULL
)
```

## Arguments

- path:

  the catalog path under the THREDDS root, as in a
  [`cefi_archives()`](https://chross22.github.io/datamatch/reference/cefi_archives.md)
  entry's `path`

- frequency:

  `"monthly"` or `"daily"`

- grid:

  `"regrid"` for the regular latitude-longitude interpolation, or
  `"raw"` for the model's own curvilinear grid. This package reads
  `"regrid"`; `"raw"` will open but not read, because the reader assumes
  a regular grid.

- release:

  a release directory such as `"r20250715"`, or `"latest"`

- label:

  a human-readable name; defaults to the path

## Value

a list in the shape
[`cefi_archives()`](https://chross22.github.io/datamatch/reference/cefi_archives.md)
entries take, ready to pass to
[`accessCEFI()`](https://chross22.github.io/datamatch/reference/accessCEFI.md)
as `archive`

## What it checks

The catalog is read once, so a path that is wrong, a release that does
not exist, or a server that is down fails here — with the reason —
rather than part-way through a fetch. The variables actually published
in that directory come back in the returned spec, so
[`str()`](https://rdrr.io/r/utils/str.html) on it says what is there.

## See also

[`accessCEFI()`](https://chross22.github.io/datamatch/reference/accessCEFI.md),
[`cefi_archives()`](https://chross22.github.io/datamatch/reference/cefi_archives.md)

## Examples

``` r
if (FALSE) { # \dontrun{
pacific <- cefi_archive(paste0("Projects/CEFI/regional_mom6/cefi_portal/",
                               "northeast_pacific/full_domain/hindcast"))
str(pacific)
} # }
```
