# Verify source files that will be bundled for the teal app exist.
run_deploy_startup_check <- function(project_root) {
  need <- c(
    file.path(project_root, "R", "load_data.R"),
    file.path(project_root, "config", "study_config.yml"),
    file.path(project_root, "config", "tlg_registry.yml"),
    file.path(project_root, "config", "dataset_inventory.yml"),
    file.path(project_root, "data", "adam", "ADSL.rds")
  )
  missing <- need[!file.exists(need)]
  if (length(missing) > 0L) {
    stop(
      "Deploy source files missing:\n  ",
      paste(missing, collapse = "\n  "),
      call. = FALSE
    )
  }
  invisible(TRUE)
}
