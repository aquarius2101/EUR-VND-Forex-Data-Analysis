library(readr)
library(dplyr)
library(tidyr)
library(here)
library(tsibble)

eur <- read.csv(here("data", "EUR_VND.csv"))

# Remove "Vol." column
eur <- eur %>% select(-Vol.)

# Remove the comma in numbers
eur <- eur %>% mutate(across(where(is.character), ~ gsub(",", "", .x)))

# Change "Change" data type into number
eur <- eur %>% mutate(Change = as.numeric(gsub("%", "", Change..)))
eur <- eur %>% select(-Change..)

# Change type of Date column to Date
eur <- eur %>% mutate(Date = as.Date(as.character(Date), format = "%m/%d/%Y"))

# Turn Date into time series
ts_eur <- as_tsibble(eur, index = Date)

# Add time index and lag variables
ts_eur <- ts_eur %>%
  arrange(Date) %>%
  mutate(
    TimeIndex = 1:n(),
    Price_lag1 = lag(Price),
    Price_lag2 = lag(Price, 2)
  )
ts_eur <- ts_eur |> drop_na()

# Save to a new CSV
write_csv(ts_eur, here("data", "clean_data.csv"))
