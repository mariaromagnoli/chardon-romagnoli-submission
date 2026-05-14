# This code: robustness, compositional change.

### PART 0: Set-up -------------


rm(list=ls())

library(readr)
library(duckdb)
library(dbplyr)
library(dplyr)
library(tidyr)
library(lubridate)

library(fixest)
library(ggplot2)
library(tibble)
library(duckdb)

library(ggplot2)
library(patchwork)
library(scales)
library(purrr)
library(glue)
library(gt)
library(broom)
library(stringr)
library(car)


con <- dbConnect(duckdb())

query_fh <- "CREATE VIEW fh AS SELECT * FROM read_parquet('C:/Users/Public/Documents/Charagnoli/02 Final Data/fh_latest.parquet')"
dbExecute(con, query_fh)
dbGetQuery(con, "DESCRIBE fh")

query_mmo <- "CREATE VIEW mmo AS SELECT * FROM read_parquet('C:/Users/Public/Documents/Charagnoli/02 Final Data/mmo_latest_wage.parquet')"
dbExecute(con, query_mmo)
dbGetQuery(con, "DESCRIBE mmo")

query_shortage <- "CREATE VIEW shortage AS SELECT * FROM read_parquet('C:/Users/Public/Documents/Charagnoli/02 Final Data/shortage_list.parquet')"
dbExecute(con, query_shortage)
dbGetQuery(con, "DESCRIBE shortage")

query_pcs <- "CREATE VIEW pcs AS SELECT * FROM read_parquet('C:/Users/Public/Documents/Charagnoli/02 Final Data/fap_to_pcs.parquet')"
dbExecute(con, query_pcs )
dbGetQuery(con, "DESCRIBE pcs")


query_base <- "CREATE VIEW base AS SELECT *
               FROM mmo m
               INNER JOIN fh f using (id_force)
               LEFT JOIN pcs p ON m.PcsEse = p.pcs_code
               LEFT JOIN shortage s ON p.pcs_code = s.pcs_code AND m.region_contract = s.region"
dbExecute(con,query_base)
dbGetQuery(con, "DESCRIBE base")

