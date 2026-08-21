# The release a CEFI filename came from

`release = "latest"` is how to follow whatever CEFI published most
recently, and it is the default because a pinned release goes stale. It
is a terrible thing to record, though: a result tagged `latest` says
only that it was fetched at some point, and two runs a year apart carry
the same tag and different numbers.

## Usage

``` r
cefi_release_of(file, fallback = "unknown-release")
```

## Arguments

- file:

  a CEFI filename

- fallback:

  what to report if the name carries no release

## Value

the release, as `"r20250715"`

## Details

So the tag is taken from the filename actually read, which names its
release outright. What a caller asked for and what they got are
different questions, and provenance is the second one.
