# Mesh coordinates, cached to disk

The mesh never changes, so its coordinates are worth keeping. Without
this a fully cached request would still open an OPeNDAP connection and
pull 48,451 points to work out which rows it already has — several
seconds to discover there is nothing to do. Everywhere else in this
package a cached call is cheap, and this keeps that true here.

## Usage

``` r
fvcom_mesh_coordinates(archive_name, spec, mesh)
```

## Arguments

- archive_name:

  the archive's name, part of the cache key

- spec:

  one entry of
  [`fvcom_archives()`](https://chross22.github.io/datamatch/reference/fvcom_archives.md)

- mesh:

  `"node"` or `"element"`

## Value

a data frame of `x` and `y`
