# Install packages required for renv::snapshot() validation.
# Run: Rscript programs/06_install_renv_missing.R

source("renv/activate.R")
Sys.setenv(RENV_CONFIG_SANDBOX_ENABLED = "FALSE")

repos <- c(CRAN = "https://cloud.r-project.org")
lib <- .libPaths()[1]

pkgs <- c(
  "car", "flextable", "geeasy", "geepack", "officer", "parallelly",
  "RcppEigen", "rvest", "styler", "testthat", "TMB", "vistime"
)

for (p in pkgs) {
  if (requireNamespace(p, quietly = TRUE)) {
    cat("OK (already installed):", p, "\n")
    next
  }
  cat("Installing:", p, "\n")
  tryCatch(
    install.packages(p, lib = lib, repos = repos, dependencies = TRUE),
    error = function(e) cat("  ERROR:", conditionMessage(e), "\n")
  )
}

still_missing <- pkgs[!vapply(pkgs, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1))]
if (length(still_missing)) {
  cat("\nStill missing:", paste(still_missing, collapse = ", "), "\n")
  quit(status = 1)
}

cat("\nAll snapshot dependencies installed.\n")
