# Generate config/tlg_registry.yml from the TLG Catalog index structure.
# Run from project root: Rscript programs/generate_tlg_registry.R

suppressPackageStartupMessages(library(yaml))

# Phase 1 TLGs with runnable implementations on CDISCPILOT01 safety ADaM.
PHASE1_CODES <- c(
  "DMT01", "EXT01", "AET01", "AET02", "AET03", "AET10",
  "LBT01", "LBT04", "VST01", "CMT01A",
  "AEL03", "CML01", "EXL01", "LBL01", "LBL02A_RLS", "AOVT01", "COXT01", "MHL01",
  "KMG01", "TTET01", "IPPG01", "LTG01"
)

# Dataset requirements by catalog domain folder.
DOMAIN_DATASETS <- list(
  ADA = c("ADAB"),
  `adverse-events` = c("ADSL", "ADAE"),
  `concomitant-medications` = c("ADSL", "ADCM"),
  deaths = c("ADSL", "ADAE"),
  demography = c("ADSL"),
  disclosures = c("ADSL", "ADAE"),
  disposition = c("ADSL"),
  ECG = c("ADSL", "ADEG"),
  efficacy = c("ADSL", "ADQS"),
  exposure = c("ADSL", "ADEX"),
  `lab-results` = c("ADSL", "ADLB"),
  `medical-history` = c("ADSL", "ADMH"),
  pharmacokinetic = c("ADSL", "ADPC", "ADPP"),
  `risk-management-plan` = c("ADSL", "ADAE"),
  safety = c("ADSL"),
  `vital-signs` = c("ADSL", "ADVS"),
  `development-safety-update-report` = c("ADSL", "ADAE"),
  other = c("ADSL", "ADLB", "ADVS", "ADAE")
)

# Teal module mapping for phase-1 entries (others default to tern_layout or unavailable).
TEAL_FN <- list(
  DMT01 = "tm_t_summary",
  DST01 = "tern_layout",
  EXT01 = "tm_t_exposure",
  AET01 = "tm_t_events_summary",
  AET02 = "tm_t_events",
  AET03 = "tm_t_events_by_grade",
  AET10 = "tm_t_events",
  LBT01 = "tm_g_lineplot",
  LBT04 = "tm_t_abnormality",
  LBT09 = "tern_layout",
  VST01 = "tm_g_lineplot",
  CMT01A = "tm_t_events",
  AEL03 = "tm_t_listings",
  CML01 = "tm_t_listings",
  EXL01 = "tm_t_listings",
  LBL01 = "tm_t_listings",
  LBL02A_RLS = "rlistings_listing",
  AOVT01 = "tm_t_ancova",
  COXT01 = "tm_t_coxreg",
  MHL01 = "tm_t_listings",
  KMG01 = "tm_g_km",
  TTET01 = "tm_t_tte",
  IPPG01 = "tm_g_pp_patient_timeline",
  LTG01 = "tm_g_lineplot"
)

# CDISCPILOT01 domains available after programs/01 + 02 + 04.
STUDY_DATASETS <- c("ADSL", "ADAE", "ADLB", "ADEX", "ADVS", "ADCM", "ADMH", "ADTTE")

CODE_DATASETS <- list(
  TTET01 = c("ADSL", "ADTTE"),
  KMG01 = c("ADSL", "ADTTE"),
  COXT01 = c("ADSL", "ADTTE"),
  COXT02 = c("ADSL", "ADTTE"),
  AOVT01 = c("ADSL", "ADQS"),
  IPPG01 = c("ADSL", "ADAE", "ADLB", "ADVS", "ADCM", "ADMH"),
  LTG01 = c("ADSL", "ADLB")
)

