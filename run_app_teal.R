#!/usr/bin/env Rscript
# Launch the TLG Catalog teal app with renv active before shiny/bslib load.
# Usage: Rscript run_app_teal.R

if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
}

Sys.setenv(RENV_CONFIG_SANDBOX_ENABLED = "FALSE")

renv_lib <- normalizePath(
  file.path("renv", "library", R.version$platform, .Platform$r_arch),
  winslash = "/",
  mustWork = FALSE
)
if (dir.exists(renv_lib)) {
  .libPaths(unique(c(renv_lib, .libPaths())))
}

bslib_scss <- system.file("lib/bs5/scss/_functions.scss", package = "bslib")
if (!nzchar(bslib_scss) || !file.exists(bslib_scss)) {
  stop(
    "bslib in the active library is missing Bootstrap SCSS files.\n",
    "From the project root run:\n",
    "  export RENV_CONFIG_SANDBOX_ENABLED=FALSE\n",
    "  Rscript -e \"renv::restore(prompt = FALSE)\"\n",
    "Then retry: Rscript run_app_teal.R",
    call. = FALSE
  )
}

args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) >= 1L) as.integer(args[[1L]]) else NULL

if (is.null(port)) {
  shiny::runApp("app_teal")
} else {
  shiny::runApp("app_teal", port = port, launch.browser = FALSE)
}
