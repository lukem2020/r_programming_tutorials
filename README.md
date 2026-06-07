# MDR Safety Dashboard (CDISCPILOT01)

A Shiny medical-data-review dashboard built on CDISC ADaM data, structured to the
FDA Standard Safety Tables & Figures (ST&F) Integrated Guide and the pharmaverse TLG Catalog.

### Built with

![R](https://img.shields.io/badge/R-4.6.0-276DC3?style=flat-square&logo=r&logoColor=white)
![renv](https://img.shields.io/badge/renv-reproducible-1f2d3d?style=flat-square)
![shiny](https://img.shields.io/badge/shiny-1.13.0-447099?style=flat-square&logo=posit&logoColor=white)
![DT](https://img.shields.io/badge/DT-0.34.0-1f6fb2?style=flat-square)
![ggplot2](https://img.shields.io/badge/ggplot2-4.0.3-1f6fb2?style=flat-square)
![scales](https://img.shields.io/badge/scales-1.4.0-4c9be8?style=flat-square)
![dplyr](https://img.shields.io/badge/dplyr-1.2.1-1f6fb2?style=flat-square)
![tidyr](https://img.shields.io/badge/tidyr-1.3.2-1f6fb2?style=flat-square)
![survival](https://img.shields.io/badge/survival-base%20R-5b6770?style=flat-square)
![yaml](https://img.shields.io/badge/yaml-2.3.12-6c757d?style=flat-square)
![pharmaverseadam](https://img.shields.io/badge/pharmaverseadam-1.3.0-e8694c?style=flat-square)

---

## Study summary

The dashboard uses the **CDISCPILOT01** study — the publicly available CDISC pilot
dataset (synthetic, sourced via `pharmaverseadam`).

- **Trial:** *A Phase III Study of Xanomeline in Alzheimer's Disease* (CDISCPILOT01)
- **Drug under study:** **Xanomeline**, a muscarinic (M1/M4) acetylcholine-receptor
  agonist, delivered as a **transdermal patch** (transdermal therapeutic system, TTS).
- **Purpose / indication:** treatment of **mild-to-moderate Alzheimer's disease** —
  the muscarinic agonism is intended to improve cognitive and behavioural symptoms.
- **Treatment arms:** Placebo, Xanomeline Low Dose, Xanomeline High Dose.
- **Population:** elderly subjects (mean age ~75); **306 enrolled, 254 in the safety
  population** (`SAFFL == "Y"`).

### What this dashboard measures

It is a **safety / medical-data-review** view (not efficacy). Because the drug is a
skin patch, **tolerability at the application site** is a primary safety question.

| Domain | What we look at | Data |
|---|---|---|
| Demographics & disposition | Who was treated and how they exited the study | ADSL |
| Adverse events | TEAE incidence, serious AEs, by SOC / preferred term | ADAE |
| Application-site / skin reactions | The patch tolerability signal (incidence + time-to-event) | ADAE / ADTTE |
| Laboratory safety | Liver chemistry central tendency, shifts, Hy's Law / eDISH | ADLB |
| Patient drill-down | Individual subject profile linking signals to a person | ADSL + ADAE + ADLB |

**Headline finding:** the Xanomeline patch arms show a clear, early excess of
**application-site / dermatologic reactions** versus placebo (visualised as a
Kaplan-Meier curve), while liver chemistry shows **no Hy's Law cases** — a tolerability
signal at the skin rather than a hepatic safety concern.

---

- App entry point: `app.R` (sources `R/`, reads `config/study_config.yml` + `data/adam/`)
- Analysis code: `R/`  |  Run-scripts: `programs/`  |  Config: `config/study_config.yml`

---

## Quick commands

All commands assume you are in the project root and that `R` / `Rscript` are on your `PATH`.
(If not, on Windows add e.g. `export PATH="/c/Program Files/R/R-4.6.0/bin:$PATH"` to `~/.bashrc`.)

### Environment (renv)

```bash
# Restore the exact package versions from renv.lock
Rscript -e 'renv::restore(prompt = FALSE)'

# Check whether the library is in sync with renv.lock
Rscript -e 'renv::status()'

# After installing/updating packages, snapshot them into renv.lock
Rscript -e 'renv::snapshot(prompt = FALSE)'
```

### Prepare data (ADaM)

```bash
# 1. Build ADSL / ADAE / ADLB into data/adam/ (from pharmaverseadam)
Rscript programs/01_prepare_adam.R

# 2. Derive the time-to-event dataset ADTTE (Time to First Dermatologic Event)
Rscript programs/02_derive_adtte.R
```

### Run the app

```bash
# Launch locally (opens a browser)
Rscript -e 'shiny::runApp(".")'

# Launch on a fixed port without opening a browser (e.g. for remote/preview)
Rscript -e 'shiny::runApp(".", port = 7900, launch.browser = FALSE)'

# Quick health check while the app is running (separate terminal)
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:7900/
```

### Smoke-test the analysis helpers (no app)

```bash
# Source every helper and confirm each function/plot builds against the data
Rscript -e 'invisible(lapply(list.files("R", full.names = TRUE), source)); \
  st <- load_study_data("."); cat("ADaM loaded OK; ADTTE rows:", nrow(st$ADTTE), "\n")'
```

### Deploy

```bash
# Public demo link (shinyapps.io) - configure rsconnect once, then:
Rscript -e 'rsconnect::deployApp(appDir = ".", \
  appFiles = c("app.R", "R/", "config/", "data/adam/"))'
```

### Inspect the data (Python notebook)

```bash
# Open the ADaM viewer notebook
jupyter lab notebooks/adam_viewer.ipynb
```
