
# Obtain median household income for specific TX counties using the 5YR ACS across multiple years using RStudio 

# Load pacman; if not already installed, I highly encourage you to do so-especially if you're working with a lot of packages!
library("pacman")

# Load libraries using p_load
p_load(dplyr, ggplot2, scales, tidyverse, tidycensus)

# Census Data API Key (enter your Census Data API Key between the parentheses)
census_api_key("ENTER_YOUR_CENSUS_API_KEY_HERE")

yrs <- 2011:2023
table_name <- "B19013A_001"

# Load variables for each year and check for the specific table
table_check <- sapply(yrs, function(year) {
  vars <- load_variables(year, "acs5", cache = TRUE)
  table_name %in% vars$variable
})

# Create a data frame to summarize the results
table_check_df <- data.frame(
  year = yrs,
  table_exists = table_check
)

# Print the results
print(table_check_df)

# Check if the table is present in all years
if (all(table_check)) {
  print(paste("The table", table_name, "is present in all years from 2011 to 2023."))
} else {
  print(paste("The table", table_name, "is not present in all years from 2011 to 2023."))
}

# Load variables for the latest "acs5"
v23 <- load_variables(2023, "acs5", cache = TRUE)

# Obtain table name for median household income using the View(v23) command by using the 
View(v23)

# Create a variable name (medianhh) using the assignment operator in R, using a named vector with one element (tablename)
medHHIncTX <- c(estimate = "B19013A_001")

# Specify the counties as the vector 'my counties'
my_counties <- c("Jones",
                 "Taylor")

# Specify the years as a list using the 'lst' from tidyverse
years <- lst(2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023)

# Request data for 2023 on the median household income for all TX counties
texas_income <- map_dfr(
  years,
  ~ get_acs(
    geography = "county",
    variables = medHHIncTX,
    state = "TX",
    county = my_counties,
    year = .x,
    survey = "acs5",
    geometry = FALSE,
    output = "wide"
  ),
  .id = "year"
)

# Rename the columns
texas_income <- texas_income %>%
  rename(
    county = NAME,
    estimate = estimateE,
    MOE = estimateM
  )

# We now need to visualize the margins of error to understand the uncertainty around these estimates. Because TX is such a huge state, filter the data to include only the top 10 and bottom 10 counties based on the median household income before plotting it.
top_bottom_20 <- texas_income %>%
  arrange(desc(estimate)) %>%
  slice(c(1:10, (n() - 9):n()))

# Check the lengths of the vectors
length(top_bottom_20$estimate)
length(top_bottom_20$county)

# Display the first few rows of the data frame to ensure it looks correct
head(top_bottom_20)

# Assuming your data frame is named 'top_bottom_20'
top_bottom_20_clean <- top_bottom_20 %>%
  distinct(year, county, .keep_all = TRUE)

# Plot the data
ggplot(top_bottom_20, aes(x = estimate, y = reorder(county, estimate))) + 
  geom_point(aes(color = as.factor(year)), size = 3) + 
  theme_minimal(base_size = 12.5) + 
  labs(title = "Median household income", 
       subtitle = "Counties in Texas", 
       x = "2018-2022 ACS estimate", 
       y = "", 
       color = "Year") + 
  scale_x_continuous(labels = label_dollar())

# Arrange in descending order by margin of error
# For counties with smaller population sizes, estimates are likely to have a larger margin of error compared to those with larger baseline populations.
texas_income %>% 
  arrange(desc(MOE))

# The margins of error for estimated median household incomes range from $1,464 in Denton County to $46,346 in Glasscock County.
# In many instances, these margins of error are larger than the income differences between counties with adjacent rankings, indicating uncertainty in the rankings.
# Here, we use horizontal error bars to help us understand how our ranking of Texas counties by median household income and the uncertainty associated with these estimates. 

ggplot(top_bottom_20, aes(x = estimate, y = reorder(county, estimate))) + 
  geom_errorbarh(aes(xmin = estimate - MOE, xmax = estimate + MOE, color = as.factor(year))) + 
  geom_point(aes(color = as.factor(year)), size = 3) + 
  theme_minimal(base_size = 12.5) + 
  labs(title = "Median household income", 
       subtitle = "Counties in Texas", 
       x = "2011-2022 ACS 5YR Estimate", 
       y = "", 
       color = "Year") + 
  scale_x_continuous(labels = label_dollar())

# Save the output 'df' as a CSV file; if on Windows, remember to use double backslashes (\\) as a directory separator in file paths 
write.csv(texas_income, "...\\texasincome.csv")
