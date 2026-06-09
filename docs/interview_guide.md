# Interview Guide — Real-time Visual Analytics Specialist

Use this guide to run a **5-minute demo** (or **7-minute deep dive**) and handle mixed-format (concepts + coding) questions.

For RBQM terminology and signal methods, see [methods_cheatsheet.md](methods_cheatsheet.md).

## Industry alignment — what medical reviewers expect

Medical Data Review (MDR) dashboards in early-development biometrics are **not exploratory data-science notebooks**. Reviewers (physicians, pharmacovigilance, clinical scientists) expect outputs that mirror what they see in CSRs, DSURs, and the **FDA Standard Safety Tables & Figures (ST&F) Integrated Guide** — delivered interactively so they can filter, drill down, and iterate.

| Industry expectation | How this dashboard meets it |
|---------------------|----------------------------|
| Correct analysis population before any summary | Safety population (`SAFFL == "Y"`) enforced in every helper via `safety_adsl()` |
| TEAE definition aligned to ADaM | `TRTEMFL == "Y"` in `.teae()` — post-treatment events only |
| Subject incidence, not event counts | `distinct(USUBJID)` then n/N (%) — AET01/AET02 convention |
| MedDRA hierarchy preserved | SOC (`AEBODSYS`) → PT (`AEDECOD`) in SOC/PT table |
| SAE review at patient level | Searchable SAE listing (AEL03-style) with severity and outcome |
| Lab monitoring triad | Central tendency (LBT01), shift table (LBT04), Hy's Law eDISH (LBT09–11) |
| Population signal → subject validation | KM / TEAE tables first; Patient Profile (IPPG01) for drill-down |
| Traceable, QC-able programming | Logic in `R/*.R`, config in YAML, data build in `programs/` — not buried in UI |
| Mapped to review plan scope | Each section (S1–S10) traces to an MDRP-style review item and TLG catalog code |

**What reviewers typically do *not* expect from an MDR dashboard:** formal hypothesis tests on AE incidence tables (descriptive n/N only); p-values are appropriate for time-to-event (log-rank) but AE tables stay exploratory.

### MDR review sequence → dashboard tabs

This mirrors the subprocess medical reviewers follow (see [pipeline_overview.md](pipeline_overview.md) §5):

1. **Scope population** — header shows Safety N; all tabs use `SAFFL == "Y"`
2. **Context** — Demographics (S1) + Disposition (S2)
3. **Population safety scan** — AE Overview (S3–S4) → TEAE Table (S5) → Lab Trends/Shifts/Hy's Law (S6–S8)
4. **Signal quantification** — Time-to-Event KM (S10) for tolerability onset
5. **Patient validation** — Patient Profile (S9)
6. **Document / escalate** — findings recorded per study governance (outside the app)

### Teal-equivalent scope (implemented)

The dashboard replicates the standard **teal.modules.clinical** safety module set on CDISCPILOT01 ADaM from `pharmaverseadam`:

| Module | Section | Status |
|--------|---------|--------|
| Exposure (`tm_t_exposure`) | S11 | ADSL `TRTDURD` + ADEX detail |
| TEAE by severity (`tm_t_events_by_grade`) | S5b | AET03 table |
| Lab CHG from baseline | S6 toggle | AVAL or CHG |
| Vital signs | S12 | ADVS line plots |
| Concomitant meds | S13 | ADCM summary + listing |
| Arm filter panel | Sidebar | Safety pop fixed; arms selectable |

Optional future additions: ECG (`ADEG`), SMQ tables, patient-year event rates — not typical in a first-pass MDR teal app.

## 30-second opener

> "I build standardized, interactive study dashboards for Medical Data Review and safety signal detection. My work aligns with RBQM principles — I focus visualizations on Critical to Quality factors like safety reporting, lab monitoring, and analysis population integrity. This dashboard covers ten FDA ST&F-aligned sections on CDISC ADaM data, delivered in R Shiny with version-controlled templates and a reproducible `renv` environment."

## Analysis catalogue (S1–S10)

Every section below is already in the app. Use this table to articulate the **breadth of analyses** — not just the tabs you happen to click during a demo.

