# Interview Guide — Real-time Visual Analytics Specialist

Use this guide to run a **5-minute demo** and handle mixed-format (concepts + coding) questions.

## 30-second opener

> "I build standardized, interactive study dashboards for Medical Data Review and safety signal detection. My work aligns with RBQM principles — I focus visualizations on Critical to Quality factors like safety reporting, lab monitoring, and analysis population integrity. I deliver in R Shiny and teal, with version-controlled templates and reproducible environments."

## 5-minute demo script

### Before the interview

```bash
# From project root (after R is installed)
Rscript scripts/setup_env.R
Rscript R/data_generation.R
```

In R:

```r
shiny::runApp("app")                          # teal version (preferred)
# shiny::runApp("app/app_shiny_fallback.R")   # if teal install fails
```

### Minute 1 — Context

1. Open the app: **"Study ABC123 — Medical Data Review Dashboard"**
2. Say: "This supports early-phase MDR — demographics, TEAE safety, labs, and patient drill-down on synthetic CDISC ADaM data."

### Minute 2 — Population filters (RBQM / CtQ)

1. Use filter panel (teal) or sidebar (fallback): **Safety Population = Y**, optionally filter by arm
2. Say: "Filters enforce the correct analysis population before any safety summaries — this maps to CtQ eligibility and safety reporting factors."

### Minute 3 — Safety signal

1. Open **Adverse Events** / Safety Signals tab
2. Point out TEAE incidence by arm
3. Say: "I use subject incidence, not just event counts. A higher rate on Drug 10mg for GI events or ALT elevation would trigger medical review per the MDRP."

### Minute 4 — Lab monitoring

1. Open **Lab Values** / Lab Shifts tab
2. Highlight normal-to-abnormal shifts (especially ALT/AST)
3. Say: "Lab shift views support hepatotoxicity monitoring — a defined CtQ factor in early development."

### Minute 5 — Patient drill-down + GitHub

1. Open **Patient Profile**, select a subject with TEAEs
2. Say: "MDR is iterative — population signal, then individual patient context."
3. Switch to GitHub repo structure:
   - `R/data_generation.R` — reproducible synthetic data
   - `R/data_prep.R` — tidyverse safety methods
   - `app/app.R` — teal dashboard template
   - `tutorials/` — documented methods

## Module → CtQ mapping

| App module | CtQ factor | MDR purpose |
|------------|------------|-------------|
| Demographics | Eligibility / population integrity | Confirm correct analysis set |
| Adverse Events | Safety reporting | Detect treatment-emergent signals |
| Lab line plots / shifts | Safety / lab monitoring | Catch clinically relevant lab changes |
| Patient profile | Traceability | Link aggregate findings to subject records |
| Filter panel | Analysis population control | RBQM-focused review scope |

## Likely questions & prepared answers

### "What is MDR vs SDV?"

**MDR (Medical Data Review)** is clinician-led review of study data to assess safety and efficacy signals during the trial. **SDV (Source Data Verification)** is comparing CRF/eCRF entries against source documents. Visual analytics supports MDR with interactive, aggregate views; SDV is a separate quality activity. Under RBQM, SDV is targeted — not 100% — while centralized monitoring and MDR dashboards cover cross-site patterns.

### "What is RBQM and how does your work fit?"

RBQM (Risk-Based Quality Management) focuses trial oversight on activities essential to subject safety and result reliability. I align dashboards to **CtQ factors** defined in the study quality plan — safety reporting, endpoint integrity, lab monitoring. My templates surface those factors, not every variable in the database.

### "What are CtQ factors?"

Critical to Quality factors are study attributes that, if wrong, would undermine participant safety or result credibility. Examples: correct informed consent, accurate AE reporting, proper randomization, lab monitoring for hepatotoxicity. I map each dashboard module to a CtQ factor so reviewers know *why* each view exists.

### "How does this support FPI timelines?"

Dashboards are templated before study start. Data generation and module configs use standard ADaM structures, so when first patient data arrives, we plug in real ADSL/ADAE/ADLB and QC — not build from scratch. `renv.lock` and Git ensure the same app runs consistently across environments.

### "How do you ensure traceability?"

- Git version control for all template code
- `renv` for reproducible package versions
- Fixed `set.seed()` for deterministic test data
- Separated data / prep / app layers for QC
- teal's reproducible code export (where enabled)
- Peer review before production deployment

### "Explain reactive() / how teal filtering works"

In Shiny, `reactive()` recomputes when inputs change — e.g., when the user selects a treatment arm, filtered datasets rebuild. In teal, the **filter panel** applies slices at the data layer shared by all modules, so demographics, AEs, and labs stay synchronized. This prevents inconsistent subsets across tabs — a common MDR requirement.

### "Why teal instead of raw Shiny?"

Teal provides pre-validated clinical modules (AE tables, KM plots, patient profiles), CDISC data handling, and cross-module filtering. Raw Shiny offers more UI flexibility. In a regulated biometrics team, teal accelerates standardized delivery; I keep a Shiny fallback to prove I understand the underlying patterns.

### "Tell me about a safety signal you'd investigate"

"If TEAE incidence for 'Alanine aminotransferase increased' is higher on Drug 10mg and lab shifts show normal-to-high ALT transitions, I'd filter to the safety population, confirm the signal across visits, drill into affected patients, and escalate per the MDRP — checking exposure, concomitant meds, and AE relationship flags."


Say: "I'd use feature branches per study template update, PRs for peer review, and tagged releases for production deployments."

## If asked to live-code

Open `R/data_prep.R` or `tutorials/02_safety_signal_methods.Rmd` and be ready to:

- Join `ADAE` to `ADSL` on `USUBJID`
- Filter `TRTEMFL == "Y"`
- Compute `count(ARM, AEDECOD)` or subject incidence
- Explain lab shift logic

## Day-before checklist

- [ ] R installed (>= 4.1)
- [ ] `Rscript scripts/setup_env.R` completed
- [ ] `Rscript R/data_generation.R` completed
- [ ] App launches locally (teal or fallback)
- [ ] Read `docs/methods_cheatsheet.md`
- [ ] Practice 5-minute demo twice
- [ ] Optional: screenshot the app for README
