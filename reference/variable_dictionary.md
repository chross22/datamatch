# Printable dictionary of variable names

The catalog as a data frame: what each short name means, its units, and
the Copernicus code and dataset behind it. Print it to see what is
available without leaving the console.

## Usage

``` r
variable_dictionary(
  product = c("all", "physical", "biogeochemical", "satellite")
)

# S3 method for class 'datamatch_dictionary'
print(x, ...)
```

## Arguments

- product:

  filter to `"physical"`, `"biogeochemical"`, or `"all"`

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
#>  name      variable label                                   units    
#>  SST       thetao   Sea surface temperature                 degrees C
#>  SSS       so       Sea surface salinity                    PSU      
#>  BOTT      bottomT  Bottom temperature                      degrees C
#>  UO        uo       Eastward current velocity               m/s      
#>  VO        vo       Northward current velocity              m/s      
#>  SSH       zos      Sea surface height                      m        
#>  MLD       mlotst   Mixed layer depth                       m        
#>  SIC       siconc   Sea ice concentration                   fraction 
#>  CHL       CHL      Chlorophyll-a concentration (satellite) mg/m3    
#>  PP        PP       Primary production (satellite)          mg/m2/day
#>  DIATO     DIATO    Diatom chlorophyll-a concentration      mg/m3    
#>  DINO      DINO     Dinophyte chlorophyll-a concentration   mg/m3    
#>  NO3       no3      Nitrate concentration                   mmol/m3  
#>  PO4       po4      Phosphate concentration                 mmol/m3  
#>  O2        o2       Dissolved oxygen                        mmol/m3  
#>  PH        ph       pH                                      unitless 
#>  CHL_MODEL chl      Chlorophyll-a concentration (model)     mg/m3    
#>  NPP_MODEL nppv     Net primary production (model)          mg/m3/day
#> 
#> GLOBAL_MULTIYEAR_PHY_001_030
#>   variables: SST, SSS, BOTT, UO, VO, SSH, MLD, SIC
#>   dataset:   cmems_mod_glo_phy_my_0.083deg_P1M-m
#>   docs:      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 
#> OCEANCOLOUR_GLO_BGC_L4_MY_009_104
#>   variables: CHL, PP, DIATO, DINO
#>   dataset:   cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1Mcmems_obs-oc_glo_bgc-pp_my_l4-multi-4km_P1M
#>   docs:      https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 
#> GLOBAL_MULTIYEAR_BGC_001_029
#>   variables: NO3, PO4, O2, PH, CHL_MODEL, NPP_MODEL
#>   dataset:   cmems_mod_glo_bgc_my_0.25deg_P1M-m
#>   docs:      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 
#> Pass a name to accessEnvDat(vars = ...), or the Copernicus code.
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
#> Pass a name to accessEnvDat(vars = ...), or the Copernicus code.
#> With every variable from one product, product_id and dataset_id can be
#> omitted - they are inferred from the names.
#> Full descriptions: as.data.frame(variable_dictionary())$description

