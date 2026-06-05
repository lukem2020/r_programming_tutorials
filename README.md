# Clinical Visual Analytics — MDR Interview Tutorial

Portfolio tutorial for a **Real-time Visual Analytics Specialist** role: interactive Medical Data Review (MDR) dashboards, safety signal methods, and RBQM-aligned workflows using R, Shiny, and teal.

Built around synthetic **CDISC ADaM** data (Study ABC123) with reproducible scripts, runnable apps, and interview preparation materials.

## What this demonstrates

| Job skill | Where in repo |
|-----------|---------------|
| R + tidyverse | `R/data_prep.R`, `tutorials/01-02` |
| R Shiny | `app/app_shiny_fallback.R` |
| R Teal | `app/app.R` |
| Clinical data (ADSL/ADAE/ADLB) | `R/data_generation.R`, `data/simulated/` |
| Safety signal detection | `tutorials/02_safety_signal_methods.Rmd` |
| MDR patient drill-down | Both apps, Patient Profile module |
| RBQM / CtQ alignment | `docs/interview_guide.md`, `docs/methods_cheatsheet.md` |
| Git + traceability | Repo structure, `renv`, fixed seed data generation |

## Prerequisites

- **R >= 4.1** ([download](https://cloud.r-project.org/))
- **RStudio** (recommended) or any R console
- Internet access for first-time package install

## Quick start (first time — no env yet)

Open R in the **project root** and run:

```r
source("scripts/setup_env.R")
```

Or from terminal:

```bash
Rscript scripts/setup_env.R
```

This initializes `renv`, installs core packages, and attempts the teal ecosystem install.

## Generate study data

```bash
Rscript R/data_generation.R
```

Creates `data/simulated/ADSL.rds`, `ADAE.rds`, `ADLB.rds` (~80 subjects, 2 arms).

## Run the dashboard

**Primary (teal):**

```r
shiny::runApp("app")
```

**Fallback (pure Shiny — use if teal install fails):**

```r
shiny::runApp("app/app_shiny_fallback.R")
```

## 2-minute demo script

1. Open app → introduce Study ABC123 MDR dashboard
2. Filter to **Safety Population** and optionally one treatment arm
3. Show **Adverse Events** — TEAE incidence by arm
4. Show **Lab Values** — trends and shift patterns (ALT/AST)
5. Open **Patient Profile** — drill into one subject
6. Mention Git repo structure: data → prep → app, version-controlled templates

Full script: [docs/interview_guide.md](docs/interview_guide.md)

## Project structure

```
├── app/
│   ├── app.R                    # teal MDR dashboard (primary)
│   └── app_shiny_fallback.R     # Shiny fallback
├── data/simulated/              # Generated ADSL, ADAE, ADLB (.rds)
├── docs/
│   ├── context_file.md          # Job description
│   ├── interview_guide.md       # Demo script + Q&A
│   └── methods_cheatsheet.md    # RBQM, CDISC, MDR glossary
├── R/
│   ├── data_generation.R        # Synthetic CDISC-like data
│   ├── data_prep.R              # Safety signal helper functions
│   └── theme_clinical.R         # Consistent plot styling
├── scripts/
│   └── setup_env.R              # First-time renv + package setup
└── tutorials/
    ├── 01_clinical_data_basics.Rmd
    ├── 02_safety_signal_methods.Rmd
    └── 03_teal_mdr_dashboard.Rmd
```

## Tutorials (study before interview)

| # | Topic | Time |
|---|-------|------|
| 01 | CDISC data structures, CRF → ADaM | ~45 min |
| 02 | TEAE, lab shifts, patient profiles | ~60 min |
| 03 | teal app architecture | ~45 min |

## Interview prep

- **Demo script & Q&A:** [docs/interview_guide.md](docs/interview_guide.md)
- **One-page methods reference:** [docs/methods_cheatsheet.md](docs/methods_cheatsheet.md)
- **Job context:** [docs/context_file.md](docs/context_file.md)

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `R` not found | Install R from [cloud.r-project.org](https://cloud.r-project.org/) and restart terminal |
| teal install fails | Use `shiny::runApp("app/app_shiny_fallback.R")` — same MDR workflow |
| Data not found | Run `Rscript R/data_generation.R` first |
| Package conflicts | `renv::restore()` from project root |

## License

MIT — see [LICENSE](LICENSE).
