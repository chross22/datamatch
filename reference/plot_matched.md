# Plot observations coloured by a matched covariate

What
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
produced, seen rather than summarised. Points that came back `NA` are
drawn as open circles rather than dropped, since a cluster of them is
usually the real finding — observations outside the environmental data's
extent or in a period it does not cover.

## Usage

``` r
plot_matched(matched, var = NULL, palette = "viridis", main = NULL, ...)
```

## Arguments

- matched:

  an `sf` object from
  [`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)

- var:

  which matched variable to colour by; `NULL` uses the first covariate

- palette:

  a
  [`grDevices::hcl.colors()`](https://rdrr.io/r/grDevices/palettes.html)
  palette name

- main:

  plot title

- ...:

  passed to
  [`graphics::plot()`](https://rdrr.io/r/graphics/plot.default.html)

## Value

the plotted values, invisibly

## Subset to one period first

The colour scale spans every observation passed in, so plotting several
months of a seasonal variable at once mixes the seasons together and the
map reads as noise: a warm February inshore point and a cool August
offshore one can take the same colour. Subset to a period before
plotting, and the spatial pattern reappears:

    plot_matched(matched[matched$MONTH == 7, ], "SST")

## See also

[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md),
[`plot_env()`](https://chross22.github.io/datamatch/reference/plot_env.md)

## Examples

``` r
if (FALSE) { # \dontrun{
matched <- matchData(observations, env)

plot_matched(matched, "SST")
# Open circles are observations that matched nothing.
} # }
```
