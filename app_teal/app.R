# TLG Catalog teal Shiny app (CDISCPILOT01 ADaM).
# Run from project root: Rscript run_app_teal.R

.root <- local({
  d <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  repeat {
    if (file.exists(file.path(d, "config", "study_config.yml"))) {
      return(d)
    }
    p <- dirname(d)
    if (identical(p, d)) {
      break
    }
    d <- p
  }
  stop(
    "Cannot find config/study_config.yml from working directory: ", getwd(),
    call. = FALSE
  )
})

for (f in c(
  "load_data.R", "teal_adam_trim.R", "tlg_registry_load.R", "teal_study_data.R",
  "tlg_unavailable_module.R", "tlg_tern_layouts.R", "lbl02a_rls_listing.R", "tlg_modules.R"
)) {
  source(file.path(.root, "R", f))
}

suppressPackageStartupMessages({
  library(shiny)
  library(teal)
  library(teal.modules.clinical)
})

if (is.null(getOption("teal.bs_theme"))) {
  options(
    teal.bs_theme = bslib::bs_theme(
      version = 5,
      bootswatch = "flatly",
      `font-size-base` = "0.875rem"
    )
  )
}

cfg <- load_config(.root)
inventory <- load_dataset_inventory(.root)
registry <- filter_registry_for_app(load_tlg_registry(.root), inventory, .root)
datasets_needed <- required_datasets_for_entries(registry$entries)
teal_data_obj <- build_teal_data(.root, cfg, datasets = datasets_needed)
tlg_modules <- build_tlg_modules(registry, cfg, inventory, .root)

if (teal_optimize_enabled(cfg)) {
  message("Teal data optimization: ON (slim columns; ADVS limited to vs_params)")
}
message(
  sprintf(
    "TLG app: %d modules | %s",
    length(registry$entries),
    paste(teal_dataset_summary(
      stats::setNames(lapply(datasets_needed, function(nm) teal_data_obj[[nm]]), datasets_needed)
    ), collapse = " | ")
  )
)

app <- init(
  data = teal_data_obj,
  modules = tlg_modules,
  filter = teal_arm_filter(intersect(CORE_STUDY_DATASETS, names(teal_data_obj)))
)

shinyApp(app$ui, app$server)
