# This code: converts datasets to parquet, some light final cleaning.

### Part 0: Set-Up -----

rm(list=ls())
library(arrow)
library(duckdb)
library(dplyr)


### Part 1: Convert to Parquet -----

read_csv_arrow("C:/Users/Public/Documents/Charagnoli/01 Intermediate Data/shortage_list.csv") |> write_parquet(sub(".csv", ".parquet","C:/Users/Public/Documents/Charagnoli/02 Final Data/shortage_list.csv"))
#read_csv_arrow("C:/Users/Public/Documents/Charagnoli/01 Intermediate Data/mmo_latest.csv") |> write_parquet(sub(".csv", ".parquet","C:/Users/Public/Documents/Charagnoli/02 Final Data/mmo_latest.csv"))
#read_csv_arrow("C:/Users/Public/Documents/Charagnoli/01 Intermediate Data/FH/fh_latest.csv") |> write_parquet(sub(".csv", ".parquet","C:/Users/Public/Documents/Charagnoli/02 Final Data/fh_latest.csv"))
#read_csv_arrow("C:/Users/Public/Documents/Charagnoli/01 Intermediate Data/fap_to_pcs.csv") |> write_parquet(sub(".csv", ".parquet","C:/Users/Public/Documents/Charagnoli/02 Final Data/fap_to_pcs.csv"))


### Part 2: Harmonize wages, exclude DOM TOM, retrieve contract location ----

setwd("C:/Users/Public/Documents/Charagnoli/02 Final Data")
getwd()

con <- dbConnect(duckdb())
dbGetQuery(con, "SHOW TABLES")

# FH

query_fh <- "CREATE VIEW fh AS SELECT * FROM read_parquet('C:/Users/Public/Documents/Charagnoli/02 Final Data/fh_latest.parquet')" #WHERE REGION NOT IN
dbExecute(con, query_fh)
dbGetQuery(con, "DESCRIBE fh")
dbGetQuery(con, "SELECT DISTINCT REGION FROM fh") 

# MMO
query_mmo <- "CREATE VIEW mmo AS SELECT * FROM read_parquet('C:/Users/Public/Documents/Charagnoli/02 Final Data/mmo_latest.parquet') WHERE salaire_base IS NOT NULL AND salaire_base > 0"
dbExecute(con, query_mmo)
dbGetQuery(con, "DESCRIBE mmo")