| Section | Tab | Dataset | FDA ST&F | TLG ref | Analysis method | Key function | One-line talk-track |
|---------|-----|---------|----------|---------|-----------------|--------------|---------------------|
| S1 | Demographics | ADSL | General | DMT01 | Mean (SD) age; n (%) sex/race by arm | `demographics_table()` | "Confirm the safety population is balanced before reading any AE or lab signal." |
| S2 | Demographics | ADSL | General | DST01 | Disposition n (%) by EOSSTT | `disposition_table()` | "Who completed, withdrew, or discontinued — context for exposure and follow-up." |
| S3 | AE Overview | ADAE | AE Analyses | AET01 | Subject incidence for any / serious / severe / related TEAE | `ae_overview_table()` | "Subject incidence, not event counts — the FDA-standard safety summary." |
| S4 | AE Overview | ADAE | SAE | AEL03 | SAE listing with PT, SOC, severity, outcome | `sae_listing()` | "Searchable listing for medical review of individual serious events." |
| S5 | TEAE Table | ADAE | TEAE | AET02 | Top-N subject-incidence bar chart + SOC → PT counts | `teae_top_plot()`, `soc_pt_table()` | "MedDRA hierarchy — SOC rolls up to preferred terms; patch reactions dominate here." |
| S6 | Lab Trends | ADLB | Lab — change over time | LBT01 / LTG01 | Mean ± SD over visits vs ULN; all PARAMCD values by LBCAT | `lab_param_catalog()`, `lab_central_tendency_plot()` | "Full ADLB catalogue — chemistry, haematology, urinalysis; default ALT for hepatotoxicity." |
| S7 | Lab Shifts | ADLB | Lab — abnormalities | LBT04 | Baseline BNRIND → worst post-baseline ANRIND (params with shift flags) | `lab_shift_table()` | "Normal-to-high shifts flag subjects needing individual review." |
| S8 | Hy's Law | ADLB | Lab — DILI | LBT09–11 | eDISH scatter: max ALT × ULN vs max bilirubin × ULN | `hys_law_plot()` | "DILI screen — no subjects in the Hy's Law zone for this study." |
| S9 | Patient Profile | ADSL + ADAE + ADLB | AE (narratives) | IPPG01 | Demographics + lab listing + panel trend plots (hepatic, chemistry, haem, etc.) | `patient_lab_table()`, `patient_lab_panel_trend_plot()` | "Population signal first, then one subject's full context for validation." |
| S10 | Time-to-Event | ADTTE | AE — time-to-event | KMG01 + TTET01 | Kaplan-Meier + log-rank + median table | `km_plot()`, `km_median_table()` | "Patch arms separate early from placebo — tolerability as a time-to-event endpoint." |
| S11 | Demographics | ADSL + ADEX | General | EXSUM | TRTDURD summary + ADEX record detail | `exposure_*()` | "Exposure context before interpreting AE rates." |
| S5b | TEAE Table | ADAE | TEAE | AET03 | SOC/PT × severity (worst grade per subject) | `teae_severity_table()` | "Full AET03 severity stratification, not just a severe row in overview." |
| S12 | Vital Signs | ADVS | VS | VST01 | Mean ± SD over visits | `vs_central_tendency_plot()` | "Standard vitals monitoring alongside labs." |
| S13 | Concomitant Meds | ADCM | CM | CM01 | On-treatment CM summary + listing | `cm_*()` | "Review concomitant therapy during treatment (`ONTRTFL`)." |

Source of truth: `config/study_config.yml` (`safety_review_sections`) and `R/*.R`.

## 5-minute demo script

### Before the interview

```bash
# From project root (after R is installed)
Rscript -e 'renv::restore(prompt = FALSE)'
Rscript programs/01_prepare_adam.R
Rscript programs/02_derive_adtte.R
Rscript -e 'shiny::runApp(".")'
```

### Minute 1 — Context

1. Open the app: **"Medical Data Review – Safety Dashboard"** (CDISCPILOT01)
2. Point to the header: **Safety N = 254**, FDA ST&F Integrated Guide (Aug 2022)
3. Say: "Phase III Xanomeline transdermal patch in Alzheimer's — a safety MDR dashboard on public CDISC ADaM data. Every tab maps to an FDA ST&F section and a pharmaverse TLG reference, driven by `config/study_config.yml`."

### Minute 2 — Population integrity (S1 / S2)

1. Open **Demographics** tab
2. Show demographics table (S1) and disposition table (S2)
3. Say: "All summaries use the safety population (`SAFFL == 'Y'`) enforced upstream in `R/load_data.R` — this is the CtQ factor for analysis population integrity. Demographics confirm balance; disposition shows who completed or withdrew."

### Minute 3 — TEAE safety (S3–S5)

1. Open **AE Overview** — subject incidence rows (any / serious / severe / related TEAE)
2. Open **TEAE Table** — top-N bar chart and SOC → PT table
3. Say: "Subject incidence, not event counts — that's the AET01/AET02 convention medical reviewers expect in CSRs and DSURs. Application-site reactions are the headline tolerability signal for a transdermal patch — visible in the SOC/PT breakdown by arm."

### Minute 4 — Laboratory safety (S6–S8)