entry <- function(code, category, domain, title, qmd_file) {
  req <- if (!is.null(CODE_DATASETS[[code]])) CODE_DATASETS[[code]] else DOMAIN_DATASETS[[domain]]
  if (is.null(req)) req <- c("ADSL")
  has_data <- all(req %in% STUDY_DATASETS)
  status <- if (code %in% PHASE1_CODES && has_data) {
    "ready"
  } else if (has_data) {
    "needs_derivation"
  } else {
    "needs_domain"
  }
  impl <- if (status == "needs_domain") {
    "unavailable"
  } else if (!is.null(TEAL_FN[[code]])) {
  if (TEAL_FN[[code]] == "tern_layout") "tern_layout" else "teal_module"
  } else {
    "tern_layout"
  }
  list(
    code = code,
    category = category,
    domain = domain,
    title = title,
    catalog_qmd = qmd_file,
    required_datasets = as.list(req),
    implementation = impl,
    teal_fn = TEAL_FN[[code]] %||% NA_character_,
    status = status
  )
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L || is.na(x)) y else x

tables <- list(
  entry("ADAT01", "tables", "ADA", "Baseline Prevalence and Incidence of Treatment Emergent ADA", "tables/ADA/adat01.qmd"),
  entry("ADAT02", "tables", "ADA", "Summary of Patients with Treatment-Induced ADA", "tables/ADA/adat02.qmd"),
  entry("ADAT03", "tables", "ADA", "Summary of Serum Concentrations at Timepoints Where ADA Samples Were Collected and Analyzed", "tables/ADA/adat03.qmd"),
  entry("ADAT04A", "tables", "ADA", "Baseline Prevalence and Incidence of Treatment Emergent NAbs", "tables/ADA/adat04a.qmd"),
  entry("ADAT04B", "tables", "ADA", "Baseline Prevalence and Incidence of NAbs", "tables/ADA/adat04b.qmd"),
  entry("AET01", "tables", "adverse-events", "Safety Summary", "tables/adverse-events/aet01.qmd"),
  entry("AET01_AESI", "tables", "adverse-events", "Safety Summary (Adverse Events of Special Interest)", "tables/adverse-events/aet01_aesi.qmd"),
  entry("AET02", "tables", "adverse-events", "Adverse Events", "tables/adverse-events/aet02.qmd"),
  entry("AET02_SMQ", "tables", "adverse-events", "Adverse Events by Standardized MedDRA Query", "tables/adverse-events/aet02_smq.qmd"),
  entry("AET03", "tables", "adverse-events", "Adverse Events by Greatest Intensity", "tables/adverse-events/aet03.qmd"),
  entry("AET04", "tables", "adverse-events", "Adverse Events by Highest NCI CTCAE Grade", "tables/adverse-events/aet04.qmd"),
  entry("AET04_PI", "tables", "adverse-events", "Adverse Events Reported in >= 10% of Patients by Highest NCI CTCAE Grade", "tables/adverse-events/aet04_pi.qmd"),
  entry("AET05", "tables", "adverse-events", "Adverse Event Rate Adjusted for Patient-Years at Risk - First Occurrence", "tables/adverse-events/aet05.qmd"),
  entry("AET05_ALL", "tables", "adverse-events", "Adverse Event Rate Adjusted for Patient-Years at Risk - All Occurrences", "tables/adverse-events/aet05_all.qmd"),
  entry("AET06", "tables", "adverse-events", "Adverse Events by Baseline Characteristic", "tables/adverse-events/aet06.qmd"),
  entry("AET06_SMQ", "tables", "adverse-events", "Adverse Events by Baseline Characteristic, by SMQ and Preferred Term", "tables/adverse-events/aet06_smq.qmd"),
  entry("AET07", "tables", "adverse-events", "Adverse Events Resulting in Death", "tables/adverse-events/aet07.qmd"),
  entry("AET09", "tables", "adverse-events", "Adverse Events Related to Study Drug", "tables/adverse-events/aet09.qmd"),
  entry("AET09_SMQ", "tables", "adverse-events", "Adverse Events Related to Study Drug by Standardized MedDRA Query", "tables/adverse-events/aet09_smq.qmd"),
  entry("AET10", "tables", "adverse-events", "Most Common (>= 5%) Adverse Events", "tables/adverse-events/aet10.qmd"),
  entry("CMT01", "tables", "concomitant-medications", "Concomitant Medications (GNEDrug Legacy Coding)", "tables/concomitant-medications/cmt01.qmd"),
  entry("CMT01A", "tables", "concomitant-medications", "Concomitant Medications by Medication Class and Preferred Name", "tables/concomitant-medications/cmt01a.qmd"),
  entry("CMT01B", "tables", "concomitant-medications", "Concomitant Medications by Medication Class and Preferred Name", "tables/concomitant-medications/cmt01b.qmd"),
  entry("CMT02_PT", "tables", "concomitant-medications", "Concomitant Medications by Preferred Name (WHODrug Coding)", "tables/concomitant-medications/cmt02_pt.qmd"),
  entry("DTHT01", "tables", "deaths", "Deaths", "tables/deaths/dtht01.qmd"),
  entry("DMT01", "tables", "demography", "Demographics and Baseline Characteristics", "tables/demography/dmt01.qmd"),
  entry("DISCLOSUREST01", "tables", "disclosures", "Disclosures Outputs", "tables/disclosures/disclosurest01.qmd"),
  entry("EUDRAT01", "tables", "disclosures", "Non-Serious Adverse Events Reported in >= 5% of Patients in Any Treatment Group - Patients and Events", "tables/disclosures/eudrat01.qmd"),
  entry("EUDRAT02", "tables", "disclosures", "Serious Adverse Events, Fatal Serious Adverse Events, and Serious Adverse Events Related to Study Medication", "tables/disclosures/eudrat02.qmd"),
  entry("DST01", "tables", "disposition", "Patient Disposition", "tables/disposition/dst01.qmd"),
  entry("PDT01", "tables", "disposition", "Major Protocol Deviations", "tables/disposition/pdt01.qmd"),
  entry("PDT02", "tables", "disposition", "Major Protocol Deviations Related to Epidemic/Pandemic", "tables/disposition/pdt02.qmd"),
  entry("EGT01", "tables", "ECG", "ECG Results and Change from Baseline by Visit", "tables/ECG/egt01.qmd"),
  entry("EGT02", "tables", "ECG", "ECG Abnormalities (EGT02_1 & EGT02_2)", "tables/ECG/egt02.qmd"),
  entry("EGT03", "tables", "ECG", "Shift Table of ECG Interval Data - Baseline Versus Minimum/Maximum Post-Baseline", "tables/ECG/egt03.qmd"),
  entry("EGT04", "tables", "ECG", "Shift Table of Qualitative ECG Assessments", "tables/ECG/egt04.qmd"),
  entry("EGT05_QTCAT", "tables", "ECG", "ECG Actual Values and Changes from Baseline by Visit", "tables/ECG/egt05_qtcat.qmd"),
  entry("AOVT01", "tables", "efficacy", "ANCOVA for Multiple End Points", "tables/efficacy/aovt01.qmd"),
  entry("AOVT02", "tables", "efficacy", "ANCOVA with Single End Point and Customized Table", "tables/efficacy/aovt02.qmd"),
  entry("AOVT03", "tables", "efficacy", "ANCOVA with Consideration of Interaction", "tables/efficacy/aovt03.qmd"),
  entry("CFBT01", "tables", "efficacy", "Efficacy Data and Change from Baseline by Visit", "tables/efficacy/cfbt01.qmd"),
  entry("CMHT01", "tables", "efficacy", "Cochran-Mantel-Haenszel (CMH) Summary", "tables/efficacy/cmht01.qmd"),
  entry("COXT01", "tables", "efficacy", "Cox Regression", "tables/efficacy/coxt01.qmd"),
  entry("COXT02", "tables", "efficacy", "Multivariable Cox Regression", "tables/efficacy/coxt02.qmd"),
  entry("DORT01", "tables", "efficacy", "Duration of Response", "tables/efficacy/dort01.qmd"),
  entry("LGRT02", "tables", "efficacy", "Multi-Variable Logistic Regression", "tables/efficacy/lgrt02.qmd"),
  entry("MMRMT01", "tables", "efficacy", "Tables for Mixed-Effect Model Repeated Measures Analysis", "tables/efficacy/mmrmt01.qmd"),
  entry("ONCT05", "tables", "efficacy", "Objective Response Rate by Subgroup", "tables/efficacy/onct05.qmd"),
  entry("RATET01", "tables", "efficacy", "Event Rate Summary for Recurrent Events", "tables/efficacy/ratet01.qmd"),
  entry("RBMIT01", "tables", "efficacy", "Tables for RBMI", "tables/efficacy/rbmit01.qmd"),
  entry("RSPT01", "tables", "efficacy", "Best Overall Response", "tables/efficacy/rspt01.qmd"),
  entry("TTET01", "tables", "efficacy", "Time-To-Event Summary", "tables/efficacy/ttet01.qmd"),
  entry("EXT01", "tables", "exposure", "Study Drug Exposure Table", "tables/exposure/ext01.qmd"),
  entry("LBT01", "tables", "lab-results", "Laboratory Test Results and Change from Baseline by Visit", "tables/lab-results/lbt01.qmd"),
  entry("LBT02", "tables", "lab-results", "Laboratory Test Results by Visit", "tables/lab-results/lbt02.qmd"),
  entry("LBT03", "tables", "lab-results", "Laboratory Test Results Change from Baseline by Visit", "tables/lab-results/lbt03.qmd"),
  entry("LBT04", "tables", "lab-results", "Laboratory Abnormalities Not Present at Baseline", "tables/lab-results/lbt04.qmd"),
  entry("LBT05", "tables", "lab-results", "Laboratory Abnormalities with Single and Replicated Marked", "tables/lab-results/lbt05.qmd"),
  entry("LBT06", "tables", "lab-results", "Laboratory Abnormalities by Visit and Baseline Status", "tables/lab-results/lbt06.qmd"),
  entry("LBT07", "tables", "lab-results", "Laboratory Test Results with Highest NCI CTCAE Grade Post-Baseline", "tables/lab-results/lbt07.qmd"),
  entry("LBT08", "tables", "lab-results", "Laboratory Test Results with Highest NCI CTCAE Grade at Any Time", "tables/lab-results/lbt08.qmd"),
  entry("LBT09", "tables", "lab-results", "Liver Laboratory Tests - Patients with Elevated Post-Baseline AST or ALT Levels", "tables/lab-results/lbt09.qmd"),
  entry("LBT10", "tables", "lab-results", "Liver Laboratory Tests - Patients with Elevated Post-Baseline AST or ALT Levels at Two Consecutive Visits (with Respect to ULN)", "tables/lab-results/lbt10.qmd"),
  entry("LBT10_BL", "tables", "lab-results", "Liver Laboratory Tests - Patients with Elevated Post-Baseline AST or ALT Levels at Two Consecutive Visits (with Respect to Baseline)", "tables/lab-results/lbt10_bl.qmd"),
  entry("LBT11", "tables", "lab-results", "Time to First Increase in Liver Laboratory Test Result Meeting Hy's Law Laboratory Criteria (with Respect to ULN)", "tables/lab-results/lbt11.qmd"),
  entry("LBT11_BL", "tables", "lab-results", "Time to First Increase in Liver Laboratory Test Result Meeting Hy's Law Laboratory Criteria (with Respect to Baseline)", "tables/lab-results/lbt11_bl.qmd"),
  entry("LBT12", "tables", "lab-results", "Liver Laboratory Tests by Time on Treatment - Patients with Elevated Post-Baseline AST or ALT Levels (with Respect to ULN)", "tables/lab-results/lbt12.qmd"),
  entry("LBT12_BL", "tables", "lab-results", "Liver Laboratory Tests by Time on Treatment - Patients with Elevated Post-Baseline AST or ALT Levels (with Respect to Baseline)", "tables/lab-results/lbt12_bl.qmd"),
  entry("LBT13", "tables", "lab-results", "NCI CTCAE Grade Laboratory Abnormalities by Visit and Baseline Grade", "tables/lab-results/lbt13.qmd"),
  entry("LBT14", "tables", "lab-results", "Laboratory Test Results Shift Table - Highest NCI CTCAE Grade Post-Baseline by Baseline NCI CTCAE Grade", "tables/lab-results/lbt14.qmd"),
  entry("LBT15", "tables", "lab-results", "Laboratory Test Shifts to NCI CTCAE Grade 3-4 Post-Baseline", "tables/lab-results/lbt15.qmd"),
  entry("MHT01", "tables", "medical-history", "Medical History", "tables/medical-history/mht01.qmd"),
  entry("PKCT01", "tables", "pharmacokinetic", "Summary Concentration Table", "tables/pharmacokinetic/pkct01.qmd"),
  entry("PKPT02", "tables", "pharmacokinetic", "Pharmacokinetic Parameter Summary - Plasma/Serum/Blood PK Parameters (Stats in Rows)", "tables/pharmacokinetic/pkpt02.qmd"),
  entry("PKPT03", "tables", "pharmacokinetic", "Pharmacokinetic Parameter Summary of Plasma by Treatment (Stats in Columns)", "tables/pharmacokinetic/pkpt03.qmd"),
  entry("PKPT04", "tables", "pharmacokinetic", "Pharmacokinetic Parameter Summary - Urine PK Parameters (Stats in Rows)", "tables/pharmacokinetic/pkpt04.qmd"),
  entry("PKPT05", "tables", "pharmacokinetic", "Summary of Urinary PK Parameters by Treatment Arm (Stats in Columns)", "tables/pharmacokinetic/pkpt05.qmd"),
  entry("PKPT06", "tables", "pharmacokinetic", "Pharmacokinetic Parameter Summary - Dose-Normalized PK Parameters (Stats in Rows)", "tables/pharmacokinetic/pkpt06.qmd"),
  entry("PKPT07", "tables", "pharmacokinetic", "Table of Mean Dose-Normalized Selected Pharmacokinetic Parameters (Stats in Columns)", "tables/pharmacokinetic/pkpt07.qmd"),
  entry("PKPT08", "tables", "pharmacokinetic", "Pharmacokinetic Parameter Summary of Cumulative Amount of Drug Eliminated and Cumulative Percentage of Drug Recovered (Stats in Columns)", "tables/pharmacokinetic/pkpt08.qmd"),
  entry("PKPT11", "tables", "pharmacokinetic", "Pharmacokinetic Parameter Estimated Ratios of Geometric Means and 90% Confidence Intervals for AUC and CMAX", "tables/pharmacokinetic/pkpt11.qmd"),
  entry("RMPT01", "tables", "risk-management-plan", "Duration of Exposure for Risk Management Plan", "tables/risk-management-plan/rmpt01.qmd"),
  entry("RMPT03", "tables", "risk-management-plan", "Extent of Exposure by Age Group and Gender for Risk Management Plan", "tables/risk-management-plan/rmpt03.qmd"),
  entry("RMPT04", "tables", "risk-management-plan", "Extent of Exposure by Ethnic Origin for Risk Management Plan", "tables/risk-management-plan/rmpt04.qmd"),
  entry("RMPT05", "tables", "risk-management-plan", "Extent of Exposure by Race for Risk Management Plan", "tables/risk-management-plan/rmpt05.qmd"),
  entry("RMPT06", "tables", "risk-management-plan", "Seriousness, Outcomes, Severity, Frequency with 95% CI for Risk Management Plan", "tables/risk-management-plan/rmpt06.qmd"),
  entry("ENTXX", "tables", "safety", "Enrollment Variants", "tables/safety/enrollment01.qmd"),
  entry("VST01", "tables", "vital-signs", "Vital Sign Results and Change from Baseline by Visit", "tables/vital-signs/vst01.qmd"),
  entry("VST02", "tables", "vital-signs", "Vital Sign Abnormalities", "tables/vital-signs/vst02.qmd")
)

