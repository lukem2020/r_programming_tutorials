# Methods Cheatsheet — Clinical Visual Analytics

One-page reference for interview concept questions.

## RBQM loop

```
CtQ factors → Risk assessment → Mitigation → Monitoring (KRIs/QTLs) → Corrective action
```

| Term | Definition |
|------|------------|
| **RBQM** | Risk-Based Quality Management — focus oversight on essential trial activities |
| **CtQ** | Critical to Quality — factors that must be right for safety and result credibility |
| **KRI** | Key Risk Indicator — metric that signals emerging risk (e.g., high query rate at a site) |
| **QTL** | Quality Tolerance Limit — threshold beyond which corrective action is required |
| **QbD** | Quality by Design — build quality into protocol/plans upfront (ICH E8(R1)) |

**Key guidance:** FDA 2013 (risk-based monitoring), EMA 2013 (RBQM reflection paper), ICH E6(R2/R3), ICH E8(R1).

## MDR workflow

| Step | Action |
|------|--------|
| 1 | Define scope in **Medical Data Review Plan (MDRP)** |
| 2 | Filter to correct **analysis population** (e.g., `SAFFL == "Y"`) |
| 3 | Review **population-level** safety (TEAE incidence, lab shifts) |
| 4 | **Drill down** to patient profiles for signal validation |
| 5 | Document findings; escalate per study governance |

**MDR vs SDV:** MDR = medical review of trial data for signals. SDV = verification against source documents. Complementary under RBQM.

## CDISC datasets (need-to-know)

| Dataset | Grain | Key variables |
|---------|-------|---------------|
| **ADSL** | 1 row / subject | `USUBJID`, `ARM`, `AGE`, `SEX`, `RACE`, `SAFFL`, `ITTFL` |
| **ADAE** | 1 row / event | `AEDECOD`, `AESOC`, `AESEV`, `TRTEMFL`, `AESTDTC`, `AEREL` |
| **ADLB** | 1 row / lab / visit | `PARAM`, `AVAL`, `CHG`, `ANRIND`, `ABLFL`, `AVISIT`, `ADY` |

**Join key:** `USUBJID` (always start from `ADSL`)

## Safety signal methods

| Method | Formula / logic | Use case |
|--------|-----------------|----------|
| TEAE filter | `TRTEMFL == "Y"` | Post-treatment events only |
| Event count | `n()` per `ARM` × `AEDECOD` | Volume comparison |
| Subject incidence | `n_distinct(USUBJID)` / `n subjects in arm` | Primary safety table |
| Lab shift | baseline `ANRIND` → latest post-baseline `ANRIND` | Hepatotoxicity / renal monitoring |
| Patient profile | filter all datasets to one `USUBJID` | MDR drill-down |

## Clinical terminology

| Term | Meaning |
|------|---------|
| **CRF** | Case Report Form — data collection instrument at sites |
| **TEAE** | Treatment-Emergent Adverse Event |
| **SOC** | System Organ Class (MedDRA high-level grouping) |
| **PT** | Preferred Term (`AEDECOD`) |
| **FPI** | First Patient In — key delivery milestone |
| **SAFFL** | Safety population flag |

## R / tooling

| Tool | Role |
|------|------|
| **tidyverse** | Data wrangling (`dplyr`, `tidyr`, `ggplot2`) |
| **Shiny** | Interactive web apps |
| **teal** | Clinical trial Shiny framework (filters, modules, CDISC) |
| **teal.modules.clinical** | Standard modules: demographics, AEs, KM, line plots, patient profiles |
| **Git** | Version control, peer review, traceability |
| **renv** | Reproducible package environment |

## teal vs raw Shiny

| | teal | raw Shiny |
|---|------|-----------|
| Clinical modules | Built-in (AE, KM, profiles) | Build yourself |
| CDISC joins | `cdisc_data()` handles keys | Manual joins |
| Cross-tab filters | Shared filter panel | Custom `reactive()` per tab |
| Best for | Regulated standard templates | Custom UX, quick prototypes |
| This repo | `app/app.R` | `app/app_shiny_fallback.R` |

## Repo quick commands

```bash
Rscript scripts/setup_env.R       # first-time environment setup
Rscript R/data_generation.R       # create synthetic ADaM data
```

```r
shiny::runApp("app")                          # teal dashboard
shiny::runApp("app/app_shiny_fallback.R")     # Shiny fallback
```
