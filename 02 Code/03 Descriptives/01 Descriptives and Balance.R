# This code: Descriptives.

### Part 0: Set-up -------------

rm(list=ls())

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(tibble)
library(duckdb)
library(scales)
library(purrr)
library(glue)
library(gt)
library(DBI)
library(xtable)

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

query_base <- "CREATE VIEW base AS SELECT *
               FROM mmo m
               INNER JOIN fh f using (id_force)
               LEFT JOIN shortage s ON m.PcsEse = s.pcs_code AND m.region_contract = s.region"
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
                CASE WHEN EXPEUNIT = 'A' THEN EXPER * 12 WHEN EXPEUNIT = 'M' THEN EXPER WHEN EXPEUNIT IS NULL THEN EXPER END AS experience_months
                FROM base")

dbExecute(con, "CREATE VIEW base3 AS SELECT *, CASE WHEN french = 1 THEN 'french' WHEN eea = 1 THEN 'eea' WHEN non_eea = 1 THEN 'non-eea' END as status FROM base2")
dbGetQuery(con, "DESCRIBE base3")

status_colors <- c( "french" = "#a8d5a2", "eea" ="#722F37", "non-eea"="#e0b0FF")
treatment_colors <- c("Listed" = "#a8d5a2", "Unlisted"="#e0b0FF")
samples <- c("sample1", "sample2", "sample3", "sample4")
sample_labels <- c("sample1" = "Yugoslav Split", "sample2" = "YUG vs. BGR + ROU", "sample3" = "TUR vs. GRC + BGR + ROU", "sample4" = "Slavic Split")

             
### Part 1: Wage distribution -------------

wage_query <- function(sample_col = NULL){
  sample_filter <- if(!is.null(sample_col))
    paste0("WHERE ", sample_col, " = 1") else ""
    paste0("SELECT status, treatment_1,  PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY monthly_wage) AS p10,
                      PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY monthly_wage) AS p25,
                      PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY monthly_wage) AS p50,
                      PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY monthly_wage) AS p75,
                      PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY monthly_wage) AS p90,
                      COUNT(*) AS n
           FROM base3 ", sample_filter, " GROUP BY status, treatment_1")}

wages_all <- dbGetQuery(con, wage_query())
wages_all <- wages_all |>  mutate(treatment_label = ifelse(treatment_1 == 1, "Listed", "Unlisted"), status = factor(status, levels = c("french", "eea", "non-eea")))

boxplot1 <- ggplot(wages_all, aes(x = treatment_label, color = treatment_label, fill = treatment_label)) +
            geom_linerange(aes(ymin =p10, ymax = p90), linewidth = 0.8) +
            geom_crossbar(aes(y=p50, ymin = p25, ymax =p75), width = 0.5, linewidth = 0.6, alpha = 0.6) +
            geom_point(aes(y = p10), shape = 19, size = 2) +
            geom_point(aes(y = p90), shape = 19, size = 2) +
            facet_wrap(~ status) +
            scale_color_manual(values = treatment_colors) +
            scale_fill_manual(values = treatment_colors)+
            theme_minimal() +
            labs(title = NULL, x = NULL, color = NULL, fill = NULL, y = "monthly wage, euros") +
            theme(legend.position = "bottom", strip.text = element_text(face="bold"), axis.text.x = element_blank())

ggsave("C:/Users/Public/Documents/Charagnoli/03 Output/Descriptives/boxplot_fullsample.png", plot = boxplot1) 


### Part 2: Balance checks ---------

