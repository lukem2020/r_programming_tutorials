# Study ABC123 — Medical Data Review Dashboard (teal)
# Run from project root: shiny::runApp("app")

required_teal <- c("teal", "teal.data", "teal.modules.clinical", "teal.slice")
missing <- required_teal[!vapply(required_teal, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing) > 0) {
  stop(
    "Missing packages: ", paste(missing, collapse = ", "), "\n",
    "Run scripts/setup_env.R first, or use app/app_shiny_fallback.R"
  )
}

library(shiny)
library(teal)
library(teal.modules.clinical)
library(teal.slice)

find_project_root <- function() {
  if (file.exists(file.path("data", "simulated", "ADSL.rds"))) {
    return(normalizePath("."))
  }
  if (file.exists(file.path("..", "data", "simulated", "ADSL.rds"))) {
    return(normalizePath(".."))
  }
  stop("Cannot locate data/simulated. Run from project root.")
}

project_root <- find_project_root()

data_dir <- file.path(project_root, "data", "simulated")
if (!file.exists(file.path(data_dir, "ADSL.rds"))) {
  stop(
    "Simulated data not found. Run: Rscript R/data_generation.R"
  )
}

ADSL <- readRDS(file.path(data_dir, "ADSL.rds"))
ADAE <- readRDS(file.path(data_dir, "ADAE.rds"))
ADLB <- readRDS(file.path(data_dir, "ADLB.rds"))

data <- cdisc_data(
  ADSL = ADSL,
  ADAE = ADAE,
  ADLB = ADLB,
  code = "ADSL <- teal.data::rds2env('ADSL.rds')\nADAE <- teal.data::rds2env('ADAE.rds')\nADLB <- teal.data::rds2env('ADLB.rds')"
)

app <- init(
  data = data,
  title = "Study ABC123 — Medical Data Review Dashboard",
  header_tags = tags$p(
    class = "text-muted",
    "Interactive MDR views for demographics, safety signals, labs, and patient profiles."
  ),
  modules = modules(
    tm_t_summary(
      label = "Demographics",
      dataname = "ADSL",
      arm_var = choices_selected(
        choices = variable_choices(ADSL, c("ARM", "SEX", "RACE")),
        selected = "ARM"
      ),
      summarize_vars = choices_selected(
        choices = variable_choices(ADSL, c("AGE", "SEX", "RACE")),
        selected = c("AGE", "SEX", "RACE")
      )
    ),
    tm_t_events(
      label = "Adverse Events",
      dataname = "ADAE",
      arm_var = choices_selected(
        choices = variable_choices(ADSL, c("ARM")),
        selected = "ARM"
      ),
      llt = choices_selected(
        choices = variable_choices(ADAE, c("AEDECOD")),
        selected = "AEDECOD"
      ),
      hlt = choices_selected(
        choices = variable_choices(ADAE, c("AESOC")),
        selected = "AESOC"
      ),
      event_type = "adverse event"
    ),
    tm_g_lineplot(
      label = "Lab Values Over Time",
      dataname = "ADLB",
      xvar = choices_selected(
        choices = variable_choices(ADLB, c("ADY", "AVISIT")),
        selected = "ADY"
      ),
      yvar = choices_selected(
        choices = variable_choices(ADLB, c("AVAL", "CHG")),
        selected = "AVAL"
      ),
      param_var = choices_selected(
        choices = variable_choices(ADLB, c("PARAM", "PARAMCD")),
        selected = "PARAM"
      ),
      arm_var = choices_selected(
        choices = variable_choices(ADSL, c("ARM")),
        selected = "ARM"
      )
    ),
    tm_t_pp_basic_info(
      label = "Patient Profile",
      dataname = "ADSL",
      patient_col = "USUBJID",
      vars = choices_selected(
        choices = variable_choices(ADSL, c("AGE", "SEX", "RACE", "ARM", "SAFFL")),
        selected = c("AGE", "SEX", "RACE", "ARM")
      )
    )
  ),
  filter = teal_slices(
    slice_var = c(
      teal_slices$slice_var(
        dataname = "ADSL",
        varname = "ARM",
        title = "Treatment Arm"
      ),
      teal_slices$slice_var(
        dataname = "ADSL",
        varname = "SEX",
        title = "Sex"
      ),
      teal_slices$slice_var(
        dataname = "ADSL",
        varname = "SAFFL",
        title = "Safety Population"
      )
    )
  )
)

shinyApp(app$ui, app$server)
