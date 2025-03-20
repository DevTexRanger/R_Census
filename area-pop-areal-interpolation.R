# **Geospatial Analysis of Hispanic Population Changes (2015-2020)**

## **Overview**
This guide provides a step-by-step breakdown of an R script that analyzes Hispanic population changes in **Shelby County, Alabama**, between **2015 and 2020** using **ACS (American Community Survey) data**. The script applies **area-weighted** and **population-weighted areal interpolation** techniques to estimate population changes and visualizes the results using a **Mapbox-based choropleth map**.

## **1. Load Required Libraries**
The script uses `pacman` to install and load necessary packages.

```r
library(pacman)

p_load(
  geospatial,
  mapboxapi,
  sf,
  tidycensus,
  tidyverse,
  tigris
)
```
- **Key Libraries:**
  - `tidycensus`: Accesses ACS data.
  - `sf`: Handles spatial data.
  - `tigris`: Provides census tract and block geometries.
  - `mapboxapi`: Creates base maps.
  - `tidyverse`: Data manipulation.

## **2. Load ACS Variables for 2015 and 2020**
```r
v15 <- load_variables(2015, "acs5", cache = TRUE) # B03001_003
v20 <- load_variables(2020, "acs5", cache = TRUE) # B03001_003
```
- Loads metadata for **ACS 5-year estimates**.
- `B03001_003` represents the **Hispanic or Latino population**.

## **3. Retrieve Hispanic Population Data**
### **2015 ACS Data**
```r
hisp_15 <- get_acs(
  geography = "tract",
  variables = "B03001_003",
  year = 2015,
  state = "AL",
  county = "Shelby",
  geometry = TRUE
) %>%
  select(estimate) %>%
  st_transform(26949)
```
### **2020 ACS Data**
```r
hisp_20 <- get_acs(
  geography = "tract",
  variables = "B03001_003",
  year = 2020,
  state = "AL",
  county = "Shelby",
  geometry = TRUE
) %>%
  st_transform(26949)
```
- `get_acs()` fetches **tract-level ACS data**.
- `st_transform(26949)` reprojects to **NAD83 / Alabama Central (EPSG: 26949)**.

## **4. Area-Weighted Areal Interpolation**
```r
hisp_interpolate_aw <- st_interpolate_aw(
  hisp_15,
  hisp_20,
  extensive = TRUE
) %>%
  mutate(GEOID = hisp_20$GEOID)
```
- Uses `st_interpolate_aw()` to estimate the **Hispanic population in 2020 census tracts based on 2015 data**.
- **Extensive interpolation** assumes **total population is preserved across spatial units**.

## **5. Population-Weighted Areal Interpolation**
### **Retrieve 2020 Census Blocks**
```r
shelby_blocks <- blocks(
  state = "AL",
  county = "Shelby",
  year = 2020
)
```
### **Interpolate Using Population Weights**
```r
hisp_interpolate_pw <- interpolate_pw(
  hisp_15,
  hisp_20,
  to_id = "GEOID",
  extensive = TRUE,
  weights = shelby_blocks,
  weight_column = "POP20",
  crs = 26949
)
```
- Uses **population-weighted interpolation**, where **census blocks** act as weighting factors.
- `weight_column = "POP20"` ensures weights are based on **2020 population data**.

## **6. Calculate Population Shift**
```r
hisp_shift <- hisp_20 %>%
  left_join(st_drop_geometry(hisp_interpolate_pw),
            by = "GEOID",
            suffix = c("_2020", "_2015")) %>%
  mutate(hisp_shift = estimate_2020 - estimate_2015)
```
- **Joins** the **2020 Hispanic population estimates** with interpolated **2015 estimates**.
- Computes **population shift**:
  \[\text{Hispanic Population in 2020} - \text{Estimated Hispanic Population in 2015}\]

## **7. Map Hispanic Population Shift**
### **Generate a Mapbox Basemap**
```r
shelby_basemap <- layer_static_mapbox(
  location = hisp_shift,
  style_id = "dark-v9",
  username = "mapbox"
)
```
- Uses **Mapbox API** to generate a **dark-themed basemap**.

### **Create the Final Map Using ggplot**
```r
ggplot() +
  shelby_basemap +
  geom_sf(data = hisp_shift, aes(fill = hisp_shift), color = NA,
          alpha = 0.8) +
  scale_fill_distiller(palette = "BuPu", direction = -1) +
  labs(fill = "Shift, 2015 to 2020 ACS",
       title = "Change in Hispanic population",
       subtitle = "Shelby County, Alabama") +
  theme_void()
```
- **Visualizes Hispanic population change per census tract**:
  - `geom_sf(aes(fill = hisp_shift))`: Colors tracts based on Hispanic population change.
  - `scale_fill_distiller(palette = "BuPu", direction = -1)`: Uses a **blue-purple gradient**.
  - `theme_void()`: Removes background elements for clarity.

 ![image](https://github.com/user-attachments/assets/cf4f9aff-b3d1-45f7-b752-1f6e766e7216)


## **Summary**
1. **Retrieve ACS Hispanic population data for 2015 and 2020.**
2. **Use area-weighted and population-weighted interpolation** to estimate Hispanic population in 2020 tracts.
3. **Calculate the shift in Hispanic population between 2015 and 2020.**
4. **Visualize the change using a Mapbox-based choropleth map.**