dbExecute(con, "CREATE VIEW base2 AS SELECT *, 
                EXTRACT(YEAR FROM DebutCTT) AS contract_year,
                EXTRACT(YEAR FROM DebutCTT) - EXTRACT(YEAR FROM datnais) AS age, 
                
                COALESCE(treatment, 0) AS treatment,
                COALESCE(treatment_2008, 0) AS treatment_2008,
                COALESCE(treatment_2021, 0) AS treatment_2021,
                COALESCE(treatment_2024, 0) AS treatment_2024,
                COALESCE(treatment_2025, 0) AS treatment_2025,
                COALESCE(treatment_2025_all, 0) AS treatment_2025_all,
                
                COALESCE(relisted_2025, 0) AS relisted_2025,
                COALESCE(delisted_2021, 0) AS delisted_2021,
                COALESCE(delisted_2024, 0) AS delisted_2024,
                COALESCE(delisted_2025, 0) AS delisted_2025,
                
                CASE WHEN SEXE = 1 THEN 1 ELSE 0 END AS male,
                CASE WHEN DIPLOME = 'D' THEN 1 ELSE 0 END AS diploma,
                CASE WHEN EXPEUNIT = 'A' THEN EXPER * 12 WHEN EXPEUNIT = 'M' THEN EXPER WHEN EXPEUNIT IS NULL THEN EXPER END AS experience_months,
                
                FROM base")

dbExecute(con, "CREATE VIEW base3 AS SELECT *, CASE WHEN french = 1 THEN 'french' WHEN eea = 1 THEN 'eea' WHEN non_eea = 1 THEN 'non-eea' END as status FROM base2")
dbGetQuery(con, "DESCRIBE base3")





### PART 1: ANALYSIS SAMPLES ----

# 2021

df_2021 <- dbGetQuery(con, "SELECT *,
                      DATEDIFF('month', DATE '2021-04-01', DATE_TRUNC('month', DebutCTT)) AS relative_time_2021,
                      DATEDIFF('month', DATE '2019-01-01', DATE_TRUNC('month', DebutCTT)) AS month_index
                      FROM base3
                      WHERE ABS(DATEDIFF('month', DATE '2021-04-01', DATE_TRUNC('month', DebutCTT))) <= 18
                      AND monthly_wage IS NOT NULL
                      AND treatment_2008_1 = 0")

df_2021 <- df_2021 %>% mutate(treated = treatment_2021_1, post = post_apr2021)

df_2021_eea <- df_2021  %>% filter(status == "eea")
df_2021_noneea <- df_2021  %>% filter(status == "non-eea")  
df_2021_french <- df_2021  %>% filter(status == "french") 

# 2025

df_2025 <- dbGetQuery(con, "SELECT *,
                      DATEDIFF('month', DATE '2025-05-01', DATE_TRUNC('month', DebutCTT)) AS relative_time_2025,
                      DATEDIFF('month', DATE '2019-01-01', DATE_TRUNC('month', DebutCTT)) AS month_index
                      FROM base3
                      WHERE ABS(DATEDIFF('month', DATE '2025-05-01', DATE_TRUNC('month', DebutCTT))) <= 6
                      AND monthly_wage IS NOT NULL
                      AND treatment_2008_1 = 0")

df_2025 <- df_2025%>% mutate(treated = treatment_2025_1, post = post_may2025)

df_2025_eea <- df_2025  %>% filter(status == "eea")
df_2025_noneea <- df_2025  %>% filter(status == "non-eea")  
df_2025_french <- df_2025  %>% filter(status == "french")

### PART 2: SHARE OF CONTRACTS IN TREATED OCCUPATIONS BY STATUS ----

plot_treated_share <- function(data, year){
  data |> 
    group_by(status, treated) |>
    summarise(n = n(), .groups = "drop") |>
    group_by(status) |>
    mutate(share = n / sum(n),
           treated = factor(treated, levels = c(0, 1), labels = c("Unlisted" , "Listed")),
           status = factor(status, levels = c("french", "eea", "non-eea"),  labels = c("French", "EEA", "NonEEA"))) |>
    ggplot(aes(x = status, y = share, fill = treated)) +
    geom_col(position = "stack", width = 0.6) +
    scale_y_continuous(labels = percent_format(accuracy = 1)) +
    scale_fill_manual(values = c("Unlisted" = "#a8d5a2","Listed" = "#e0b0FF")) +
    labs(x=NULL, y = "Share of contracts", fill = NULL, subtitle = as.character(year)) +
    theme_bw() +
    theme(legend.position = "top", plot.subtitle = element_text(face = "bold", hjust = 0.5))
}


share21 <- plot_treated_share(df_2021, 2021)
share25 <- plot_treated_share(df_2025, 2025)
pshare <- (share21 | share25) + plot_layout(guides = "collect", axes = "collect") & theme(legend.position = "bottom")

ggsave("C:/Users/Public/Documents/Charagnoli/03 Output/Descriptives/sharecontracts.png", plot = pshare)

### PART 3: FORMATION SELECTION CHECKS ----

#2021
selection_french <- feols(formation ~ treated + post + treated*post | fap_code + region_contract + year,
                          data = df_2021_french , cluster = "fap_code")

selection_eea <- feols(formation ~ treated + post + treated*post | fap_code + region_contract + year,
                          data = df_2021_eea , cluster = "fap_code")

selection_noneea <- feols(formation ~ treated + post + treated*post | fap_code + region_contract + year,
                          data = df_2021_noneea , cluster = "fap_code")

etable(selection_french, selection_eea, selection_noneea,
       se.below = TRUE,
       digits = 4,
       signif.code = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
       headers = list( "French", "EEA", "NonEEA"),
       title = "2021 Selection",
       file = "C:/Users/Public/Documents/Charagnoli/03 Output/DiD/2021_selection",
       replace = TRUE)


#2025
selection_french25 <- feols(formation ~ treated + post + treated*post | fap_code + region_contract + year,
                          data = df_2025_french, cluster = "fap_code")

selection_eea25 <- feols(formation ~ treated + post + treated*post | fap_code + region_contract + year,
                       data = df_2025_eea, cluster = "fap_code")

selection_noneea25 <- feols(formation ~ treated + post + treated*post | fap_code + region_contract + year,
                          data = df_2025_noneea, cluster = "fap_code")

etable(selection_french25, selection_eea25, selection_noneea25,
       se.below = TRUE,
       digits = 4,
       signif.code = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
       headers = list( "French", "EEA", "NonEEA"),
       title = "2025 Selection",
       file = "C:/Users/Public/Documents/Charagnoli/03 Output/DiD/2025_selection",
       replace = TRUE)
