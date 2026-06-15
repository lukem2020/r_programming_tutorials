#!/usr/bin/env Rscript
# Launch the TLG Catalog teal app using only the project renv library.
# Usage: Rscript run_app_teal.R [port]

find_project_root <- function() {
  d <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  repeat {
    if (file.exists(file.path(d, "renv", "activate.R"))) return(d)
    p <- dirname(d)
    if (identical(p, d)) {
      stop(
        "Could not find project root (no renv/activate.R). ",
        "Run this script from the repository root.",
        call. = FALSE
      )
    }
    d <- p
  }
}

root <- find_project_root()
setwd(root)
source(file.path(root, "renv", "activate.R"))

# renv::activate() sets the correct platform/R-version/arch library path.
renv_lib <- .libPaths()[1]
if (!dir.exists(renv_lib) || !grepl("/renv/library/", gsub("\\\\", "/", renv_lib))) {
  stop(
    "renv project library not found at: ", renv_lib, "\n",
    "From the project root run:\n",
    "  Rscript -e \"source('renv/activate.R'); renv::restore(prompt = FALSE)\"",
    call. = FALSE
  )
}

# Isolate to the project library so a broken system install (e.g. C:/R/library/bslib)
# cannot shadow renv packages at runtime.
.libPaths(renv_lib)

bslib_scss <- system.file("lib/bs5/scss/_functions.scss", package = "bslib")
if (!nzchar(bslib_scss) || !file.exists(bslib_scss)) {
  stop(
    "bslib in the project library is missing Bootstrap SCSS files.\n",
    "From the project root run:\n",
    "  Rscript -e \"source('renv/activate.R'); renv::restore(prompt = FALSE)\"\n",
    "Then retry: Rscript run_app_teal.R",
    call. = FALSE
  )
}

suppressPackageStartupMessages({
  library(bslib)
  library(shiny)
})

# Precompiled Bootswatch theme avoids Sass compile (and stale C:/R/library paths).
options(
  teal.bs_theme = bslib::bs_theme(
    version = 5,
    bootswatch = "flatly",
    `font-size-base` = "0.875rem"
  )
)

args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) >= 1L) as.integer(args[[1L]]) else NULL

app_dir <- file.path(root, "app_teal")
if (is.null(port)) {
  shiny::runApp(app_dir)
} else {
  shiny::runApp(app_dir, port = port, launch.browser = FALSE)
}
