# Loaded by shiny::runApp() before app.R.
# Use a precompiled Bootswatch theme to avoid runtime Sass compilation
# (which can fail if a stale system bslib path is cached).

if (requireNamespace("bslib", quietly = TRUE)) {
  options(
    teal.bs_theme = bslib::bs_theme(
      version = 5,
      bootswatch = "flatly",
      `font-size-base` = "0.875rem"
    )
  )
}
