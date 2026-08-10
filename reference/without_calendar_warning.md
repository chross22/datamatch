# Evaluate something, muffling only terra's unknown-calendar warning

Some Copernicus files declare their calendar as `Gregorian`, which is
not one of the spellings the CF conventions list. terra warns and
assumes the standard calendar, which is correct — `Gregorian` *is* the
standard calendar, spelled with a capital — so the warning says nothing
a caller can act on. One per file makes fifty on a fifty-day fetch,
burying the warnings that do matter.

## Usage

``` r
without_calendar_warning(expr)
```

## Arguments

- expr:

  an expression to evaluate

## Value

the value of `expr`

## Details

Matched on the message text so that only this one is caught. Every other
warning is left to propagate, since a file that is genuinely unreadable
should still say so.
