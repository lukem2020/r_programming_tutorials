# Methods Cheatsheet — Clinical Visual Analytics

One-page reference for interview concept questions. Full demo script and S1–S10 analysis catalogue: [interview_guide.md](interview_guide.md).

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
| **ADEX** | 1 row / exposure record | `EXDOSE`, `EXDURD`, `EXROUTE`, `EXSTDY` |
| **ADVS** | 1 row / vital / visit | `PARAM`, `AVAL`, `CHG`, `AVISIT`, `AVISITN` |
| **ADCM** | 1 row / medication | `CMTRT`, `CMDECOD`, `ONTRTFL`, `ASTDY` |
| **ADMH** | 1 row / history term | `MHTERM`, `MHBODSYS`, `MHSTDY` |

**Join key:** `USUBJID` (always start from `ADSL`)

## Industry conventions for MDR safety analyses

What medical reviewers expect in pharma/biotech — and how this repo implements them:

| Analysis | Industry rule | This repo |
|----------|---------------|-----------|
| Analysis population | Define flag in SAP/MDRP (e.g. `SAFFL == "Y"`) before any table | `safety_adsl()` in `R/load_data.R` |
| TEAE | `TRTEMFL == "Y"` per ADaM IG | `.teae()` in `R/ae_analysis.R` |
| AE tables | Subject incidence n/N (%), not event counts | `distinct(USUBJID)` in overview and SOC/PT tables |
| MedDRA display | SOC → PT hierarchy | `AEBODSYS` → `AEDECOD` in `soc_pt_table()` |
| SAE review | Patient-level listing with PT, severity, outcome | `sae_listing()` — AEL03-style |
| Lab catalogue | All ADLB `PARAMCD` values grouped by `LBCAT` for selectors | `lab_param_catalog()` — S6/S7/S9 |
| Lab shifts | Baseline normal indicator → worst post-baseline | `lab_shift_table()` — LBT04 |
| DILI screen | Max post-baseline ALT and bilirubin vs ULN; Hy's Law zone | `hys_law_plot()` — eDISH |
| Drill-down | Link aggregate signal to one subject | Patient Profile tab — IPPG01 |
| Standards | FDA ST&F Integrated Guide; pharmaverse TLG catalog | Mapped in `config/study_config.yml` |

## Safety signal methods

| Method | Formula / logic | Use case |
|--------|-----------------|----------|
| TEAE filter | `TRTEMFL == "Y"` | Post-treatment events only |
| Event count | `n()` per `ARM` × `AEDECOD` | Volume comparison |
| Subject incidence | `n_distinct(USUBJID)` / `n subjects in arm` | Primary safety table |
| Lab shift | baseline `BNRIND` → worst post-baseline `ANRIND` | Hepatotoxicity / renal monitoring (FDA LBT04) |
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
| Best for | Regulated standard templates | Custom UX, explicit analysis logic |
| This repo | teal (production option) | [`app.R`](../app.R) + [`R/`](../R/) helpers |

