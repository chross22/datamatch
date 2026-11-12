# Remove an Earthdata appkey from a message

The appkey travels in the query string, and
[`download.file()`](https://rdrr.io/r/utils/download.file.html) quotes
the URL it failed on, so a failure message carries the key. Those
messages are collected and shown as a warning, which ends up on the
console, in logs and in CI output. The key is a credential, so it is
replaced wherever it appears: after `appkey=`, and as a literal string
in case a message carries it in some other form.

## Usage

``` r
redact_appkey(x, key = NULL)
```

## Arguments

- x:

  messages

- key:

  the appkey in use, if any

## Value

`x` with the key replaced by `<redacted>`