listings <- list(
  entry("ADAL02", "listings", "ADA", "Listing of Anti-Drug Antibody Data for Treatment Emergent ADA Positive Patients", "listings/ADA/adal02.qmd"),
  entry("AEL01", "listings", "adverse-events", "Listing of Preferred Terms, Lowest Level Terms, and Investigator-Specified Adverse Event Terms", "listings/adverse-events/ael01.qmd"),
  entry("AEL01_NOLLT", "listings", "adverse-events", "Listing of Preferred Terms and Investigator-Specified Adverse Event Terms", "listings/adverse-events/ael01_nollt.qmd"),
  entry("AEL02", "listings", "adverse-events", "Listing of Adverse Events", "listings/adverse-events/ael02.qmd"),
  entry("AEL02_ED", "listings", "adverse-events", "Listing of Adverse Events (for Early Development Studies)", "listings/adverse-events/ael02_ed.qmd"),
  entry("AEL03", "listings", "adverse-events", "Listing of Serious Adverse Events", "listings/adverse-events/ael03.qmd"),
  entry("AEL04", "listings", "adverse-events", "Listing of Patient Deaths", "listings/adverse-events/ael04.qmd"),
  entry("CML01", "listings", "concomitant-medications", "Listing of Previous and Concomitant Medications", "listings/concomitant-medications/cml01.qmd"),
  entry("CML02A_GL", "listings", "concomitant-medications", "Listing of Concomitant Medication Class Level 2, Preferred Name, and Investigator-Specified Terms", "listings/concomitant-medications/cml02a_gl.qmd"),
  entry("CML02B_GL", "listings", "concomitant-medications", "Listing of Concomitant Medication Class, Preferred Name, and Investigator-Specified Terms", "listings/concomitant-medications/cml02b_gl.qmd"),
  entry("DSL01", "listings", "disposition", "Listing of Patients with Study Drug Withdrawn Due to Adverse Events", "listings/disposition/dsl01.qmd"),
  entry("DSL02", "listings", "disposition", "Listing of Patients Who Discontinued Early from Study", "listings/disposition/dsl02.qmd"),
  entry("DSUR4", "listings", "development-safety-update-report", "Listing of Patients Who Died During Reporting Period", "listings/development-safety-update-report/dsur4.qmd"),
  entry("EGL01", "listings", "ECG", "Listing of ECG Data: Safety-Evaluable Patients", "listings/ECG/egl01.qmd"),
  entry("EXL01", "listings", "exposure", "Listing of Exposure to Study Drug", "listings/exposure/exl01.qmd"),
  entry("LBL01", "listings", "lab-results", "Listing of Laboratory Test Results", "listings/lab-results/lbl01.qmd"),
  entry("LBL01_RLS", "listings", "lab-results", "Listing of Laboratory Test Results Using Roche Safety Lab Standardization", "listings/lab-results/lbl01_rls.qmd"),
  entry("LBL02A", "listings", "lab-results", "Listing of Laboratory Abnormalities (constant units)", "listings/lab-results/lbl02a.qmd"),
  entry("LBL02A_RLS", "listings", "lab-results", "Listing of Laboratory Abnormalities Defined by Roche Safety Lab Standardization", "listings/lab-results/lbl02a_rls.qmd"),
  entry("LBL02B", "listings", "lab-results", "Listing of Laboratory Abnormalities (variable units)", "listings/lab-results/lbl02b.qmd"),
  entry("MHL01", "listings", "medical-history", "Listing of Medical History and Concurrent Diseases", "listings/medical-history/mhl01.qmd"),
  entry("PKCL01", "listings", "pharmacokinetic", "Listing of Drug A Concentration by Treatment Group, Patient and Nominal Time", "listings/pharmacokinetic/pkcl01.qmd"),
  entry("PKCL02", "listings", "pharmacokinetic", "Listing of Drug A Urine Concentration and Volumes", "listings/pharmacokinetic/pkcl02.qmd"),
  entry("PKPL01", "listings", "pharmacokinetic", "Listing of Drug A Plasma PK Parameters", "listings/pharmacokinetic/pkpl01.qmd"),
  entry("PKPL02", "listings", "pharmacokinetic", "Listing of Drug A Urine PK Parameters", "listings/pharmacokinetic/pkpl02.qmd"),
  entry("PKPL04", "listings", "pharmacokinetic", "Listing of Individual Drug A AUCIFO and CMAX Ratios Following Drug A or Drug B", "listings/pharmacokinetic/pkpl04.qmd"),
  entry("VSL01", "listings", "vital-signs", "Listing of Vital Signs: Safety-Evaluable Patients", "listings/vital-signs/vsl01.qmd")
)