# Variables to balance 
dbExecute(con, "CREATE OR REPLACE VIEW individual_level AS SELECT DISTINCT ON (id_force)
                id_force, age, status, diploma, part_time, male, formation, experience_months, treatment_2021_1, treatment_2024_1, treatment_2025_1 FROM base3")

individual_vars <- c("age", "male", "diploma", "part_time", "formation", "experience_months")
contract_vars <- c("monthly_wage")
treatment_vars <- c("treatment_2021_1", "treatment_2024_1", "treatment_2025_1")

# helpers
make_balance <- function(group_col, group_levels = NULL, vars, tbl){
  
  safe_prefix <- gsub("[^a-zA-Z0-9]", "_", group_col)
  
  
  var_blocks <- lapply(vars,function(v){
    
    cte_stats <- paste0("grp_", safe_prefix, "_", v)
    cte_pairs <- paste0("pairs_", safe_prefix, "_", v)
    
    group_stats <- paste0(cte_stats," AS (\n", 
      "SELECT ", group_col, " AS grp,\n",
      "AVG (", v, ") AS mn,\n",
      "STDDEV_SAMP (", v, ") AS sd,\n",
      "COUNT (", v, ") AS n\n",
      "FROM ", tbl, "\n",
      "WHERE ", group_col, " IS NOT NULL\n",
      "GROUP BY ", group_col, "\n",
      "), \n")
    
    pairs <- paste0(cte_pairs, " AS (\n",
      "SELECT '", v, "' AS variable,\n",
      "a.grp || 'vs' || b.grp AS comparison,\n",
      "a.mn AS mean_a,\n",
      "b.mn AS mean_b,\n",
      "a.mn - b.mn AS diff,\n",
      "a.n AS n_a,\n",
      "b.n AS n_b,\n",
      "(a.mn-b.mn) /\n",
      "NULLIF(SQRT(a.sd*a.sd/a.n + b.sd*b.sd/b.n), 0) AS t_stat \n",
      "FROM ", cte_stats , " a\n",
      "CROSS JOIN ", cte_stats , " b\n",
      "WHERE a.grp < b.grp\n",")\n")
    
    list(cte = paste0(group_stats, pairs), sel = paste0("SELECT * FROM ", cte_pairs))})
    
    ctes <- paste(sapply(var_blocks, `[[`, "cte"), collapse = ",\n")
    sels <- paste(sapply(var_blocks, `[[`, "sel"), collapse = "\nUNION ALL\n")
    
    paste0("WITH\n", ctes, "\n", sels, "\nORDER BY comparison, variable")}

make_means_sql <- function(group_col, vars, tbl){
  
  aggs <- paste(
    c("COUNT(*) AS n_total", 
    sapply(vars, function(v) paste0("AVG(", v, ") AS mean_", v))), collapse = ",\n")


  paste0("SELECT ", group_col, " AS group_label, \n",
         " ", aggs, "\n",
         "FROM ", tbl, "\n",
         "WHERE ", group_col, " IS NOT NULL\n",
         "GROUP BY ", group_col, "\n",
         "ORDER BY ", group_col)}

dimensions <- list(list(col = "status", label = "status", treatment = NULL))
    
for (tv in treatment_vars){
  dimensions <- c(dimensions, list(
    list(col=tv, label = tv, treatment = tv),
    list(col = paste0("status_x_", tv), label = paste0("interaction_", tv), treatment = tv)
))}          

for (tv in treatment_vars) {dbExecute(con, paste0("CREATE OR REPLACE VIEW base4_", tv," AS SELECT *, status || 'x' || ", tv, " AS status_x_", tv, " FROM base3"))}
for (tv in treatment_vars) {dbExecute(con, paste0("CREATE OR REPLACE VIEW individual_level_", tv," AS SELECT DISTINCT ON (id_force) id_force, age, status,", tv, ", diploma, part_time, male, formation,
                                experience_months, status || 'x' || ", tv, " AS status_x_", tv, " FROM base3"))}


results_balance <- vector("list", length(dimensions))
names(results_balance) <- sapply(dimensions, `[[`, "label")  
  
for (i in seq_along(dimensions)) {
  
  d <- dimensions[[i]]
  
  cat("Running:", d$label, "\n")
  
  tbl_contract <- if (grepl("^interaction_", d$label)){paste0("base4_", d$treatment)} else { "base3"}
  tbl_individual <- if (grepl("^interaction_", d$label)){paste0("individual_level_", d$treatment)} else { "individual_level"}
  
  means <- bind_rows(dbGetQuery(con, make_means_sql(d$col, individual_vars, tbl_individual)),
                      dbGetQuery(con, make_means_sql(d$col, contract_vars, tbl_contract)))
                     
                     
  diffs <- bind_rows(dbGetQuery(con, make_balance(d$col,NULL, individual_vars, tbl_individual)),
                     dbGetQuery(con, make_balance(d$col,NULL, contract_vars, tbl_contract)))
  
  diffs|> mutate(sig = case_when(abs(t_stat) > 2.576 ~ "***",
                           abs(t_stat) > 1.960 ~ "**",
                           abs(t_stat) > 1.645 ~ "*",
                           TRUE ~ ""))
  
  results_balance[[i]] <- list(means = means, diffs = diffs)
}

output_path <- "C:/Users/Public/Documents/Charagnoli/03 Output/Descriptives/"
for (mn in names(results_balance)){
  write.csv(results_balance[[mn]]$means, file.path(output_path, paste0("balance_means_", mn, ".csv")), row.names = FALSE)
  write.csv(results_balance[[mn]]$diffs, file.path(output_path, paste0("balance_diffs_", mn, ".csv")), row.names = FALSE)
}

### Part 3: Regions and occupations -----
raw_df <- dbGetQuery(con, "SELECT * FROM shortage")

# Region Split

region_table <- raw_df |> distinct(fap_code, region,treatment_2021, treatment_2024, treatment_2025, treatment_2025_all) |>
  group_by(region)|>
  summarise(present_2021 = sum(treatment_2021 == 1),
            present_2024 = sum(treatment_2024 == 1),
            present_2025 = sum(treatment_2025_all == 1),
            total = n())  |>
  arrange(desc(total))

region_latex <- region_table |>
  rename("Region" = region, "2021" = present_2021, "2024" = present_2024, "2025" = present_2025, "Total" = total)

print(xtable(region_latex, caption = "Listed FAP by region and listing year"), include.rownames = FALSE, booktabs = TRUE, file = "C:/Users/Public/Documents/Charagnoli/03 Output/Descriptives/region_breakdown.tex")

#  Correlation matrix

region_fap <- raw_df |> distinct(fap_code, region) |>
  mutate(present = 1) |>
  pivot_wider(names_from = region, values_from = present, values_fill = 0)

regions <- names(region_fap)[-1]
jaccard <-function(a,b) sum(a&b) / sum(a | b)

jaccard_matrix <- outer(regions, regions, Vectorize(function(r1, r2) {jaccard(region_fap[[r1]],region_fap[[r2]])}))
rownames(jaccard_matrix) <- colnames(jaccard_matrix) <- regions

jaccard_long <- as.data.frame(jaccard_matrix)|>
  rownames_to_column("region_x") |>
  pivot_longer(-region_x, names_to = "region_y", values_to = "jaccard")

heatmap <- ggplot(jaccard_long, aes(x=region_x, y = region_y, fill = jaccard)) +
  geom_tile(colour = "white", linewidth = 0.5) +
  geom_text(aes(label=round(jaccard,2)), size = 3, colour = "white") +
  scale_fill_gradient(low = "#2F5496", high = "#C94040", limits= c(0,1), guide = "none") +
  labs(title = NULL, x = NULL, y = NULL) +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid = element_blank(),
        plot.title = element_text(face="bold"))

ggsave("C:/Users/Public/Documents/Charagnoli/03 Output/Descriptives/heatmap.png", plot = heatmap)
dbDisconnect(con)