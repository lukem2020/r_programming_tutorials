# TLG Catalog teal Shiny app (CDISCPILOT01 ADaM).
# Run: Rscript -e 'shiny::runApp("app_teal")'

if (file.exists(file.path(getwd(), "renv", "activate.R"))) {
  source(file.path(getwd(), "renv", "activate.R"))
} else {
  for (d in c(getwd(), dirname(getwd()))) {
    act <- file.path(d, "renv", "activate.R")
    if (file.exists(act)) {
      source(act)
      break
    }
  }
}

.root <- local({
  d <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  repeat {
    if (file.exists(file.path(d, "config", "study_config.yml"))) break
    p <- dirname(d)
    if (identical(p, d)) break
    d <- p
  }
  d
})

for (f in c(
  "load_data.R", "tlg_registry_load.R", "teal_study_data.R",
  "tlg_unavailable_module.R", "tlg_tern_layouts.R", "tlg_modules.R"
)) {
  source(file.path(.root, "R", f))
}

suppressPackageStartupMessages({
  library(shiny)
  library(teal)
  library(teal.modules.clinical)
})

cfg <- load_config(.root)
registry <- load_tlg_registry(.root)
inventory <- load_dataset_inventory(.root)
teal_data_obj <- build_teal_data(.root, cfg)
tlg_modules <- build_tlg_modules(registry, cfg, inventory)

app <- init(
  data = teal_data_obj,
  modules = tlg_modules,
  filter = teal_arm_filter()
)

shinyApp(app$ui, app$server)
