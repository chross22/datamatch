# Fetch a monthly climate index

Downloads an index from its official source and returns it as a tidy
monthly series.

## Usage

``` r
fetch_climate_index(
  index,
  years = NULL,
  url = NULL,
  max_age = NULL,
  refresh = FALSE
)
```

## Arguments

- index:

  an index name from
  [`climate_indices()`](https://camilleross.org/datamatch/reference/climate_indices.md)

- years:

  years to keep; `NULL` keeps the whole record

- url:

  override the catalog URL, if a provider has moved the file

- max_age:

  how many days a cached copy may be reused for. `NULL` uses the
  provider's publishing cadence.

- refresh:

  re-download even if a fresh cached copy exists

## Value

a data frame with `YEAR`, `MONTH`, and a column named after the index

## Details

The published files use fixed-width year-by-month tables with
provider-specific missing-value codes, which are parsed here into one
row per month.

## Citing an index

`LCR` and `AMOC` come from specific published sources rather than being
operational products, and should be cited when used:

- Jutras M, Dufour CO, Mucci A, Talbot LC (2023) Large-scale control of
  the retroflection of the Labrador Current. *Nature Communications*
  **14**:2623.
  [doi:10.1038/s41467-023-38321-y](https://doi.org/10.1038/s41467-023-38321-y)

- Moat BI, Smeed DA, Rayner D, Johns WE, Smith R, Volkov D, Elipot S,
  Petit T, Kajtar J, Baringer MO, Collins J (2026). Atlantic meridional
  overturning circulation observed by the RAPID-MOCHA-WBTS array at 26N
  from 2004 to 2024 (v2024.1a). British Oceanographic Data Centre, NERC,
  UK.
  [doi:10.5285/48d0bf43-0598-ceb2-e063-7086abc062f1](https://doi.org/10.5285/48d0bf43-0598-ceb2-e063-7086abc062f1)

BODC mints a new DOI for each RAPID release and retires the old one, so
the `AMOC` reference changes when a new version is published.
`as.data.frame(index_dictionary())$reference` is the current one.

The series is the source data published with that paper's Figure 3,
fetched from the journal rather than recomputed, so the values are the
authors' own. `as.data.frame(index_dictionary())$reference` carries this
at runtime.

Note that these are the **raw** index values, running roughly -0.09 to
0.18, consistent with a fraction of the seeded particles. Figure 3a of
the paper plots a detrended, smoothed series normalized to `[-1, 1]`,
spanning about -0.6 to +0.5. Both describe the same quantity, but a
value here is not comparable with that figure. Reproducing the plotted
variant means applying the paper's chain: detrend, 12-month rolling
mean, rescale to `[-1, 1]`, subtract the 1993-2015 mean.

## Staying current

Downloads are cached, and the cache expires on an interval matched to
how often each provider actually publishes: weekly for the monthly NOAA
indices, monthly for RAPID, never for `LCR`, which is a finished
dataset. So a living index re-downloads on its own without being asked,
and a finished one is not re-fetched pointlessly.

Two things back that up. If the returned series ends further behind the
present than its provider's usual lag, that is reported: a fresh
download of a stale file is still stale, so the check is on the data
rather than on the cache. And if a download fails while a cached copy
exists, the cached copy is returned with a warning rather than an error,
so a provider's outage does not become yours.

[`climate_index_status()`](https://camilleross.org/datamatch/reference/climate_index_status.md)
reports what is cached and what is due;
[`refresh_climate_index()`](https://camilleross.org/datamatch/reference/refresh_climate_index.md)
forces the issue.

## Examples

``` r
if (FALSE) { # \dontrun{
nao <- fetch_climate_index("NAO", years = 2000:2020)
head(nao)
} # }
```
