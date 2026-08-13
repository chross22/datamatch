# Package index

## Fetching data

Four sources behind one interface, sharing one set of variable names,
and all returning the same shape. A value of the same name from two of
them is not the same number - each function’s help says what its source
is and is not good for.

- [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
  : Access environmental data from Copernicus Marine Service
- [`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md)
  : Access FVCOM output from the NECOFS hindcast
- [`accessHYCOM()`](https://chross22.github.io/datamatch/reference/accessHYCOM.md)
  : Access HYCOM output from the GOFS 3.1 reanalysis
- [`accessCCMP()`](https://chross22.github.io/datamatch/reference/accessCCMP.md)
  : Access CCMP ocean surface winds
- [`accessERDDAP()`](https://chross22.github.io/datamatch/reference/accessERDDAP.md)
  : Access satellite data through ERDDAP
- [`fill_satellite_gaps()`](https://chross22.github.io/datamatch/reference/fill_satellite_gaps.md)
  : Fill satellite gaps with the model equivalent
- [`forecast_variables()`](https://chross22.github.io/datamatch/reference/forecast_variables.md)
  : Forecast equivalents of the catalog variables

## Matching

The spatiotemporal nearest-feature join, the columns it adds, and where
each value came from.

- [`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
  : Match one set of points to another in space and time
- [`covariate_columns()`](https://chross22.github.io/datamatch/reference/covariate_columns.md)
  : Covariate column names in an environmental data object
- [`source_of()`](https://chross22.github.io/datamatch/reference/source_of.md)
  : Which source and archive produced a fetched object

## Resampling

Moving between grids and time steps. Aggregating loses detail, which is
the safe direction; interpolating adds cells, not information.

- [`upscale_grid()`](https://chross22.github.io/datamatch/reference/upscale_grid.md)
  : Aggregate environmental data onto a coarser grid
- [`downscale_grid()`](https://chross22.github.io/datamatch/reference/downscale_grid.md)
  : Interpolate environmental data onto a finer grid
- [`upscale_time()`](https://chross22.github.io/datamatch/reference/upscale_time.md)
  : Aggregate environmental data onto a coarser time step
- [`downscale_time()`](https://chross22.github.io/datamatch/reference/downscale_time.md)
  : Interpolate environmental data onto a finer time step
- [`grid_resolution()`](https://chross22.github.io/datamatch/reference/grid_resolution.md)
  : Grid resolution of an environmental data object

## Seafloor terrain

Depth, slope, aspect, and TPI from NOAA ETOPO.

- [`fetch_bathymetry()`](https://chross22.github.io/datamatch/reference/fetch_bathymetry.md)
  : Fetch static bathymetry for a study area
- [`attach_bathymetry()`](https://chross22.github.io/datamatch/reference/attach_bathymetry.md)
  : Attach static bathymetry to a table of points
- [`bathymetry_variables()`](https://chross22.github.io/datamatch/reference/bathymetry_variables.md)
  : Static seafloor variables

## Climate indices

Basin-scale indices, their units, and the cache that expires on each
provider’s publishing cadence.

- [`fetch_climate_index()`](https://chross22.github.io/datamatch/reference/fetch_climate_index.md)
  : Fetch a monthly climate index
- [`attach_climate_index()`](https://chross22.github.io/datamatch/reference/attach_climate_index.md)
  : Attach climate indices to observations
- [`climate_indices()`](https://chross22.github.io/datamatch/reference/climate_indices.md)
  : Catalog of basin-scale climate indices
- [`index_dictionary()`](https://chross22.github.io/datamatch/reference/index_dictionary.md)
  [`print(`*`<datamatch_index_dictionary>`*`)`](https://chross22.github.io/datamatch/reference/index_dictionary.md)
  : Printable dictionary of climate indices
- [`climate_index_status()`](https://chross22.github.io/datamatch/reference/climate_index_status.md)
  [`print(`*`<datamatch_index_status>`*`)`](https://chross22.github.io/datamatch/reference/climate_index_status.md)
  : What is cached, how old it is, and whether it is due a refresh
- [`refresh_climate_index()`](https://chross22.github.io/datamatch/reference/refresh_climate_index.md)
  : Re-download cached climate indices

## Plotting

Base-graphics views of what was downloaded and what it matched to. Each
returns the data it drew.

- [`plot_env()`](https://chross22.github.io/datamatch/reference/plot_env.md)
  : Map an environmental variable
- [`plot_coverage()`](https://chross22.github.io/datamatch/reference/plot_coverage.md)
  : Plot how much data each time step actually has
- [`plot_series()`](https://chross22.github.io/datamatch/reference/plot_series.md)
  : Plot a variable through time
- [`plot_matched()`](https://chross22.github.io/datamatch/reference/plot_matched.md)
  : Plot observations coloured by a matched covariate

## Catalogs and lookup

What each source offers, which dataset or archive a variable comes from,
and where it is documented.

- [`variable_dictionary()`](https://chross22.github.io/datamatch/reference/variable_dictionary.md)
  [`print(`*`<datamatch_dictionary>`*`)`](https://chross22.github.io/datamatch/reference/variable_dictionary.md)
  : Printable dictionary of variable names
- [`variable_dataset()`](https://chross22.github.io/datamatch/reference/variable_dataset.md)
  : Look up the dataset a set of variables comes from
- [`copernicus_variables()`](https://chross22.github.io/datamatch/reference/copernicus_variables.md)
  : Catalog of Copernicus variables under familiar names
- [`fvcom_variables()`](https://chross22.github.io/datamatch/reference/fvcom_variables.md)
  : Catalog of FVCOM variables under the same names as the Copernicus
  ones
- [`fvcom_dictionary()`](https://chross22.github.io/datamatch/reference/fvcom_dictionary.md)
  : Printable dictionary of FVCOM variables
- [`fvcom_archives()`](https://chross22.github.io/datamatch/reference/fvcom_archives.md)
  : FVCOM archives this package ships with
- [`fvcom_archive()`](https://chross22.github.io/datamatch/reference/fvcom_archive.md)
  : Describe any FVCOM archive, so it can be read like a built-in one
- [`hycom_variables()`](https://chross22.github.io/datamatch/reference/hycom_variables.md)
  : Catalog of HYCOM variables under the same names as the Copernicus
  ones
- [`hycom_dictionary()`](https://chross22.github.io/datamatch/reference/hycom_dictionary.md)
  : Printable dictionary of HYCOM variables
- [`hycom_archives()`](https://chross22.github.io/datamatch/reference/hycom_archives.md)
  : HYCOM archives this package can read
- [`hycom_covering()`](https://chross22.github.io/datamatch/reference/hycom_covering.md)
  : Which HYCOM archives cover a given date
- [`ccmp_variables()`](https://chross22.github.io/datamatch/reference/ccmp_variables.md)
  : Catalog of CCMP wind variables
- [`ccmp_dictionary()`](https://chross22.github.io/datamatch/reference/ccmp_dictionary.md)
  : Printable dictionary of CCMP variables
- [`ccmp_versions()`](https://chross22.github.io/datamatch/reference/ccmp_versions.md)
  : CCMP versions this package can read
- [`erddap_datasets()`](https://chross22.github.io/datamatch/reference/erddap_datasets.md)
  : Satellite datasets read through ERDDAP
- [`erddap_dataset()`](https://chross22.github.io/datamatch/reference/erddap_dataset.md)
  : Describe any ERDDAP griddap dataset, so it can be read like a
  built-in one
- [`erddap_dictionary()`](https://chross22.github.io/datamatch/reference/erddap_dictionary.md)
  : Printable dictionary of the ERDDAP datasets and their variables
- [`product_url()`](https://chross22.github.io/datamatch/reference/product_url.md)
  : Copernicus Marine product page for a product identifier
- [`as_markdown()`](https://chross22.github.io/datamatch/reference/as_markdown.md)
  : Render a dictionary as a markdown table
