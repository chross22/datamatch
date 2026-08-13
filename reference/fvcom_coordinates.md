# Node or element coordinates of a mesh

Scalars sit on nodes and velocities on element centroids, so which set
of coordinates a value belongs to depends on the variable.

## Usage

``` r
fvcom_coordinates(handle, mesh)
```

## Arguments

- handle:

  an open `ncdf4` handle

- mesh:

  `"node"` or `"element"`

## Value

a data frame of `x` and `y`
