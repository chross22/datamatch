# Render a dictionary as a markdown table

The console view is a fixed-width table, which turns to mush when pasted
into a README or a notebook. This emits a pipe table instead, so a
dictionary can be dropped straight into documentation.

## Usage

``` r
as_markdown(x, columns = NULL)
```

## Arguments

- x:

  a dictionary from
  [`variable_dictionary()`](https://chross22.github.io/datamatch/reference/variable_dictionary.md)
  or
  [`index_dictionary()`](https://chross22.github.io/datamatch/reference/index_dictionary.md)

- columns:

  which columns to include; defaults to the readable subset

## Value

a character vector of markdown lines, invisibly; printed as a side
effect

## Examples

``` r
as_markdown(variable_dictionary())
#> | name      | variable              | label                                   | units     |
#> | --------- | --------------------- | --------------------------------------- | --------- |
#> | SST       | thetao                | Sea surface temperature                 | degrees C |
#> | SSS       | so                    | Sea surface salinity                    | PSU       |
#> | BOTT      | bottomT               | Bottom temperature                      | degrees C |
#> | BOTS      | so                    | Bottom salinity                         | PSU       |
#> | UO        | uo                    | Eastward current velocity               | m/s       |
#> | VO        | vo                    | Northward current velocity              | m/s       |
#> | SSH       | zos                   | Sea surface height                      | m         |
#> | MLD       | mlotst                | Mixed layer depth                       | m         |
#> | SIC       | siconc                | Sea ice concentration                   | fraction  |
#> | CHL       | CHL                   | Chlorophyll-a concentration (satellite) | mg/m3     |
#> | PP        | PP                    | Primary production (satellite)          | mg/m2/day |
#> | DIATO     | DIATO                 | Diatom chlorophyll-a concentration      | mg/m3     |
#> | DINO      | DINO                  | Dinophyte chlorophyll-a concentration   | mg/m3     |
#> | NO3       | no3                   | Nitrate concentration                   | mmol/m3   |
#> | PO4       | po4                   | Phosphate concentration                 | mmol/m3   |
#> | O2        | o2                    | Dissolved oxygen                        | mmol/m3   |
#> | PH        | ph                    | pH                                      | unitless  |
#> | CHL_MODEL | chl                   | Chlorophyll-a concentration (model)     | mg/m3     |
#> | NPP_MODEL | nppv                  | Net primary production (model)          | mg/m3/day |
#> | WSPD      | wind_speed            | Wind speed                              | m/s       |
#> | UWND      | eastward_wind         | Eastward wind                           | m/s       |
#> | VWND      | northward_wind        | Northward wind                          | m/s       |
#> | TAUX      | eastward_stress       | Eastward wind stress                    | N/m2      |
#> | TAUY      | northward_stress      | Northward wind stress                   | N/m2      |
#> | TAU       | wind_stress_magnitude | Wind stress magnitude                   | N/m2      |

# Include the dataset identifiers as well
as_markdown(variable_dictionary(), columns = c("name", "variable", "dataset"))
#> | name      | variable              | dataset                                           |
#> | --------- | --------------------- | ------------------------------------------------- |
#> | SST       | thetao                | cmems_mod_glo_phy_my_0.083deg_P1M-m               |
#> | SSS       | so                    | cmems_mod_glo_phy_my_0.083deg_P1M-m               |
#> | BOTT      | bottomT               | cmems_mod_glo_phy_my_0.083deg_P1M-m               |
#> | BOTS      | so                    | cmems_mod_glo_phy_my_0.083deg_P1M-m               |
#> | UO        | uo                    | cmems_mod_glo_phy_my_0.083deg_P1M-m               |
#> | VO        | vo                    | cmems_mod_glo_phy_my_0.083deg_P1M-m               |
#> | SSH       | zos                   | cmems_mod_glo_phy_my_0.083deg_P1M-m               |
#> | MLD       | mlotst                | cmems_mod_glo_phy_my_0.083deg_P1M-m               |
#> | SIC       | siconc                | cmems_mod_glo_phy_my_0.083deg_P1M-m               |
#> | CHL       | CHL                   | cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M |
#> | PP        | PP                    | cmems_obs-oc_glo_bgc-pp_my_l4-multi-4km_P1M       |
#> | DIATO     | DIATO                 | cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M |
#> | DINO      | DINO                  | cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M |
#> | NO3       | no3                   | cmems_mod_glo_bgc_my_0.25deg_P1M-m                |
#> | PO4       | po4                   | cmems_mod_glo_bgc_my_0.25deg_P1M-m                |
#> | O2        | o2                    | cmems_mod_glo_bgc_my_0.25deg_P1M-m                |
#> | PH        | ph                    | cmems_mod_glo_bgc_my_0.25deg_P1M-m                |
#> | CHL_MODEL | chl                   | cmems_mod_glo_bgc_my_0.25deg_P1M-m                |
#> | NPP_MODEL | nppv                  | cmems_mod_glo_bgc_my_0.25deg_P1M-m                |
#> | WSPD      | wind_speed            | cmems_obs-wind_glo_phy_my_l4_P1M                  |
#> | UWND      | eastward_wind         | cmems_obs-wind_glo_phy_my_l4_P1M                  |
#> | VWND      | northward_wind        | cmems_obs-wind_glo_phy_my_l4_P1M                  |
#> | TAUX      | eastward_stress       | cmems_obs-wind_glo_phy_my_l4_P1M                  |
#> | TAUY      | northward_stress      | cmems_obs-wind_glo_phy_my_l4_P1M                  |
#> | TAU       | wind_stress_magnitude | cmems_obs-wind_glo_phy_my_l4_P1M                  |
```
