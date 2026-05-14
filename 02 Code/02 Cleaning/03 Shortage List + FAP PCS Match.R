# This code: constructs the treated occupation table, maps pcs, quick descriptives.

### Part 0: Set-Up ----

rm(list=ls())

library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(stringi)
library(readODS)
library(xtable)
library(ggplot2)
library(tibble)

raw_df <- read_csv("C:/Users/Public/Documents/Charagnoli/01 Intermediate Data/Treatment/shortage_list.csv")
table_pcs <- read_ods("C:/Users/Public/Documents/Charagnoli/01 Intermediate Data/Treatment/Table_passage_FAP_PCS-ESE.ods")

### Step 1: General FAP to PCS mapping ----

table_pcs <- table_pcs |>
  slice(-1) |>
  rename(fap_code = 1, fap_label = 2, pcs_code = 3, pcs_label = 4) |>
  filter(!if_all(everything(), ~ is.na(.) | str_trim(.) == "" )) |>
  filter(is.na(fap_code) | str_trim(fap_code) == "" | str_detect(fap_code, "^[A-Za-z][0-9][A-Za-z][0-9][0-9]$")) |>
  mutate(fap_code = na_if(str_trim(fap_code), ""),
         fap_code = if_else(str_detect(replace_na(fap_code, ""), "^[A-Za-z][0-9][A-Za-z][0-9][0-9]$") | is.na(fap_code),
                            fap_code,NA_character_)) |>
  mutate(pcs_code = str_to_upper(pcs_code)) |>
  fill(fap_code, fap_label, .direction = "down")

write_excel_csv(table_pcs, "C:/Users/Public/Documents/Charagnoli/01 Intermediate Data/fap_to_pcs.csv")

### Step 2: Check if we have same PCS codes ----

mismatch <- raw_df |> left_join(table_pcs, by = "pcs_code") |> filter(fap_code.x != fap_code.y)
raw_df <- raw_df  |> distinct(pcs_code) 
table_pcs <-table_pcs  |> distinct(pcs_code)
missing <- setdiff(raw_df$pcs_code, table_pcs$pcs_code)

write_excel_csv(raw_df, "C:/Users/Public/Documents/Charagnoli/01 Intermediate Data/shortage_list.csv")