# MMO diagnostics
dbGetQuery(con, "SELECT ModeExercice, COUNT(*) as n FROM mmo GROUP BY ModeExercice ORDER BY n DESC")
dbGetQuery(con, "SELECT COUNT(*),  COUNT(*) as total,
                 SUM(CASE WHEN salaire_base is NULL THEN 1 ELSE 0 END) as missing_salary,
                 SUM(CASE WHEN salaire_base_mois_complet is NULL THEN 1 ELSE 0 END) as missing_mois,
                 SUM(CASE WHEN DebutCTT is NULL THEN 1 ELSE 0 END) as missing_debut,
                 SUM(CASE WHEN FinCTT is NULL THEN 1 ELSE 0 END) as missing_fin,
                 SUM(CASE WHEN ModeExercice is NULL THEN 1 ELSE 0 END) as missing_mode
                 FROM mmo")


query1 <- "CREATE TABLE mmo_2 AS SELECT *, 

           CAST(FinCTT AS DATE) - CAST(DebutCTT AS DATE) + 1 as contract_days,
           
           CASE WHEN ModeExercice = '10' THEN 0
                WHEN ModeExercice IN ('20', '30', '40', '41', '42') THEN 1
                 WHEN ModeExercice = '99' AND salaire_base < 1521.22 THEN 1
                 WHEN ModeExercice = '99' AND salaire_base >= 1521.22 THEN 0
            ELSE NULL
            END AS part_time,
           
           CASE WHEN part_time = 1 AND salaire_base_mois_complet = '1' THEN salaire_base
                WHEN part_time = 0 AND salaire_base_mois_complet = '0' THEN Salaire_base / (CAST(FinCTT AS DATE) - CAST(DebutCTT AS DATE) + 1)*30.4375
                WHEN part_time = 1 AND salaire_base_mois_complet = '1' THEN salaire_base
                WHEN part_time = 0 AND salaire_base_mois_complet = '0' THEN Salaire_base / (CAST(FinCTT AS DATE) - CAST(DebutCTT AS DATE) + 1)*30.4375
           ELSE NULL
           END AS monthly_wage,
           
           CASE WHEN CP IS NULL THEN 'Abroad'
           
           ELSE CASE LEFT(LPAD(CAST(CP AS VARCHAR), 5, '0'), 2)
           
           WHEN '01' THEN 'Auvergne-Rhône-Alpes'
           WHEN '03' THEN 'Auvergne-Rhône-Alpes'
           WHEN '07' THEN 'Auvergne-Rhône-Alpes'
           WHEN '15' THEN 'Auvergne-Rhône-Alpes'
           WHEN '26' THEN 'Auvergne-Rhône-Alpes'
           WHEN '38' THEN 'Auvergne-Rhône-Alpes'
           WHEN '42' THEN 'Auvergne-Rhône-Alpes'
           WHEN '43' THEN 'Auvergne-Rhône-Alpes'
           WHEN '63' THEN 'Auvergne-Rhône-Alpes'
           WHEN '69' THEN 'Auvergne-Rhône-Alpes'
           WHEN '73' THEN 'Auvergne-Rhône-Alpes'
           WHEN '74' THEN 'Auvergne-Rhône-Alpes'
           
           WHEN '21' THEN 'Bourgogne-Franche-Comté'
           WHEN '25' THEN 'Bourgogne-Franche-Comté'
           WHEN '39' THEN 'Bourgogne-Franche-Comté'
           WHEN '58' THEN 'Bourgogne-Franche-Comté'
           WHEN '70' THEN 'Bourgogne-Franche-Comté'
           WHEN '71' THEN 'Bourgogne-Franche-Comté'
           WHEN '89' THEN 'Bourgogne-Franche-Comté'
           WHEN '90' THEN 'Bourgogne-Franche-Comté'
           
           WHEN '22' THEN 'Bretagne'
           WHEN '29' THEN 'Bretagne'
           WHEN '35' THEN 'Bretagne'
           WHEN '56' THEN 'Bretagne'
           
           WHEN '18' THEN 'Centre-Val de Loire'
           WHEN '28' THEN 'Centre-Val de Loire'
           WHEN '36' THEN 'Centre-Val de Loire'
           WHEN '37' THEN 'Centre-Val de Loire'
           WHEN '41' THEN 'Centre-Val de Loire'
           WHEN '45' THEN 'Centre-Val de Loire'
           
           WHEN '2A' THEN 'Corse'
           WHEN '2B' THEN 'Corse'
           WHEN '20' THEN 'Corse'
           
           WHEN '08' THEN 'Grand Est'
           WHEN '10' THEN 'Grand Est'
           WHEN '51' THEN 'Grand Est'
           WHEN '52' THEN 'Grand Est'
           WHEN '54' THEN 'Grand Est'
           WHEN '55' THEN 'Grand Est'
           WHEN '57' THEN 'Grand Est'
           WHEN '67' THEN 'Grand Est'
           WHEN '68' THEN 'Grand Est'
           WHEN '88' THEN 'Grand Est'
           
           WHEN '02' THEN 'Hauts-de-France'
           WHEN '59' THEN 'Hauts-de-France'
           WHEN '60' THEN 'Hauts-de-France'
           WHEN '62' THEN 'Hauts-de-France'
           WHEN '80' THEN 'Hauts-de-France'
           
           WHEN '75' THEN 'Ile-de-France'
           WHEN '77' THEN 'Ile-de-France'
           WHEN '78' THEN 'Ile-de-France'
           WHEN '91' THEN 'Ile-de-France'
           WHEN '92' THEN 'Ile-de-France'
           WHEN '93' THEN 'Ile-de-France'
           WHEN '94' THEN 'Ile-de-France'
           WHEN '95' THEN 'Ile-de-France'
           
           WHEN '14' THEN 'Normandie'
           WHEN '27' THEN 'Normandie'
           WHEN '50' THEN 'Normandie'
           WHEN '61' THEN 'Normandie'
           WHEN '76' THEN 'Normandie'
           
           WHEN '16' THEN 'Nouvelle-Aquitaine'
           WHEN '17' THEN 'Nouvelle-Aquitaine'
           WHEN '19' THEN 'Nouvelle-Aquitaine'
           WHEN '23' THEN 'Nouvelle-Aquitaine'
           WHEN '24' THEN 'Nouvelle-Aquitaine'
           WHEN '33' THEN 'Nouvelle-Aquitaine'
           WHEN '40' THEN 'Nouvelle-Aquitaine'
           WHEN '47' THEN 'Nouvelle-Aquitaine'
           WHEN '64' THEN 'Nouvelle-Aquitaine'
           WHEN '79' THEN 'Nouvelle-Aquitaine'
           WHEN '86' THEN 'Nouvelle-Aquitaine'
           WHEN '87' THEN 'Nouvelle-Aquitaine'
           
           WHEN '09' THEN 'Occitanie'
           WHEN '11' THEN 'Occitanie'
           WHEN '12' THEN 'Occitanie'
           WHEN '30' THEN 'Occitanie'
           WHEN '31' THEN 'Occitanie'
           WHEN '32' THEN 'Occitanie'
           WHEN '34' THEN 'Occitanie'
           WHEN '46' THEN 'Occitanie'
           WHEN '48' THEN 'Occitanie'
           WHEN '65' THEN 'Occitanie'
           WHEN '66' THEN 'Occitanie'
           WHEN '81' THEN 'Occitanie'
           WHEN '82' THEN 'Occitanie'
           
           WHEN '44' THEN 'Pays de la Loire'
           WHEN '49' THEN 'Pays de la Loire'
           WHEN '53' THEN 'Pays de la Loire'
           WHEN '72' THEN 'Pays de la Loire'
           WHEN '85' THEN 'Pays de la Loire'
           
           WHEN '04' THEN 'Provence-Alpes-Côte d''Azur'
           WHEN '05' THEN 'Provence-Alpes-Côte d''Azur'
           WHEN '06' THEN 'Provence-Alpes-Côte d''Azur'
           WHEN '13' THEN 'Provence-Alpes-Côte d''Azur'
           WHEN '83' THEN 'Provence-Alpes-Côte d''Azur'
           WHEN '84' THEN 'Provence-Alpes-Côte d''Azur'
           
           WHEN '97' THEN 'Outre Mer'
           WHEN '98' THEN 'Outre Mer'
           
           END
           END AS region_contract
           FROM read_parquet('mmo_latest.parquet')"

dbExecute(con, query1)

dbGetQuery(con, "SELECT * FROM mmo_2 WHERE region_contract IS NULL")

dbExecute(con, "CREATE TABLE mmo_3 AS SELECT * FROM mmo_2 WHERE region_contract NOT IN ('Abroad', 'Outre Mer') AND region_contract IS NOT NULL")
     
dbExecute(con, "COPY mmo_3 TO 'mmo_latest_wage.parquet' (FORMAT PARQUET)")

dbDisconnect(con)