graphs <- list(
  entry("FSTG01", "graphs", "efficacy", "Subgroup Analysis of Best Overall Response", "graphs/efficacy/fstg01.qmd"),
  entry("FSTG02", "graphs", "efficacy", "Subgroup Analysis of Survival Duration", "graphs/efficacy/fstg02.qmd"),
  entry("KMG01", "graphs", "efficacy", "Kaplan-Meier Plot", "graphs/efficacy/kmg01.qmd"),
  entry("MMRMG01", "graphs", "efficacy", "Plots for Mixed-Effect Model Repeated Measures Analysis", "graphs/efficacy/mmrmg01.qmd"),
  entry("MMRMG02", "graphs", "efficacy", "Forest Plot for Mixed-Effect Model Repeated Measures", "graphs/efficacy/mmrmg02.qmd"),
  entry("PKCG01", "graphs", "pharmacokinetic", "Plot of PK Concentration Over Time by Subject", "graphs/pharmacokinetic/pkcg01.qmd"),
  entry("PKCG02", "graphs", "pharmacokinetic", "Plot of PK Concentration Over Time by Cohort/Treatment Group/Dose", "graphs/pharmacokinetic/pkcg02.qmd"),
  entry("PKCG03", "graphs", "pharmacokinetic", "Plot of Mean PK Concentration Over Time by Cohort", "graphs/pharmacokinetic/pkcg03.qmd"),
  entry("PKPG01", "graphs", "pharmacokinetic", "Plot of Mean Cumulative Percentage (%) of Recovered Drug in Urine", "graphs/pharmacokinetic/pkpg01.qmd"),
  entry("PKPG02", "graphs", "pharmacokinetic", "Pharmacokinetic Parameter Summary of Serum PK Parameters by Treatment", "graphs/pharmacokinetic/pkpg02.qmd"),
  entry("PKPG03", "graphs", "pharmacokinetic", "Box Plot of Pharmacokinetic Parameters by Visit - Plasma", "graphs/pharmacokinetic/pkpg03.qmd"),
  entry("PKPG04", "graphs", "pharmacokinetic", "Box Plot of Pharmacokinetic Parameters by Visit - Plasma", "graphs/pharmacokinetic/pkpg04.qmd"),
  entry("PKPG06", "graphs", "pharmacokinetic", "Boxplot of Metabolite to Parent Ratios by Treatment", "graphs/pharmacokinetic/pkpg06.qmd"),
  entry("BRG01", "graphs", "other", "Bar Chart", "graphs/other/brg01.qmd"),
  entry("BWG01", "graphs", "other", "Box Plot", "graphs/other/bwg01.qmd"),
  entry("CIG01", "graphs", "other", "Confidence Interval Plot", "graphs/other/cig01.qmd"),
  entry("IPPG01", "graphs", "other", "Individual Patient Plot Over Time", "graphs/other/ippg01.qmd"),
  entry("LTG01", "graphs", "other", "Lattice Plot of Laboratory Tests by Treatment Group Over Time", "graphs/other/ltg01.qmd"),
  entry("MNG01", "graphs", "other", "Mean Plot", "graphs/other/mng01.qmd")
)

registry <- list(
  version = 1,
  source = "https://github.com/insightsengineering/tlg-catalog",
  study_datasets = as.list(STUDY_DATASETS),
  phase1_codes = as.list(PHASE1_CODES),
  entries = c(tables, listings, graphs)
)

out <- file.path("config", "tlg_registry.yml")
write_yaml(registry, out)
cat("Wrote", length(registry$entries), "TLG entries to", out, "\n")
