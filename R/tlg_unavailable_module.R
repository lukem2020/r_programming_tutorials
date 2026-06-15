# Unavailable TLG placeholder module (needs_domain / not yet implemented).

tlg_unavailable_module <- function(entry, inventory = NULL) {
  label <- tlg_module_label(entry)
  req <- paste(unlist(entry$required_datasets, use.names = FALSE), collapse = ", ")
  status <- entry$status
  impl <- entry$implementation

  teal::module(
    label = label,
    server = function(id, data, ...) {
      moduleServer(id, function(input, output, session) {
        output$msg <- renderUI({
          avail <- entry_has_data(entry, inventory)
          tagList(
            div(
              class = "tlg-unavailable",
              h3(label),
              tags$p(sprintf("FDA ST&F mapping | Required datasets: %s", req)),
              tags$p(sprintf("Registry status: %s | Implementation: %s", status, impl)),
              if (!avail) {
                tags$p(
                  style = "color:#b02a37;font-weight:600;",
                  "One or more required ADaM domains are not available for this study."
                )
              } else {
                tags$p("Dataset requirements are met; this TLG is scheduled for a later implementation phase.")
              }
            )
          )
        })
      })
    },
    ui = function(id, ...) {
      ns <- NS(id)
      uiOutput(ns("msg"))
    },
    datanames = "all"
  )
}