1. Open **Lab Trends** — browse parameters by LBCAT (chemistry, haematology, urinalysis); default ALT; note mean ± SD vs ULN dashed line
2. Open **Lab Shifts** — baseline-to-worst post-baseline shift counts
3. Open **Hy's Law** — eDISH scatter; no flagged subjects
4. Say: "Three complementary lab views the FDA ST&F expects for hepatic safety: central tendency over time (LBT01), categorical shift tables (LBT04), and the DILI eDISH screen. No Hy's Law cases — the safety story here is skin tolerability, not hepatotoxicity."

### Minute 5 — Time-to-event + drill-down + repo (S10 / S9)

1. Open **Time-to-Event** — Kaplan-Meier curve; note log-rank p-value and patch-arm separation
2. Open **Patient Profile** — search a subject from an active arm; show AE timeline
3. Say: "MDR is iterative — population KM signal, then individual patient context."
4. Switch to GitHub repo structure:
   - `config/study_config.yml` — study metadata, CtQ mapping, TLG refs
   - `programs/` — ADaM build and ADTTE derivation
   - `R/` — analysis helpers (`ae_analysis.R`, `lab_analysis.R`, `tte_analysis.R`)
   - `app.R` — Shiny UI wiring

## 7-minute "analysis depth" demo (follow-up)

Use this version when interviewers want to hear **more about the methods**. Same tab order, but pause on specifics:

| Pause point | What to show | What to say |
|-------------|--------------|-------------|
| S3 rows | AE Overview table | "Four incidence categories — any, serious, severe, and **related** TEAE. Relatedness uses `AEREL != 'NONE'` in this study's coding." |
| S5 dual view | TEAE bar chart + SOC/PT table | "Bar chart for the top ten PTs by overall incidence; table preserves the MedDRA SOC → PT hierarchy for full review." |
| S7 shifts | Lab Shifts tab (ALT) | "Worst post-baseline abnormality per subject — Normal→High transitions are the actionable rows." |
| S10 KM | Time-to-Event tab | "Derived ADTTE endpoint: first treatment-emergent application-site or skin SOC event. Subjects without an event are censored at `TRTDURD`. Log-rank tests arm separation." |
| S9 profile | Patient Profile tab | "Pick a subject from a patch arm — confirm application-site events are treatment-emergent and temporally consistent with the population KM signal." |

## Prepared answer: "What types of analyses does your dashboard include?"

> "Ten FDA ST&F-aligned sections on CDISC ADaM: demographics and disposition; TEAE overview with subject incidence and SAE listing; SOC/PT TEAE tables; laboratory central tendency, shift tables, and Hy's Law eDISH; a derived time-to-event Kaplan-Meier for patch tolerability; and patient-level drill-down. Each maps to a CtQ factor in the config and a TLG catalog reference — DMT01, AET02, LBT04, KMG01, IPPG01, and others. The analysis logic lives in separated R helpers, not embedded in the Shiny UI, so each method is independently testable and QC-able."

**If they push for more:** "The dashboard now covers the standard teal safety module set — exposure, AET03 severity, lab CHG, vitals, and con meds. Optional extensions would be ECG (`ADEG`), SMQ tables, or efficacy modules — scoped per study MDRP."

### "How do you know these are the right analyses for medical review?"

"I scope modules from the **Medical Data Review Plan** and **CtQ register**, then implement against the **FDA ST&F Integrated Guide** and **pharmaverse TLG catalog** so medical reviewers see familiar table structures — AET01 overview, AET02 SOC/PT, LBT04 shifts, eDISH, patient profiles. The ADaM IG defines the variables (`TRTEMFL`, `BNRIND`, `ANRIND`, population flags). I don't invent custom metrics; I standardise industry conventions in interactive form."

### "What's the difference between your dashboard and CSR safety tables?"

"Same analysis logic and population rules — subject incidence, TEAE filter, worst post-baseline for shifts. The dashboard adds interactivity: parameter selection, subject search, and linked drill-down. Static TLFs in the CSR are the locked snapshot; the dashboard supports **ongoing review** between data cuts. Both should reconcile if they use the same ADaM and programming specs."

## Module → CtQ mapping

| Section | App tab | CtQ factor | MDR purpose |
|---------|---------|------------|-------------|
| S1 | Demographics | Analysis population integrity | Confirm correct analysis set |
| S2 | Demographics | Analysis population integrity | Understand disposition / follow-up |
| S3–S5 | AE Overview / TEAE Table | Safety reporting accuracy | Detect treatment-emergent signals |
| S6–S8 | Lab Trends / Shifts / Hy's Law | Laboratory monitoring integrity | Catch clinically relevant lab changes |
| S9 | Patient Profile | Traceability | Link aggregate findings to subject records |
| S10 | Time-to-Event | Safety reporting (tolerability) | Quantify time to first dermatologic event |

