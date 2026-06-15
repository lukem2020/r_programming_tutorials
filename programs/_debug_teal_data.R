source("renv/activate.R")
source("R/load_data.R")
suppressPackageStartupMessages(library(teal.data))
st <- load_study_data(".")
for (nm in c("ADSL", "ADAE", "ADLB", "ADVS", "ADCM", "ADEX", "ADMH", "ADTTE")) {
  data <- teal_data()
  x <- st[[nm]]
  if (is.null(x)) {
    cat(nm, "skip null\n")
    next
  }
  expr <- substitute(within(data, { DATASET <- x }), list(DATASET = as.name(nm), x = x))
  out <- tryCatch(eval(expr), error = function(e) e)
  ok <- !inherits(out, "error") && !inherits(out, "qenv.error")
  cat(nm, if (ok) "OK" else conditionMessage(out), "\n")
}
