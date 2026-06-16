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
| Treatment exposure | Duration summary (`TRTDURD`) and record-level exposure | ADSL + ADEX |
| Adverse events | TEAE overview, SAE listing, SOC/PT, severity (AET03) | ADAE |
| Application-site / skin reactions | Patch tolerability (incidence + Kaplan-Meier) | ADAE / ADTTE |
| Laboratory safety | Central tendency (AVAL/CHG), shifts, Hy's Law / eDISH | ADLB |
| Vital signs | Central tendency over visits | ADVS |
| Concomitant medications | On-treatment CM summary and listing | ADCM |
| Patient drill-down | Demographics, AEs, labs, vitals, CM, medical history | ADSL + ADAE + ADLB + ADVS + ADCM + ADMH |

**Headline finding:** the Xanomeline patch arms show a clear, early excess of
**application-site / dermatologic reactions** versus placebo (visualised as a
Kaplan-Meier curve), while liver chemistry shows **no Hy's Law cases** — a tolerability
signal at the skin rather than a hepatic safety concern.

---

- App entry points:
  - **TLG Catalog (teal):** `app_teal/app.R` — full catalog navigation with `teal` / `tern` modules
  - **Legacy ggplot2 dashboard:** `app.R` — original ST&F views for validation
- Analysis code: `R/`  |  Run-scripts: `programs/`  |  Config: `config/study_config.yml`, `config/tlg_registry.yml`

---

## Quick commands

All commands assume you are in the project root and that `R` / `Rscript` are on your `PATH`.
(If not, on Windows add e.g. `export PATH="/c/Program Files/R/R-4.6.0/bin:$PATH"` to `~/.bashrc`.)

### Environment (renv)

```bash
# Restore the exact package versions from renv.lock
Rscript -e 'renv::restore(prompt = FALSE)'

# On Windows, disable the renv sandbox only when installing packages or snapshotting:
export RENV_CONFIG_SANDBOX_ENABLED=FALSE

# Check whether the library is in sync with renv.lock
Rscript -e 'renv::status()'

# After installing/updating packages, snapshot them into renv.lock
Rscript -e 'renv::snapshot(prompt = FALSE)'
```

### Prepare data (ADaM)

```bash
# 1. Build ADaM domains into data/adam/ (from pharmaverseadam)
Rscript programs/01_prepare_adam.R

# 2. Derive ADTTE (Time to First Dermatologic Event)
Rscript programs/02_derive_adtte.R

# 3. Prepare teal-ready ADaM (tern explicit NA, AE flags, optional domains)
Rscript programs/04_prepare_teal_adam.R

# Optional: verify datasets and smoke-test helpers
Rscript programs/00_verify_adam.R
Rscript programs/03_smoke_test.R
Rscript programs/05_smoke_test_teal.R
```

### Run the TLG Catalog app (teal)

Use the launcher — it isolates the project `renv` library so a broken system `bslib` (e.g. under `C:/R/library`) cannot shadow packages:

```bash
# Recommended (no extra env vars needed for normal runs)
Rscript run_app_teal.R

# Fixed port, no browser (remote / CI)
Rscript run_app_teal.R 7900
```

Only set `RENV_CONFIG_SANDBOX_ENABLED=FALSE` when **installing** or **snapshotting** packages, not when starting the app.

### Run the legacy dashboard

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
Rscript programs/03_smoke_test.R
```

### Deploy (shinyapps.io)

Prepare teal data, then deploy the TLG Catalog app (`app_teal/`):

```bash
# 1. Copy the template and add your account / token / secret
cp config/deploy.example.yml config/deploy.yml
# Edit config/deploy.yml (file is gitignored — do not commit secrets)
# Set deploy.app: teal  and  shinyapps.app_name: xanomeline-tlg-teal

# 2. Prepare ADaM + registry artifacts bundled with the app
Rscript programs/04_prepare_teal_adam.R

# 3. Deploy (runs programs/05_smoke_test_teal.R first)
Rscript deploy_app.R
```

To deploy the legacy MDR Safety Dashboard instead, set `deploy.app: legacy` and a distinct `shinyapps.app_name` in `config/deploy.yml`.

Public URL: `https://<account>.shinyapps.io/<app_name>/`

**Note:** The teal app loads ~22 modules and trimmed ADaM (~83k ADLB rows). Use a shinyapps.io instance size with sufficient memory (Starter or higher).

### Inspect the data (Python notebook)

```bash
# Open the ADaM viewer notebook
jupyter lab notebooks/adam_viewer.ipynb
```
