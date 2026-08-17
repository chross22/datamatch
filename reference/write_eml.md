# Write EML metadata for a matched table

Produces an [Ecological Metadata
Language](https://eml.ecoinformatics.org/) document describing a table
[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
produced: what each column is, where and when it covers, which data
sources went into it, and what to cite. EML is what repositories such as
EDI and the LTER network expect alongside a deposited dataset.

## Usage

``` r
write_eml(
  x,
  file,
  title,
  creator,
  abstract = NULL,
  contact = creator,
  keywords = NULL,
  entity_name = basename(file),
  validate = TRUE
)
```

## Arguments

- x:

  an `sf` object from
  [`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md),
  or any of the access functions

- file:

  where to write the XML

- title:

  the dataset's title

- creator:

  a list in EML `creator` shape, or a character name. An ORCID is worth
  including; see the examples.

- abstract:

  a paragraph on what the dataset is and why it exists

- contact:

  the contact party; defaults to `creator`

- keywords:

  optional keywords

- entity_name:

  what the data file is called, for the `dataTable`

- validate:

  validate against the EML schema before returning. Requires the `emld`
  package, and is worth leaving on: an invalid document is rejected at
  submission rather than at write time.

## Value

the path, invisibly

## What is filled in for you

Nearly all of it, because the package already knows:

- **Geographic coverage** from the object's own bounding box.

- **Temporal coverage** from its `YEAR`/`MONTH`/`DAY` columns.

- **An attribute for every column** — definition, units, and measurement
  scale — with labels and units taken from whichever source catalog
  defines that name, and this package's own conventions used for the
  time, `LON`/`LAT`, `<var>_source` and `<var>_depth` columns.

- **Methods and citations** from the `<var>_source` columns
  [`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
  writes. This is the part worth having: a table with four sources
  chained onto it produces a methods section naming all four and a
  reference for each, rather than leaving you to reconstruct which fetch
  produced which column.

What it cannot know is who you are and what the dataset is *for*, so
`title`, `creator` and `abstract` are yours to give.

## Units, and why some are declared

EML validates units against a fixed vocabulary and rejects anything not
on it. **`PSU` and `N/m2` are both absent from it** — salinity and wind
stress, two of this package's core variables — so they are written as
*custom* units and declared in the document's own `unitList`. That is
the mechanism EML provides for it, and the resulting document validates.

## See also

[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md),
which writes the `<var>_source` columns this reads, and
[`source_of()`](https://chross22.github.io/datamatch/reference/source_of.md)

## Examples

``` r
if (FALSE) { # \dontrun{
matched <- matchData(observations, accessHYCOM(vars = "BOTS", ...))

write_eml(
  matched, "matched.xml",
  title = "Bottom salinity matched to trawl stations, Gulf of Maine",
  creator = list(individualName = list(givenName = "Camille",
                                       surName = "Ross"),
                 electronicMailAddress = "camille.ross@maine.edu",
                 userId = list(directory = "https://orcid.org",
                               userId = "0000-0002-1428-2294")),
  abstract = "Stations from the spring survey with HYCOM bottom salinity.")
} # }
```
