# Unique names for source columns that collide with `dat`'s

`.matched` first, then `.matched2`, `.matched3` and so on, so chaining
the same variable onto one table any number of times never produces two
columns of the same name. A `<var>_source` column follows its variable's
rename - `CHL_source` becomes `CHL.matched_source` beside
`CHL.matched` - so the tag stays next to the value it describes.

## Usage

``` r
matched_names(collisions, source_vars, taken)
```

## Arguments

- collisions:

  source columns whose names `dat` already has

- source_vars:

  every column being joined from the source

- taken:

  names already in use in `dat`

## Value

one new name per element of `collisions`
