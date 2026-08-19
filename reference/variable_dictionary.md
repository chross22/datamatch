# Printable dictionary of variable names

The catalog as a data frame: what each short name means, its units, and
the Copernicus code and dataset behind it. Print it to see what is
available without leaving the console.

## Usage

``` r
variable_dictionary(
  product = c("all", "physical", "biogeochemical", "satellite", "wind")
)

# S3 method for class 'datamatch_dictionary'
print(x, ...)
```

## Arguments

- product:

  filter to `"physical"`, `"biogeochemical"`, `"satellite"`, `"wind"`,
  or `"all"`

- x:

  a `datamatch_dictionary`

- ...:

  ignored

## Value

a data frame of class `datamatch_dictionary` with columns `name`,
`variable`, `label`, `units`, `product`, `dataset`, `url`, and
`description`

## Examples

``` r
variable_dictionary()
#> Copernicus variables available by name
#> ------------------------------------------------------------------
#>  name      variable              label                                  
#>  SST       thetao                Sea surface temperature                
#>  SSS       so                    Sea surface salinity                   
#>  BOTT      bottomT               Bottom temperature                     
#>  BOTS      so                    Bottom salinity                        
#>  UO        uo                    Eastward current velocity              
#>  VO        vo                    Northward current velocity             
#>  SSH       zos                   Sea surface height                     
#>  MLD       mlotst                Mixed layer depth                      
#>  SIC       siconc                Sea ice concentration                  
#>  CHL       CHL                   Chlorophyll-a concentration (satellite)
#>  PP        PP                    Primary production (satellite)         
#>  DIATO     DIATO                 Diatom chlorophyll-a concentration     
#>  DINO      DINO                  Dinophyte chlorophyll-a concentration  
#>  NO3       no3                   Nitrate concentration                  
#>  PO4       po4                   Phosphate concentration                
#>  O2        o2                    Dissolved oxygen                       
#>  PH        ph                    pH                                     
#>  CHL_MODEL chl                   Chlorophyll-a concentration (model)    
#>  NPP_MODEL nppv                  Net primary production (model)         
#>  WSPD      wind_speed            Wind speed                             
#>  UWND      eastward_wind         Eastward wind                          
#>  VWND      northward_wind        Northward wind                         
#>  TAUX      eastward_stress       Eastward wind stress                   
#>  TAUY      northward_stress      Northward wind stress                  
#>  TAU       wind_stress_magnitude Wind stress magnitude                  
#>  units    
#>  degrees C
#>  PSU      
#>  degrees C
#>  PSU      
#>  m/s      
#>  m/s      
#>  m        
#>  m        
#>  fraction 
#>  mg/m3    
#>  mg/m2/day
#>  mg/m3    
#>  mg/m3    
#>  mmol/m3  
#>  mmol/m3  
#>  mmol/m3  
#>  unitless 
#>  mg/m3    
#>  mg/m3/day
#>  m/s      
#>  m/s      
#>  m/s      
#>  N/m2     
#>  N/m2     
#>  N/m2     
#> 
#> GLOBAL_MULTIYEAR_PHY_001_030
#>   variables: SST, SSS, BOTT, BOTS, UO, VO, SSH, MLD, SIC
#>   dataset:   cmems_mod_glo_phy_my_0.083deg_P1M-m
#>   docs:      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 
#> OCEANCOLOUR_GLO_BGC_L4_MY_009_104
#>   variables: CHL, PP, DIATO, DINO
#>   dataset:   cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M
#>              cmems_obs-oc_glo_bgc-pp_my_l4-multi-4km_P1M
#>   docs:      https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 
#> GLOBAL_MULTIYEAR_BGC_001_029
#>   variables: NO3, PO4, O2, PH, CHL_MODEL, NPP_MODEL
#>   dataset:   cmems_mod_glo_bgc_my_0.25deg_P1M-m
#>   docs:      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 
#> WIND_GLO_PHY_CLIMATE_L4_MY_012_003
#>   variables: WSPD, UWND, VWND, TAUX, TAUY, TAU
#>   dataset:   cmems_obs-wind_glo_phy_my_l4_P1M
#>   docs:      https://data.marine.copernicus.eu/product/WIND_GLO_PHY_CLIMATE_L4_MY_012_003/description
#> 
#> Pass a name to accessCopernicus(vars = ...), or the Copernicus code.
#> With every variable from one product, product_id and dataset_id can be
#> omitted - they are inferred from the names.
#> Full descriptions: as.data.frame(variable_dictionary())$description
variable_dictionary("biogeochemical")
#> Copernicus variables available by name
#> ------------------------------------------------------------------
#>  name      variable label                               units    
#>  NO3       no3      Nitrate concentration               mmol/m3  
#>  PO4       po4      Phosphate concentration             mmol/m3  
#>  O2        o2       Dissolved oxygen                    mmol/m3  
#>  PH        ph       pH                                  unitless 
#>  CHL_MODEL chl      Chlorophyll-a concentration (model) mg/m3    
#>  NPP_MODEL nppv     Net primary production (model)      mg/m3/day
#> 
#> GLOBAL_MULTIYEAR_BGC_001_029
#>   variables: NO3, PO4, O2, PH, CHL_MODEL, NPP_MODEL
#>   dataset:   cmems_mod_glo_bgc_my_0.25deg_P1M-m
#>   docs:      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 
#> Pass a name to accessCopernicus(vars = ...), or the Copernicus code.
#> With every variable from one product, product_id and dataset_id can be
#> omitted - they are inferred from the names.
#> Full descriptions: as.data.frame(variable_dictionary())$description
variable_dictionary("wind")
#> Copernicus variables available by name
#> ------------------------------------------------------------------
#>  name variable              label                 units
#>  WSPD wind_speed            Wind speed            m/s  
#>  UWND eastward_wind         Eastward wind         m/s  
#>  VWND northward_wind        Northward wind        m/s  
#>  TAUX eastward_stress       Eastward wind stress  N/m2 
#>  TAUY northward_stress      Northward wind stress N/m2 
#>  TAU  wind_stress_magnitude Wind stress magnitude N/m2 
#> 
#> WIND_GLO_PHY_CLIMATE_L4_MY_012_003
#>   variables: WSPD, UWND, VWND, TAUX, TAUY, TAU
#>   dataset:   cmems_obs-wind_glo_phy_my_l4_P1M
#>   docs:      https://data.marine.copernicus.eu/product/WIND_GLO_PHY_CLIMATE_L4_MY_012_003/description
#> 
#> Pass a name to accessCopernicus(vars = ...), or the Copernicus code.
#> With every variable from one product, product_id and dataset_id can be
#> omitted - they are inferred from the names.
#> Full descriptions: as.data.frame(variable_dictionary())$description

# As a plain data frame, for programmatic use
as.data.frame(variable_dictionary())
#>         name              variable                                   label
#> 1        SST                thetao                 Sea surface temperature
#> 2        SSS                    so                    Sea surface salinity
#> 3       BOTT               bottomT                      Bottom temperature
#> 4       BOTS                    so                         Bottom salinity
#> 5         UO                    uo               Eastward current velocity
#> 6         VO                    vo              Northward current velocity
#> 7        SSH                   zos                      Sea surface height
#> 8        MLD                mlotst                       Mixed layer depth
#> 9        SIC                siconc                   Sea ice concentration
#> 10       CHL                   CHL Chlorophyll-a concentration (satellite)
#> 11        PP                    PP          Primary production (satellite)
#> 12     DIATO                 DIATO      Diatom chlorophyll-a concentration
#> 13      DINO                  DINO   Dinophyte chlorophyll-a concentration
#> 14       NO3                   no3                   Nitrate concentration
#> 15       PO4                   po4                 Phosphate concentration
#> 16        O2                    o2                        Dissolved oxygen
#> 17        PH                    ph                                      pH
#> 18 CHL_MODEL                   chl     Chlorophyll-a concentration (model)
#> 19 NPP_MODEL                  nppv          Net primary production (model)
#> 20      WSPD            wind_speed                              Wind speed
#> 21      UWND         eastward_wind                           Eastward wind
#> 22      VWND        northward_wind                          Northward wind
#> 23      TAUX       eastward_stress                    Eastward wind stress
#> 24      TAUY      northward_stress                   Northward wind stress
#> 25       TAU wind_stress_magnitude                   Wind stress magnitude
#>        units                            product
#> 1  degrees C       GLOBAL_MULTIYEAR_PHY_001_030
#> 2        PSU       GLOBAL_MULTIYEAR_PHY_001_030
#> 3  degrees C       GLOBAL_MULTIYEAR_PHY_001_030
#> 4        PSU       GLOBAL_MULTIYEAR_PHY_001_030
#> 5        m/s       GLOBAL_MULTIYEAR_PHY_001_030
#> 6        m/s       GLOBAL_MULTIYEAR_PHY_001_030
#> 7          m       GLOBAL_MULTIYEAR_PHY_001_030
#> 8          m       GLOBAL_MULTIYEAR_PHY_001_030
#> 9   fraction       GLOBAL_MULTIYEAR_PHY_001_030
#> 10     mg/m3  OCEANCOLOUR_GLO_BGC_L4_MY_009_104
#> 11 mg/m2/day  OCEANCOLOUR_GLO_BGC_L4_MY_009_104
#> 12     mg/m3  OCEANCOLOUR_GLO_BGC_L4_MY_009_104
#> 13     mg/m3  OCEANCOLOUR_GLO_BGC_L4_MY_009_104
#> 14   mmol/m3       GLOBAL_MULTIYEAR_BGC_001_029
#> 15   mmol/m3       GLOBAL_MULTIYEAR_BGC_001_029
#> 16   mmol/m3       GLOBAL_MULTIYEAR_BGC_001_029
#> 17  unitless       GLOBAL_MULTIYEAR_BGC_001_029
#> 18     mg/m3       GLOBAL_MULTIYEAR_BGC_001_029
#> 19 mg/m3/day       GLOBAL_MULTIYEAR_BGC_001_029
#> 20       m/s WIND_GLO_PHY_CLIMATE_L4_MY_012_003
#> 21       m/s WIND_GLO_PHY_CLIMATE_L4_MY_012_003
#> 22       m/s WIND_GLO_PHY_CLIMATE_L4_MY_012_003
#> 23      N/m2 WIND_GLO_PHY_CLIMATE_L4_MY_012_003
#> 24      N/m2 WIND_GLO_PHY_CLIMATE_L4_MY_012_003
#> 25      N/m2 WIND_GLO_PHY_CLIMATE_L4_MY_012_003
#>                                              dataset
#> 1                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 2                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 3                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 4                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 5                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 6                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 7                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 8                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 9                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 10 cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M
#> 11       cmems_obs-oc_glo_bgc-pp_my_l4-multi-4km_P1M
#> 12 cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M
#> 13 cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M
#> 14                cmems_mod_glo_bgc_my_0.25deg_P1M-m
#> 15                cmems_mod_glo_bgc_my_0.25deg_P1M-m
#> 16                cmems_mod_glo_bgc_my_0.25deg_P1M-m
#> 17                cmems_mod_glo_bgc_my_0.25deg_P1M-m
#> 18                cmems_mod_glo_bgc_my_0.25deg_P1M-m
#> 19                cmems_mod_glo_bgc_my_0.25deg_P1M-m
#> 20                  cmems_obs-wind_glo_phy_my_l4_P1M
#> 21                  cmems_obs-wind_glo_phy_my_l4_P1M
#> 22                  cmems_obs-wind_glo_phy_my_l4_P1M
#> 23                  cmems_obs-wind_glo_phy_my_l4_P1M
#> 24                  cmems_obs-wind_glo_phy_my_l4_P1M
#> 25                  cmems_obs-wind_glo_phy_my_l4_P1M
#>                                                                                         url
#> 1        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 2        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 3        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 4        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 5        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 6        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 7        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 8        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 9        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 10  https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 11  https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 12  https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 13  https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 14       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 15       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 16       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 17       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 18       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 19       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 20 https://data.marine.copernicus.eu/product/WIND_GLO_PHY_CLIMATE_L4_MY_012_003/description
#> 21 https://data.marine.copernicus.eu/product/WIND_GLO_PHY_CLIMATE_L4_MY_012_003/description
#> 22 https://data.marine.copernicus.eu/product/WIND_GLO_PHY_CLIMATE_L4_MY_012_003/description
#> 23 https://data.marine.copernicus.eu/product/WIND_GLO_PHY_CLIMATE_L4_MY_012_003/description
#> 24 https://data.marine.copernicus.eu/product/WIND_GLO_PHY_CLIMATE_L4_MY_012_003/description
#> 25 https://data.marine.copernicus.eu/product/WIND_GLO_PHY_CLIMATE_L4_MY_012_003/description
#>                                                                                                                                                                                                                                                                                         description
#> 1                                                                                                                                                                                                                                                   Sea water potential temperature at the surface.
#> 2                                                                                                                                                                                                                                                                Sea water salinity at the surface.
#> 3                                                                                                                                                                                                       Sea water potential temperature at the sea floor. Relevant to overwintering copepod stages.
#> 4  Sea water salinity in the deepest wet model level of each cell. Derived from the three-dimensional salinity field in the reanalysis, where Copernicus publishes no sea-floor salinity variable; taken directly from `sob` in forecast mode. Pairs with BOTT for water-mass work near the bottom.
#> 5                                                                                                                                                                                                                                                         Eastward component of sea water velocity.
#> 6                                                                                                                                                                                                                                                        Northward component of sea water velocity.
#> 7                                                                                                                                                                                                                       Sea surface height above geoid. A proxy for mesoscale circulation features.
#> 8                                                                                                                                                                                                   Ocean mixed layer thickness by a sigma-theta criterion. Controls how deeply plankton are mixed.
#> 9                                                                                                                                                                                                                                                          Fraction of the cell covered by sea ice.
#> 10                                                             Mass concentration of chlorophyll-a from Copernicus-GlobColour. A food-availability proxy; usually worth log-transforming. Surface only, and gappy under persistent cloud - though the daily field is the gap-free interpolated one.
#> 11                                                                     Primary productivity of biomass expressed as carbon, from Copernicus-GlobColour. A rate rather than the standing stock chlorophyll reports. Note the areal units: this is depth-integrated, unlike the volumetric model NPP.
#> 12                                                                                                                      Mass concentration of diatoms expressed as chlorophyll in sea water. Large, fast-growing cells that dominate the spring bloom and are the preferred prey of large copepods.
#> 13                                                                                                             Mass concentration of dinophytes (dinoflagellates) expressed as chlorophyll in sea water. Typically later in the season than diatoms and favoured by stratified, low-nutrient water.
#> 14                                                                                                                                                                                                                                              Mole concentration of nitrate, a limiting nutrient.
#> 15                                                                                                                                                                                                                                                                 Mole concentration of phosphate.
#> 16                                                                                                                                                                                                                                                Mole concentration of dissolved molecular oxygen.
#> 17                                                                                                                                                Sea water pH on the total scale. A logarithmic ratio, so it has no units - and for the same reason should not be averaged directly. Monthly only.
#> 18                                                                                                                                               Chlorophyll-a from the biogeochemistry reanalysis. Coarser than the satellite CHL but gap-free, so preferable where cloud cover would leave holes.
#> 19                                                                                                                                            Net primary production from the biogeochemistry reanalysis. Volumetric, unlike the depth-integrated satellite PP, so the two are not interchangeable.
#> 20                                                                                   Scalar wind speed at 10 m. Averaged as a speed rather than derived from the mean components, so it exceeds the magnitude of the mean wind vector wherever the direction varied within the month. Monthly only.
#> 21                                                                                                                                                                                                                                                     Eastward component of wind velocity at 10 m.
#> 22                                                                                                                                                                                                                                                    Northward component of wind velocity at 10 m.
#> 23                                                                                                                                                           Eastward component of the surface downward stress. The momentum actually entering the ocean, which is roughly quadratic in wind speed.
#> 24                                                                                                                                                                                                                                              Northward component of the surface downward stress.
#> 25                                                                                                                                                                                      Magnitude of the surface downward stress. Drives mixing and, through its curl, Ekman pumping. Monthly only.

# The product page for a variable, to check its coverage and revisions
as.data.frame(variable_dictionary())[c("name", "url")]
#>         name
#> 1        SST
#> 2        SSS
#> 3       BOTT
#> 4       BOTS
#> 5         UO
#> 6         VO
#> 7        SSH
#> 8        MLD
#> 9        SIC
#> 10       CHL
#> 11        PP
#> 12     DIATO
#> 13      DINO
#> 14       NO3
#> 15       PO4
#> 16        O2
#> 17        PH
#> 18 CHL_MODEL
#> 19 NPP_MODEL
#> 20      WSPD
#> 21      UWND
#> 22      VWND
#> 23      TAUX
#> 24      TAUY
#> 25       TAU
#>                                                                                         url
#> 1        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 2        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 3        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 4        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 5        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 6        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 7        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 8        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 9        https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 10  https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 11  https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 12  https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 13  https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 14       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 15       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 16       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 17       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 18       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 19       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 20 https://data.marine.copernicus.eu/product/WIND_GLO_PHY_CLIMATE_L4_MY_012_003/description
#> 21 https://data.marine.copernicus.eu/product/WIND_GLO_PHY_CLIMATE_L4_MY_012_003/description
#> 22 https://data.marine.copernicus.eu/product/WIND_GLO_PHY_CLIMATE_L4_MY_012_003/description
#> 23 https://data.marine.copernicus.eu/product/WIND_GLO_PHY_CLIMATE_L4_MY_012_003/description
#> 24 https://data.marine.copernicus.eu/product/WIND_GLO_PHY_CLIMATE_L4_MY_012_003/description
#> 25 https://data.marine.copernicus.eu/product/WIND_GLO_PHY_CLIMATE_L4_MY_012_003/description
```
