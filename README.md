# MDR Safety Dashboard (CDISCPILOT01)

A Shiny medical-data-review dashboard built on CDISC ADaM data, structured to the
FDA Standard Safety Tables & Figures (ST&F) Integrated Guide and the pharmaverse TLG Catalog.

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