## Likely questions & prepared answers

### "What is MDR vs SDV?"

**MDR (Medical Data Review)** is clinician-led review of study data to assess safety and efficacy signals during the trial. **SDV (Source Data Verification)** is comparing CRF/eCRF entries against source documents. Visual analytics supports MDR with interactive, aggregate views; SDV is a separate quality activity. Under RBQM, SDV is targeted — not 100% — while centralized monitoring and MDR dashboards cover cross-site patterns.

### "What is RBQM and how does your work fit?"

RBQM (Risk-Based Quality Management) focuses trial oversight on activities essential to subject safety and result reliability. I align dashboards to **CtQ factors** defined in the study quality plan — safety reporting, endpoint integrity, lab monitoring. My templates surface those factors, not every variable in the database.

### "What are CtQ factors?"

Critical to Quality factors are study attributes that, if wrong, would undermine participant safety or result credibility. Examples: correct informed consent, accurate AE reporting, proper randomization, lab monitoring for hepatotoxicity. I map each dashboard section to a CtQ factor in `study_config.yml` so reviewers know *why* each view exists.

### "How does this support FPI timelines?"

Dashboards are templated before study start. Module configs use standard ADaM structures, so when first patient data arrives, we plug in real ADSL/ADAE/ADLB and QC — not build from scratch. `renv.lock` and Git ensure the same app runs consistently across environments.

### "How do you ensure traceability?"

- Git version control for all template code
- `renv` for reproducible package versions (`renv.lock`)
- `config/study_config.yml` as single source of truth for study metadata and section mapping
- Separated layers: `programs/` (data build) → `R/` (analysis helpers) → `app.R` (UI)
- Peer review via pull requests before production deployment

### "Explain reactive() / how Shiny updates work"

In this app, `renderDT()` and `renderPlot()` re-run when inputs change — e.g., selecting any ADLB parameter on **Lab Trends** rebuilds the central-tendency plot; choosing a subject on **Patient Profile** refreshes the AE timeline, selected lab trace, and hepatic panel. All analysis helpers enforce the safety population (`SAFFL == "Y"`) upstream in `safety_adsl()`, so every tab stays on the same analysis set without a separate filter panel.

### "Why raw Shiny instead of teal?"

Teal provides pre-validated clinical modules (AE tables, KM plots, patient profiles), CDISC data handling, and cross-module filtering — ideal for regulated, standardised delivery. This repo uses raw Shiny to show I understand the underlying patterns: TEAE filtering, subject incidence, lab shifts, and Kaplan-Meier logic are implemented explicitly in `R/`. In production I'd reach for teal where the team standardises on it; the analysis methods transfer directly.

### "Tell me about a safety signal you'd investigate"

"In this study, the Xanomeline patch arms show an early excess of application-site and dermatologic TEAEs versus placebo — visible in the SOC/PT table and as arm separation on the Kaplan-Meier curve. I'd confirm the signal in the safety population, check severity and relatedness in the AE Overview, rule out a hepatic concern via lab shifts and Hy's Law, then drill into individual subjects on the Patient Profile — checking treatment duration (`TRTDURD`), AE relationship flags, and temporal pattern — before escalating per the MDRP."

### "How do you use Git in this workflow?"

"I'd use feature branches per study template update, pull requests for peer review, and tagged releases for production deployments. Analysis helpers and config changes are reviewed separately from UI changes so QC can trace any table back to its R function."

## If asked to live-code

Open `R/ae_analysis.R` or `R/lab_analysis.R` and be ready to:

- Walk through `.teae()` — filter `TRTEMFL == "Y"` and restrict to safety-population `USUBJID`s
- Compute subject incidence: `distinct(ARM, USUBJID, AEDECOD)` then `count()` per arm
- Explain `lab_shift_table()` — baseline `BNRIND` vs worst post-baseline `ANRIND` ranking
- Join `ADAE` to `ADSL` on `USUBJID` if asked to show the pattern from scratch

## Day-before checklist

- [ ] R installed (>= 4.1)
- [ ] `Rscript -e 'renv::restore(prompt = FALSE)'` completed
- [ ] `Rscript programs/01_prepare_adam.R` completed
- [ ] `Rscript programs/02_derive_adtte.R` completed
- [ ] App launches locally: `Rscript -e 'shiny::runApp(".")'`
- [ ] Read `docs/methods_cheatsheet.md`
- [ ] Read **Industry alignment** and **Known gaps** sections — be ready to explain what is in scope vs standard ST&F additions
- [ ] Read the **Analysis catalogue** table above — practice naming all 10 sections from memory
- [ ] Practice 5-minute demo twice; run through 7-minute version once
- [ ] Optional: screenshot the app for README
