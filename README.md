# Shortage Lists and Monopsony

Replication repository for the _Applied Labor Economics_ final project at ENSAE Paris (2025–2026).

**Authors:** Lisa Chardon--Denizot and Maria Romagnoli

---

## Research question

Do French *métiers en tension* shortage lists generate wage markdowns for non-EEA workers? We exploit the 2021 and 2025 updates to the list to test whether being employed in a listed occupation compresses outside options for non-EEA permit holders, allowing firms to set wages below competitive levels.

---

## Data

The analysis uses the **ForCE 2025S2** vintage, accessed via CASD. Two datasets are combined:

- **FH** (*Fichier Historique*): jobseeker records from France Travail, providing nationality and socio-demographics.
- **MMO** (*Mouvements de Main d'Œuvre*): contract-level employment spells from the Labour Ministry, with monthly wages, region, and PCS-ESE occupation codes.

The shortage lists (2008, 2021, 2024, 2025) are parsed from the official *arrêtés* (PDFs in `02 Code/01 Extraction/00 Raw/`). Occupation matching relies on DARES FAP–PCS correspondence table.

**Raw data not included** in this repository.

---

## Repository structure

```
01 Reporting/
│
├── Analysis Plans/        Presentations and research proposal
├── Literature Review/     Key papers
└── Final Report/ Final report

02 Code/
│
├── 01 Extraction/
│   ├── 00 Raw/            PDFs of arrêtés + correspondence tables + sources
│   └── 01 build shortage list.R   Parse arrêtés → shortage_list.csv
│
├── 02 Cleaning/
│   ├── 01 FH Cleaning.sas          Clean FH → fh_latest.csv, unique_ids.csv
│   ├── 02 MMO Cleaning.sas         Clean MMO → mmo_latest.csv
│   ├── 03 Shortage List + FAP PCS Match.R   Build FAP–PCS crosswalk
│   └── 04 Parquet + Final Cleaning.R        Wage harmonisation → .parquet
│
├── 03 Descriptives/
│   └── 01 Descriptives and Balance.R
│
└── 04 Analysis/
    ├── 01 DiD.R           Main DiD regressions (FE1, FE2, FE3) + event studies
    └── 02 Robustness.R    Robustness checks

03 Output/
├── Descriptives/          Tables and figures for the descriptive section
└── DiD/                   Regression output tables + event study plots
```

---

## Replication pipeline

Run scripts in the following order. Steps C–D require SAS; all others require R.

| Step | Script | Input | Output |
|------|--------|-------|--------|
| A | `01 Extraction/01 build shortage list.R` | PDFs in `00 Raw/` | `shortage_list.csv` |
| B | `02 Cleaning/03 Shortage List + FAP PCS Match.R` | `shortage_list.csv`, DARES ODS | `fap_to_pcs.csv` |
| C | `02 Cleaning/01 FH Cleaning.sas` | FH raw | `fh_latest.csv`, `unique_ids.csv` |
| D | `02 Cleaning/02 MMO Cleaning.sas` | MMO raw | `mmo_latest.csv` |
| E | `02 Cleaning/04 Parquet + Final Cleaning.R` | all CSVs | `mmo_latest_wage.parquet` |
| F | `04 Analysis/01 DiD.R` | all parquets | regression tables + event study figures |
| G | `04 Analysis/02 Robustness.R` | all parquets | robustness checks |

---

## Software

- **SAS**
- **R** ≥ 4.4 with packages: `duckdb`, `dbplyr`, `dplyr`, `fixest`, `ggplot2`, `tidyr`, `lubridate`, `readr`

---

## Notes

- `did_2025_fe1` is absent from `03 Output/DiD/` due to an exporting error; only FE2 and FE3 results are available for the 2025 cohort.
- The 2024 policy amendment was minor and is excluded from the main analysis.