# As a plain data frame, for programmatic use
as.data.frame(variable_dictionary())
#>         name variable                                   label     units
#> 1        SST   thetao                 Sea surface temperature degrees C
#> 2        SSS       so                    Sea surface salinity       PSU
#> 3       BOTT  bottomT                      Bottom temperature degrees C
#> 4         UO       uo               Eastward current velocity       m/s
#> 5         VO       vo              Northward current velocity       m/s
#> 6        SSH      zos                      Sea surface height         m
#> 7        MLD   mlotst                       Mixed layer depth         m
#> 8        SIC   siconc                   Sea ice concentration  fraction
#> 9        CHL      CHL Chlorophyll-a concentration (satellite)     mg/m3
#> 10        PP       PP          Primary production (satellite) mg/m2/day
#> 11     DIATO    DIATO      Diatom chlorophyll-a concentration     mg/m3
#> 12      DINO     DINO   Dinophyte chlorophyll-a concentration     mg/m3
#> 13       NO3      no3                   Nitrate concentration   mmol/m3
#> 14       PO4      po4                 Phosphate concentration   mmol/m3
#> 15        O2       o2                        Dissolved oxygen   mmol/m3
#> 16        PH       ph                                      pH  unitless
#> 17 CHL_MODEL      chl     Chlorophyll-a concentration (model)     mg/m3
#> 18 NPP_MODEL     nppv          Net primary production (model) mg/m3/day
#>                              product
#> 1       GLOBAL_MULTIYEAR_PHY_001_030
#> 2       GLOBAL_MULTIYEAR_PHY_001_030
#> 3       GLOBAL_MULTIYEAR_PHY_001_030
#> 4       GLOBAL_MULTIYEAR_PHY_001_030
#> 5       GLOBAL_MULTIYEAR_PHY_001_030
#> 6       GLOBAL_MULTIYEAR_PHY_001_030
#> 7       GLOBAL_MULTIYEAR_PHY_001_030
#> 8       GLOBAL_MULTIYEAR_PHY_001_030
#> 9  OCEANCOLOUR_GLO_BGC_L4_MY_009_104
#> 10 OCEANCOLOUR_GLO_BGC_L4_MY_009_104
#> 11 OCEANCOLOUR_GLO_BGC_L4_MY_009_104
#> 12 OCEANCOLOUR_GLO_BGC_L4_MY_009_104
#> 13      GLOBAL_MULTIYEAR_BGC_001_029
#> 14      GLOBAL_MULTIYEAR_BGC_001_029
#> 15      GLOBAL_MULTIYEAR_BGC_001_029
#> 16      GLOBAL_MULTIYEAR_BGC_001_029
#> 17      GLOBAL_MULTIYEAR_BGC_001_029
#> 18      GLOBAL_MULTIYEAR_BGC_001_029
#>                                              dataset
#> 1                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 2                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 3                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 4                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 5                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 6                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 7                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 8                cmems_mod_glo_phy_my_0.083deg_P1M-m
#> 9  cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M
#> 10       cmems_obs-oc_glo_bgc-pp_my_l4-multi-4km_P1M
#> 11 cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M
#> 12 cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M
#> 13                cmems_mod_glo_bgc_my_0.25deg_P1M-m
#> 14                cmems_mod_glo_bgc_my_0.25deg_P1M-m
#> 15                cmems_mod_glo_bgc_my_0.25deg_P1M-m
#> 16                cmems_mod_glo_bgc_my_0.25deg_P1M-m
#> 17                cmems_mod_glo_bgc_my_0.25deg_P1M-m
#> 18                cmems_mod_glo_bgc_my_0.25deg_P1M-m
#>                                                                                        url
#> 1       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 2       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 3       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 4       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 5       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 6       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 7       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 8       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 9  https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 10 https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 11 https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 12 https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 13      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 14      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 15      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 16      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 17      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 18      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#>                                                                                                                                                                                                                             description
#> 1                                                                                                                                                                                       Sea water potential temperature at the surface.
#> 2                                                                                                                                                                                                    Sea water salinity at the surface.
#> 3                                                                                                                                           Sea water potential temperature at the sea floor. Relevant to overwintering copepod stages.
#> 4                                                                                                                                                                                             Eastward component of sea water velocity.
#> 5                                                                                                                                                                                            Northward component of sea water velocity.
#> 6                                                                                                                                                           Sea surface height above geoid. A proxy for mesoscale circulation features.
#> 7                                                                                                                                       Ocean mixed layer thickness by a sigma-theta criterion. Controls how deeply plankton are mixed.
#> 8                                                                                                                                                                                              Fraction of the cell covered by sea ice.
#> 9  Mass concentration of chlorophyll-a from Copernicus-GlobColour. A food-availability proxy; usually worth log-transforming. Surface only, and gappy under persistent cloud - though the daily field is the gap-free interpolated one.
#> 10         Primary productivity of biomass expressed as carbon, from Copernicus-GlobColour. A rate rather than the standing stock chlorophyll reports. Note the areal units: this is depth-integrated, unlike the volumetric model NPP.
#> 11                                                          Mass concentration of diatoms expressed as chlorophyll in sea water. Large, fast-growing cells that dominate the spring bloom and are the preferred prey of large copepods.
#> 12                                                 Mass concentration of dinophytes (dinoflagellates) expressed as chlorophyll in sea water. Typically later in the season than diatoms and favoured by stratified, low-nutrient water.
#> 13                                                                                                                                                                                  Mole concentration of nitrate, a limiting nutrient.
#> 14                                                                                                                                                                                                     Mole concentration of phosphate.
#> 15                                                                                                                                                                                    Mole concentration of dissolved molecular oxygen.
#> 16                                                                                    Sea water pH on the total scale. A logarithmic ratio, so it has no units - and for the same reason should not be averaged directly. Monthly only.
#> 17                                                                                   Chlorophyll-a from the biogeochemistry reanalysis. Coarser than the satellite CHL but gap-free, so preferable where cloud cover would leave holes.
#> 18                                                                                Net primary production from the biogeochemistry reanalysis. Volumetric, unlike the depth-integrated satellite PP, so the two are not interchangeable.

# The product page for a variable, to check its coverage and revisions
as.data.frame(variable_dictionary())[c("name", "url")]
#>         name
#> 1        SST
#> 2        SSS
#> 3       BOTT
#> 4         UO
#> 5         VO
#> 6        SSH
#> 7        MLD
#> 8        SIC
#> 9        CHL
#> 10        PP
#> 11     DIATO
#> 12      DINO
#> 13       NO3
#> 14       PO4
#> 15        O2
#> 16        PH
#> 17 CHL_MODEL
#> 18 NPP_MODEL
#>                                                                                        url
#> 1       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 2       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 3       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 4       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 5       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 6       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 7       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 8       https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/description
#> 9  https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 10 https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 11 https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 12 https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/description
#> 13      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 14      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 15      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 16      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 17      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
#> 18      https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_BGC_001_029/description
```
