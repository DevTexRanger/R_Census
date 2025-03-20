# Constructing a Demographic Multi-Dimensional Contingency Table with PUMS Data and `pivot_wider`

In this exercise, we’ll create a demographic multi-dimensional contingency table, a key component of a contract I managed that involved developing regional household distribution tables for Metropolitan Planning Organizations (MPOs) in Texas. This table aggregates key demographic indicators—income groups, household sizes (1-person to 5+ person households), and the number of workers per household (0 to 2+)—using Public Use Microdata Sample (PUMS) data for Bexar County, TX. The resulting table serves as input for travel demand models, with a base year of 2017.

This method involves manually downloading person-level and household-level PUMS files from the Census Bureau's FTP server and merging them. For an updated approach using the `tidycensus` package, refer to [this method](https://github.com/DevTexRanger/pums-contingency-table/blob/main/README.md).

> **Note:** The income categories in this example are for demonstration only. In practice, they are often derived from household surveys conducted by the governing agency. Additionally, adjustments based on the Consumer Price Index for All Urban Consumers (CPI-U) may be necessary, but they have not been applied here.


setwd("...")

# Verify working directory
getwd()


# Load library
library(pacman)

# Install & load packages
p_load(
  car,
  dplyr,
  matrixStats,
  questionr,
  stringr,
  tidycensus,
  tidyverse,
  tidyr
)

# Load household data 2017 5-year ACS PUMS
pums_h <-
  read.csv("...\\psam_h48.csv")

# Load person data 2017 5-year ACS PUMS
pums_p <-
  read.csv("...\\psam_p48.csv")

# Merge household and person PUMS data
pums_BY <-
  inner_join(pums_h,
    pums_p,
    by = c("SERIALNO", "DIVISION", "PUMA", "REGION", "ST", "ADJINC")
  )

# Set variables of interest to include
pums_BY_var <-
  pums_BY %>% select(
    SERIALNO,
    AGEP,
    PWGTP,
    RELSHIPP,
    SCH,
    SCHG,
    ST,
    PUMA,
    WAGP,
    WKL,
    ESR,
    ADJINC,
    BLD,
    HHT,
    HINCP,
    NP,
    WIF,
    NR,
    TEN,
    TYPEHUGQ,
    WGTP
  )

# Filter observations to VIC == 485600 (Victoria County; partial—exclude the state code '48')
pumas <- pums_BY_var %>% filter(PUMA == 5600)

# Generate county variable to associate the requisite PUMA(s) with the county
pumas$county <-
  Recode(pumas$PUMA, recodes = "5600='Victoria'; else = NA")

# Convert SERIALNO into string
pumas$SERIALNO <- as.character(pumas$SERIALNO)

str(pumas)

# Replace NAs
pumas[is.na(pumas)] <- 0

# Remove negative
pumas$HINCP[pumas$HINCP < 0] <- 0

# Standardize HHincome dollars to 2017 dollars
pumas$hinc_BY <- pumas$HINCP * (1071818 / 1000000)

# Compare summary of old and new variable

with(pumas, summary(HINCP))

with(pumas, summary(hinc_BY))

# Generate grouped a grouped income variable
pumas$incgrp <-
  Recode(
    pumas$hinc_BY,
    recodes = "0:22481='$0 - $22,841'; 22842:44963='$22,842 - $44,963'; 44964:67446='$44,964 - $67,446'; 67447:112410='$67,447 - $112,410'; 112411:xxx='$112,411+'; else = NA",
    as.factor = T,
    levels = c(
      "$0 - $22,841",
      "$22,842 - $44,963",
      "$44,964 - $67,446",
      "$67,447 - $112,410",
      "$112,411+"
    )
  )

# Double check number of people in household
pumas %>%
  group_by(SERIALNO) %>%
  mutate(HHSIZE1 = str_count(SERIALNO)) -> pumas

na.omit(pumas)

# Generate a grouped household size variable and Generate a variable representing number of workers in the household (worker)
pumas$hhsize <-
  Recode(pumas$NP, recodes = "1=1; 2=2; 3=3; 4=4; 5:20='5+'; else=NA", as.factor = T)

# Create a flag variable to identify workers in the household
pumas$worker <-
  factor(ifelse(pumas$ESR == 1,
    "1",
    ifelse(pumas$ESR == 2,
      "1", NA
    )
  ))

# Create a flag to identify workers in the household
pumas %>%
  group_by(SERIALNO) %>%
  mutate(wihh = sum(worker == 1, na.rm = TRUE)) -> pumas

# Generate a grouped number of workers in the household variable
pumas$hhworker <-
  factor(ifelse(pumas$wihh == 0,
    "0",
    ifelse(
      pumas$wihh == 1,
      "1",
      ifelse(pumas$wihh >= 2, "2+", NA)
    )
  ))

# Generate a variable to distinguish different types of households
pumas$hhtype <-
  factor(ifelse(pumas$WGTP != 0,
    "1",
    ifelse(pumas$WGTP != 2,
      "2", NA
    )
  ))

# Generate a flag variable which identifies householders
pumas$hholder <- factor(ifelse(pumas$RELSHIPP == 20 ,"1",NA))  

pumas$hholder <-  
  Recode(pumas$RELSHIPP,
    recodes = "20=1; else = 0", as.factor = T)  

# Outputs
write.csv(
  pumas,
  "...\\Output.csv"
)

# All households, if hholder == 1
hhinc_all <-
  pumas %>%
  filter(hholder == 1) %>%
  group_by(county, incgrp, hhsize, hhworker) %>%
  dplyr::count(hhworker, wt = WGTP, na.rm = TRUE)

write.csv(
  hhinc_all,
  "...\\VICFreq.csv"
)

# 3-way table
HHInc_3way <- pivot_wider(
  hhinc_all,
  id_cols = c(county, incgrp),
  values_fill = 0,
  names_from = c(hhworker, hhsize),
  values_from = n
)

write.csv(
  HHInc_3way,
  "...\\VIC3way.csv"
)

# totpop_by_type
totpop <-
  pumas %>%
  filter(hholder == 1) %>%
  group_by(SERIALNO, hhtype) %>%
  summarise(hhtype, wt = WGTP, na.rm = TRUE)

write.csv(
  totpop,
  "...\\totpop_by_type.csv"
)

## Median household income by household type
medhh_bytype <-
  pumas %>%
  filter(hholder == 1) %>%
  group_by(hhtype) %>%
  summarise(wtd_median = weightedMedian(hinc_BY, w = WGTP, na.rm = TRUE))

write.csv(
  medhh_bytype,
  "...\\medhh_bytype.csv"
)
