# This code: DiD analysis.

#DiD 1: Effect of listing 
  # Before and after the policy, for everyone. 
  # Treatment group: contracts in listed occupations.
  # studies: 2021, 2025.

# DiD 2: Differential effect of listing 
  # Before and after the policy, comparing different status.
  # Treatment group: contracts in listed occupations. 
  # studies: 2021, 2025.


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





### PART 1: ANALYSIS SAMPLES

# 2021

df_2021 <- dbGetQuery(con, "SELECT *,
                      DATEDIFF('month', DATE '2021-04-01', DATE_TRUNC('month', DebutCTT)) AS relative_time_2021,
                      DATEDIFF('month', DATE '2019-01-01', DATE_TRUNC('month', DebutCTT)) AS month_index
                      FROM base3
                      WHERE ABS(DATEDIFF('month', DATE '2021-04-01', DATE_TRUNC('month', DebutCTT))) <= 18
                      AND monthly_wage IS NOT NULL
                      AND treatment_2008_1 = 0")

df_2021 <- df_2021 %>% mutate(log_wage = log(monthly_wage), status = factor(status, levels = c("french", "eea", "non-eea")))
                  
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

df_2025 <- df_2025 %>% mutate(log_wage = log(monthly_wage), status = factor(status, levels = c("french", "eea", "non-eea")))

df_2025_eea <- df_2025  %>% filter(status == "eea")
df_2025_noneea <- df_2025  %>% filter(status == "non-eea")  
df_2025_french <- df_2025  %>% filter(status == "french") 
                
### PART 1. EVENT STUDIES ---------

# 2021, ALL

es1_2021 <- feols(log_wage ~ i(relative_time_2021, treatment_2021_1, ref = -1) | fap_code^year + region_contract^year,
                 data = df_2021, cluster = "fap_code")

es1_2021_coeff <- tidy(es1_2021, conf.int = TRUE) %>%
  filter(str_detect(term, "relative_time_2021")) %>% 
  mutate(time = as.integer(str_extract(term, "(?<=[:])-?[0-9]+"))) %>% 
  bind_rows(tibble(term = "ref", time = -1L, estimate = 0, conf.low = 0,  conf.high=0, std.error = 0, statistic = NA_real_, p.value = NA_real_))  %>% 
  arrange(time)

es1_2021_pre <- wald(es1_2021, keep = es1_2021_coeff %>% filter(time < -1) %>% pull(term)) 
                                                                                                                                                             
plot_es1_2021 <- ggplot(es1_2021_coeff, aes(x = time, y = estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_vline(xintercept = -0.5, linetype = "dotted", colour = "#722F37") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.5, fill = "#a8d5a2") +
  geom_line(colour = "#e0b0FF") + geom_point(colour = "#e0b0FF", size = 2) +
  scale_x_continuous(breaks = seq(-18, 18, by = 3)) +
  labs(title = "Event Study Apr 2021 - All Workers",
       subtitle = paste0("Pre-trend nullity: F = ", round(es1_2021_pre$stat, 3) ,", p = ", round(es1_2021_pre$p, 3)),
       x = "months relative to policy change", y = "coefficient") +
  theme_minimal()
  
# 2021, EEA

es1_2021_eea <- feols(log_wage ~ i(relative_time_2021, treatment_2021_1, ref = -1) | fap_code^year + region_contract^year,
                  data = df_2021_eea, cluster = "fap_code")

es1_2021_eea_coeff <- tidy(es1_2021_eea, conf.int = TRUE) %>%
  filter(str_detect(term, "relative_time_2021")) %>% 
  mutate(time = as.integer(str_extract(term, "(?<=[:])-?[0-9]+"))) %>% 
  bind_rows(tibble(term = "ref", time = -1L, estimate = 0, conf.low = 0,  conf.high=0, std.error = 0, statistic = NA_real_, p.value = NA_real_))  %>% 
  arrange(time)

es1_2021_eea_pre <- wald(es1_2021_eea, keep = es1_2021_eea_coeff %>% filter(time < -1) %>% pull(term)) 

plot_es1_eea_2021 <- ggplot(es1_2021_eea_coeff, aes(x = time, y = estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_vline(xintercept = -0.5, linetype = "dotted", colour = "#722F37") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.5, fill = "#e0b0FF") +
  geom_line(colour = "#722F37") + geom_point(colour = "#722F37", size = 2) +
  scale_x_continuous(breaks = seq(-18, 18, by = 3)) +
  labs(title = "Event Study Apr 2021 - EEA",
       subtitle = paste0("Pre-trend nullity: F = ", round(es1_2021_eea_pre$stat, 3) ,", p = ", round(es1_2021_eea_pre$p, 3)),
       x = "months relative to policy change", y = "coefficient") +
  theme_minimal()

# 2021, NonEEA

es1_2021_noneea <- feols(log_wage ~ i(relative_time_2021, treatment_2021_1, ref = -1) | fap_code^year + region_contract^year,
                      data = df_2021_noneea, cluster = "fap_code")

es1_2021_noneea_coeff <- tidy(es1_2021_noneea, conf.int = TRUE) %>%
  filter(str_detect(term, "relative_time_2021")) %>% 
  mutate(time = as.integer(str_extract(term, "(?<=[:])-?[0-9]+"))) %>% 
  bind_rows(tibble(term = "ref", time = -1L, estimate = 0, conf.low = 0,  conf.high=0, std.error = 0, statistic = NA_real_, p.value = NA_real_))  %>% 
  arrange(time)

es1_2021_noneea_pre <- wald(es1_2021_noneea, keep = es1_2021_noneea_coeff %>% filter(time < -1) %>% pull(term)) 

plot_es1_noneea_2021 <- ggplot(es1_2021_noneea_coeff, aes(x = time, y = estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_vline(xintercept = -0.5, linetype = "dotted", colour = "#722F37") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.3, fill = "#a8d5a2") +
  geom_line(colour = "#e0b0FF") + geom_point(colour = "#e0b0FF", size = 2) +
  scale_x_continuous(breaks = seq(-18, 18, by = 3)) +
  labs(title = "Event Study Apr 2021 - Non-EEA",
       subtitle = paste0("Pre-trend nullity: F = ", round(es1_2021_eea_pre$stat, 3) ,", p = ", round(es1_2021_eea_pre$p, 3)),
       x = "months relative to policy change", y = "coefficient") +
  theme_minimal()

# 2021, french

es1_2021_french <- feols(log_wage ~ i(relative_time_2021, treatment_2021_1, ref = -1) | fap_code^year + region_contract^year,
                      data = df_2021_french, cluster = "fap_code")

es1_2021_french_coeff <- tidy(es1_2021_french, conf.int = TRUE) %>%
  filter(str_detect(term, "relative_time_2021")) %>% 
  mutate(time = as.integer(str_extract(term, "(?<=[:])-?[0-9]+"))) %>% 
  bind_rows(tibble(term = "ref", time = -1L, estimate = 0, conf.low = 0,  conf.high=0, std.error = 0, statistic = NA_real_, p.value = NA_real_))  %>% 
  arrange(time)

es1_2021_french_pre <- wald(es1_2021_french, keep = es1_2021_french_coeff %>% filter(time < -1) %>% pull(term)) 

plot_es1_french_2021 <- ggplot(es1_2021_french_coeff, aes(x = time, y = estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_vline(xintercept = -0.5, linetype = "dotted", colour = "#722F37") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.5, fill = "#e0b0FF") +
  geom_line(colour = "#722F37") + geom_point(colour = "#722F37", size = 2) +
  scale_x_continuous(breaks = seq(-18, 18, by = 3)) +
  labs(title = "Event Study Apr 2021 - French",
       subtitle = paste0("Pre-trend nullity: F = ", round(es1_2021_french_pre$stat, 3) ,", p = ", round(es1_2021_french_pre$p, 3)),
       x = "months relative to policy change", y = "coefficient") +
  theme_minimal()


ggsave("C:/Users/Public/Documents/Charagnoli/03 Output/DiD/event_study_2021.png", plot = plot_es1_2021)
ggsave("C:/Users/Public/Documents/Charagnoli/03 Output/DiD/event_study_eea_2021.png", plot = plot_es1_eea_2021)
ggsave("C:/Users/Public/Documents/Charagnoli/03 Output/DiD/event_study_non_eea_2021.png", plot = plot_es1_noneea_2021)
ggsave("C:/Users/Public/Documents/Charagnoli/03 Output/DiD/event_study_french_2021.png", plot = plot_es1_french_2021)

# 2025, ALL

es1_2025 <- feols(log_wage ~ i(relative_time_2025, treatment_2025_1, ref = -1) | fap_code^year + region_contract^year,
                  data = df_2025, cluster = "fap_code")

es1_2025_coeff <- tidy(es1_2025, conf.int = TRUE) %>%
  filter(str_detect(term, "relative_time_2025")) %>% 
  mutate(time = as.integer(str_extract(term, "(?<=[:])-?[0-9]+"))) %>% 
  bind_rows(tibble(term = "ref", time = -1L, estimate = 0, conf.low = 0,  conf.high=0, std.error = 0, statistic = NA_real_, p.value = NA_real_))  %>% 
  arrange(time)

es1_2025_pre <- wald(es1_2025, keep = es1_2025_coeff %>% filter(time < -1) %>% pull(term)) 

plot_es1_2025 <- ggplot(es1_2025_coeff, aes(x = time, y = estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_vline(xintercept = -0.5, linetype = "dotted", colour = "#722F37") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.5, fill = "#a8d5a2") +
  geom_line(colour = "#e0b0FF") + geom_point(colour = "#e0b0FF", size = 2) +
  scale_x_continuous(breaks = seq(-6, 6, by = 3)) +
  labs(title = "Event Study May 2025 - All Workers",
       subtitle = paste0("Pre-trend nullity: F = ", round(es1_2025_pre$stat, 3) ,", p = ", round(es1_2025_pre$p, 3)),
       x = "months relative to policy change", y = "coefficient") +
  theme_minimal()


# 2025, EEA

es1_2025_eea <- feols(log_wage ~ i(relative_time_2025, treatment_2025_1, ref = -1) | fap_code^year + region_contract^year,
                      data = df_2025_eea, cluster = "fap_code")

es1_2025_eea_coeff <- tidy(es1_2025_eea, conf.int = TRUE) %>%
  filter(str_detect(term, "relative_time_2025")) %>% 
  mutate(time = as.integer(str_extract(term, "(?<=[:])-?[0-9]+"))) %>% 
  bind_rows(tibble(term = "ref", time = -1L, estimate = 0, conf.low = 0,  conf.high=0, std.error = 0, statistic = NA_real_, p.value = NA_real_))  %>% 
  arrange(time)

es1_2025_eea_pre <- wald(es1_2025_eea, keep = es1_2025_eea_coeff %>% filter(time < -1) %>% pull(term)) 

plot_es1_eea_2025 <- ggplot(es1_2025_eea_coeff, aes(x = time, y = estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_vline(xintercept = -0.5, linetype = "dotted", colour = "#722F37") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.5, fill = "#e0b0FF") +
  geom_line(colour = "#722F37") + geom_point(colour = "#722F37", size = 2) +
  scale_x_continuous(breaks = seq(-6, 6, by = 3)) +
  labs(title = "Event Study May 2025 -  EEA",
       subtitle = paste0("Pre-trend nullity: F = ", round(es1_2025_eea_pre$stat, 3) ,", p = ", round(es1_2025_eea_pre$p, 3)),
       x = "months relative to policy change", y = "coefficient") +
  theme_minimal()

# 2025, NonEEA

es1_2025_noneea <- feols(log_wage ~ i(relative_time_2025, treatment_2025_1, ref = -1) | fap_code^year + region_contract^year,
                      data = df_2025_noneea, cluster = "fap_code")

es1_2025_noneea_coeff <- tidy(es1_2025_noneea, conf.int = TRUE) %>%
  filter(str_detect(term, "relative_time_2025")) %>% 
  mutate(time = as.integer(str_extract(term, "(?<=[:])-?[0-9]+"))) %>% 
  bind_rows(tibble(term = "ref", time = -1L, estimate = 0, conf.low = 0,  conf.high=0, std.error = 0, statistic = NA_real_, p.value = NA_real_))  %>% 
  arrange(time)

es1_2025_noneea_pre <- wald(es1_2025_noneea, keep = es1_2025_noneea_coeff %>% filter(time < -1) %>% pull(term)) 

plot_es1_noneea_2025 <- ggplot(es1_2025_noneea_coeff, aes(x = time, y = estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_vline(xintercept = -0.5, linetype = "dotted", colour = "#722F37") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.5, fill = "#e0b0FF") +
  geom_line(colour = "#722F37") + geom_point(colour = "#722F37", size = 2) +
  scale_x_continuous(breaks = seq(-6, 6, by = 3)) +
  labs(title = "Event Study May 2025 - NonEEA",
       subtitle = paste0("Pre-trend nullity: F = ", round(es1_2025_noneea_pre$stat, 3) ,", p = ", round(es1_2025_noneea_pre$p, 3)),
       x = "months relative to policy change", y = "coefficient") +
  theme_minimal()

# 2025, french

es1_2025_french <- feols(log_wage ~ i(relative_time_2025, treatment_2025_1, ref = -1) | fap_code^year + region_contract^year,
                      data = df_2025_french, cluster = "fap_code")

es1_2025_french_coeff <- tidy(es1_2025_french, conf.int = TRUE) %>%
  filter(str_detect(term, "relative_time_2025")) %>% 
  mutate(time = as.integer(str_extract(term, "(?<=[:])-?[0-9]+"))) %>% 
  bind_rows(tibble(term = "ref", time = -1L, estimate = 0, conf.low = 0,  conf.high=0, std.error = 0, statistic = NA_real_, p.value = NA_real_))  %>% 
  arrange(time)

es1_2025_french_pre <- wald(es1_2025_french, keep = es1_2025_french_coeff %>% filter(time < -1) %>% pull(term)) 

plot_es1_french_2025 <- ggplot(es1_2025_french_coeff, aes(x = time, y = estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_vline(xintercept = -0.5, linetype = "dotted", colour = "#722F37") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.5, fill = "#e0b0FF") +
  geom_line(colour = "#722F37") + geom_point(colour = "#722F37", size = 2) +
  scale_x_continuous(breaks = seq(-6, 6, by = 3)) +
  labs(title = "Event Study May 2025 -  French",
       subtitle = paste0("Pre-trend nullity: F = ", round(es1_2025_french_pre$stat, 3) ,", p = ", round(es1_2025_french_pre$p, 3)),
       x = "months relative to policy change", y = "coefficient") +
  theme_minimal()

ggsave("C:/Users/Public/Documents/Charagnoli/03 Output/DiD/event_study_2025.png", plot = plot_es1_2025)
ggsave("C:/Users/Public/Documents/Charagnoli/03 Output/DiD/event_study_french_2025.png", plot = plot_es1_french_2025)
ggsave("C:/Users/Public/Documents/Charagnoli/03 Output/DiD/event_study_eea_2025.png", plot = plot_es1_eea_2025)
ggsave("C:/Users/Public/Documents/Charagnoli/03 Output/DiD/event_study_non_eea_2025.png", plot = plot_es1_noneea_2025)


### PART 2. DID 2021  --------- 


# ALL

all_fe1 <- feols(log_wage ~ treatment_2021_1 + post_apr2021 + treatment_2021_1*post_apr2021 + age + diploma + part_time + formation + male + experience_months | fap_code + region_contract + year,
                 data = df_2021, cluster = "fap_code")
all_fe2 <- feols(log_wage ~ treatment_2021_1 + post_apr2021 + treatment_2021_1*post_apr2021 +  age + diploma + part_time + formation + male + experience_months | fap_code^region_contract^year,
                 data = df_2021, cluster = "fap_code")
all_fe3 <- feols(log_wage ~ treatment_2021_1 + post_apr2021 + treatment_2021_1*post_apr2021 +  age + diploma + part_time + formation + male + experience_months | fap_code^year + region_contract^year,
                 data = df_2021, cluster = "fap_code")
  
# French
  
french_fe1 <- feols(log_wage ~ treatment_2021_1 + post_apr2021 + treatment_2021_1*post_apr2021 +  age + diploma + part_time + formation + male + experience_months | fap_code + region_contract + year,
                    data = df_2021_french, cluster = "fap_code")
french_fe2 <- feols(log_wage ~ treatment_2021_1 + post_apr2021 + treatment_2021_1*post_apr2021 +  age + diploma + part_time + formation + male + experience_months | fap_code^region_contract^year,
                    data = df_2021_french, cluster = "fap_code")
french_fe3 <- feols(log_wage ~ treatment_2021_1 + post_apr2021 + treatment_2021_1*post_apr2021 +  age + diploma + part_time + formation + male + experience_months | fap_code^year + region_contract^year,
                    data = df_2021_french, cluster = "fap_code")

# EEA
  
  eea_fe1 <- feols(log_wage ~ treatment_2021_1 + post_apr2021 + treatment_2021_1*post_apr2021 +  age + diploma + part_time + formation + male + experience_months | fap_code + region_contract + year,
                   data = df_2021_eea, cluster = "fap_code")
  eea_fe2 <- feols(log_wage ~ treatment_2021_1 + post_apr2021 + treatment_2021_1*post_apr2021 +  age + diploma + part_time + formation + male + experience_months | fap_code^region_contract^year,
                   data = df_2021_eea, cluster = "fap_code")
  eea_fe3 <- feols(log_wage ~ treatment_2021_1 + post_apr2021 + treatment_2021_1*post_apr2021 +  age + diploma + part_time + formation + male + experience_months | fap_code^year + region_contract^year,
                   data = df_2021_eea, cluster = "fap_code")
  

# NonEEA
  
  noneea_fe1 <- feols(log_wage ~ treatment_2021_1 + post_apr2021 + treatment_2021_1*post_apr2021 +  age + diploma + part_time + formation + male + experience_months | fap_code + region_contract + year,
                      data = df_2021_noneea, cluster = "fap_code")
  noneea_fe2 <- feols(log_wage ~ treatment_2021_1 + post_apr2021 + treatment_2021_1*post_apr2021 +  age + diploma + part_time + formation + male + experience_months | fap_code^region_contract^year,
                      data = df_2021_noneea, cluster = "fap_code")
  noneea_fe3 <- feols(log_wage ~ treatment_2021_1 + post_apr2021 + treatment_2021_1*post_apr2021 +  age + diploma + part_time + formation + male + experience_months | fap_code^year + region_contract^year,
                      data = df_2021_noneea, cluster = "fap_code")

 
#Saving, by fixed effect strcture
  
  etable(all_fe1, french_fe1, eea_fe1, noneea_fe1,
         se.below = TRUE,
         digits = 4,
         signif.code = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
         headers = list("All", "French", "EEA", "NonEEA"),
         title = "2021 Policy Effects - FE1",
         file = "C:/Users/Public/Documents/Charagnoli/03 Output/DiD/did_2021_fe2",
         replace = TRUE)
  
  etable(all_fe2, french_fe2, eea_fe2, noneea_fe2,
         se.below = TRUE,
         digits = 4,
         signif.code = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
         headers = list("All", "French", "EEA", "NonEEA"),
         title = "2021 Policy Effects - fe2",
         file = "C:/Users/Public/Documents/Charagnoli/03 Output/DiD/did_2021_fe2",
         replace = TRUE)
  
  etable(all_fe3, french_fe3, eea_fe3, noneea_fe3,
         se.below = TRUE,
         digits = 4,
         signif.code = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
         headers = list("All", "French", "EEA", "NonEEA"),
         title = "2021 Policy Effects - fe3",
         file = "C:/Users/Public/Documents/Charagnoli/03 Output/DiD/did_2021_fe3",
         replace = TRUE)
  
  
   
 
### PART 3. DID 2025 -----
  
  # ALL
  
  all_fe1_25 <- feols(log_wage ~ treatment_2025_1 +post_may2025 + treatment_2025_1*post_may2025 +  age + diploma + part_time + formation + male + experience_months | fap_code + region_contract + year,
                   data = df_2025, cluster = "fap_code")
  all_fe2_25 <- feols(log_wage ~ treatment_2025_1 +post_may2025 + treatment_2025_1*post_may2025 +  age + diploma + part_time + formation + male + experience_months | fap_code^region_contract^year,
                   data = df_2025, cluster = "fap_code")
  all_fe3_25 <- feols(log_wage ~ treatment_2025_1 +post_may2025 + treatment_2025_1*post_may2025 +  age + diploma + part_time + formation + male + experience_months | fap_code^year + region_contract^year,
                   data = df_2025, cluster = "fap_code")
  
  # French
  
  french_fe1_25 <- feols(log_wage ~ treatment_2025_1 +post_may2025 + treatment_2025_1*post_may2025 +  age + diploma + part_time + formation + male + experience_months | fap_code + region_contract + year,
                      data = df_2025_french, cluster = "fap_code")
  french_fe2_25 <- feols(log_wage ~ treatment_2025_1 +post_may2025 + treatment_2025_1*post_may2025 +  age + diploma + part_time + formation + male + experience_months | fap_code^region_contract^year,
                      data = df_2025_french, cluster = "fap_code")
  french_fe3_25 <- feols(log_wage ~ treatment_2025_1 +post_may2025 + treatment_2025_1*post_may2025 +  age + diploma + part_time + formation + male + experience_months | fap_code^year + region_contract^year,
                      data = df_2025_french, cluster = "fap_code")
  
  # EEA
  
  eea_fe1_25 <- feols(log_wage ~ treatment_2025_1 +post_may2025 + treatment_2025_1*post_may2025 +  age + diploma + part_time + formation + male + experience_months | fap_code + region_contract + year,
                   data = df_2025_eea, cluster = "fap_code")
  eea_fe2_25 <- feols(log_wage ~ treatment_2025_1 +post_may2025 + treatment_2025_1*post_may2025 +  age + diploma + part_time + formation + male + experience_months | fap_code^region_contract^year,
                   data = df_2025_eea, cluster = "fap_code")
  eea_fe3_25 <- feols(log_wage ~ treatment_2025_1 +post_may2025 + treatment_2025_1*post_may2025 +  age + diploma + part_time + formation + male + experience_months | fap_code^year + region_contract^year,
                   data = df_2025_eea, cluster = "fap_code")
  
  
  # NonEEA
  
  noneea_fe1_25 <- feols(log_wage ~ treatment_2025_1 +post_may2025 + treatment_2025_1*post_may2025 +  age + diploma + part_time + formation + male + experience_months | fap_code + region_contract + year,
                      data = df_2025_noneea, cluster = "fap_code")
  noneea_fe2_25 <- feols(log_wage ~ treatment_2025_1 +post_may2025 + treatment_2025_1*post_may2025 +  age + diploma + part_time + formation + male + experience_months | fap_code^region_contract^year,
                      data = df_2025_noneea, cluster = "fap_code")
  noneea_fe3_25 <- feols(log_wage ~ treatment_2025_1 +post_may2025 + treatment_2025_1*post_may2025 +  age + diploma + part_time + formation + male + experience_months | fap_code^year + region_contract^year,
                      data = df_2025_noneea, cluster = "fap_code")
  
  #Saving, by fixed effect strcture
  
  etable(all_fe1_25, french_fe1_25, eea_fe1_25, noneea_fe1_25,
         se.below = TRUE,
         digits = 4,
         signif.code = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
         headers = list("All", "French", "EEA", "NonEEA"),
         title = "2025 Policy Effects - FE1",
         file = "C:/Users/Public/Documents/Charagnoli/03 Output/DiD/did_2025_fe1",
         replace = TRUE)
  
  etable(all_fe2_25, french_fe2_25, eea_fe2_25, noneea_fe2_25,
         se.below = TRUE,
         digits = 4,
         signif.code = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
         headers = list("All", "French", "EEA", "NonEEA"),
         title = "2025 Policy Effects - fe2",
         file = "C:/Users/Public/Documents/Charagnoli/03 Output/DiD/did_2025_fe2",
         replace = TRUE)
  
  etable(all_fe3_25, french_fe3_25, eea_fe3_25, noneea_fe3_25,
         se.below = TRUE,
         digits = 4,
         signif.code = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
         headers = list("All", "French", "EEA", "NonEEA"),
         title = "2025 Policy Effects - fe3",
         file = "C:/Users/Public/Documents/Charagnoli/03 Output/DiD/did_2025_fe3",
         replace = TRUE)

