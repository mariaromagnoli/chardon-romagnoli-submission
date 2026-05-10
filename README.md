# Welcome to our project !

This is our submission for the _Applied Labor Economics_ final project at ENSAE. 

## Overview

This repository contains the replication code and results for our empirical 
analysis of whether France's regional shortage-occupation lists (*métiers en tension*) g
generate wage markdowns for non-EEA workers. 
We implement a difference-in-differences design with event studies, estimated separately for the 2021, 2024, 2025 and
stacking all three dates listing reforms.

---

## Repository structure

```

This repository is structured as follows:
- _*00 Variable Bank*_ $\rightarrow$ an Excel that documents all variables used throughout the project.

 - _01 Extraction_ $\rightarrow$ code + raw data relating to the ShortageList dataset construction.
   - `01 build shortage list.R`

│
├── 02 Data/                # Not tracked (see Data access below)
│
└── 03 Results/
    ├── 2021/               # Outputs for the 2021 listing cohort
    ├── 2024/               # Outputs for the 2024 listing cohort
    ├── 2025/               # Outputs for the 2025 listing cohort
    └── stacked/            # Pooled stacked estimates and diagnostic plots
```

---

## Data access

The primary data source is **ForCE** (*Formation, Chômage et Emploi*), a French administrative dataset held by France Travail. 
Access requires an individual research agreement. 
Raw data files should be placed under `01 Data/` once access is granted.

Two ForCE tables are used:
- **Fichier Historique (FH)** — worker socio-demographics and unemployment spells, merged on `force_id`
- **Mouvement de Main-d'Œuvre (MMO)** — contract-level wages and job characteristics

The listing status of each occupation-region cell by year is constructed from the *arrêtés* published in the *Journal Officiel* (2021, 2024, 2025 reforms).

---

## Requirements

All analysis is conducted in **R**. The following packages are required:

```r
install.packages(c("fixest", "dplyr", "tidyr", "ggplot2", "purrr", "haven", "broom"))
```

| Package | Use |
|---|---|
| `fixest` | High-dimensional fixed-effects estimation (`feols`) and delta-method tests |
| `dplyr` / `tidyr` / `purrr` | Data wrangling and stacked dataset construction |
| `ggplot2` | Event-study figures |
| `haven` | Reading `.sas7bdat` / `.dta` ForCE extracts |

---

## Empirical design

For each listing cohort we estimate:

$$\ln w_{ijrts} = \sum_{k \neq -1} \beta_k \bigl(\mathbf{1}[\text{group}_i = g] \times \mathbf{1}[\text{policy}_{jrt} = k]\bigr) + \mathbf{X}_{ijrt}'\,\gamma + \delta_{jrt} + \varepsilon_{ijrts}$$

where the fixed effects $\delta_{jrt}$ absorb occupation × region × year variation. The main coefficient of interest is the delta-method difference $\Delta_k = \hat\beta_k^{\text{non-EEA}} - \hat\beta_k^{\text{EEA}}$, which isolates the monopsony effect from both the shortage premium and taste-based discrimination.

See the paper for full details on identification assumptions, sample construction, and robustness checks.

---

## Results structure

Each cohort subfolder under `02 Results/` contains:

```
2021/
├── es_nonEEA_vs_French.png     # Event study: non-EEA relative to French
├── es_EEA_vs_French.png        # Event study: EEA relative to French
├── es_delta.png                # Differential Δk with delta-method CIs
└── delta_table.tex             # Delta-method estimates, SEs and p-values
```

The `stacked/` subfolder collects results stacked across cohorts.

---

## Reference

Key references: Naidu, Nyarko & Wang (2016, JPE); Signorelli (2024, JHR); Amior & Stuhler (2024, CEP DP1971); Callaway & Sant'Anna (2021, JoE); Sun & Abraham (2021, JoE).