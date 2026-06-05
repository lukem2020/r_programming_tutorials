# Study ABC123 — Medical Data Review Dashboard (pure Shiny fallback)
# Run from project root: shiny::runApp("app/app_shiny_fallback.R")

suppressPackageStartupMessages({
  library(dplyr)
  library(DT)
  library(ggplot2)
  library(shiny)
  library(tidyr)
})

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
source(file.path(project_root, "R", "data_prep.R"), local = TRUE)
source(file.path(project_root, "R", "theme_clinical.R"), local = TRUE)

data_dir <- file.path(project_root, "data", "simulated")
if (!file.exists(file.path(data_dir, "ADSL.rds"))) {
  stop("Simulated data not found. Run: Rscript R/data_generation.R")
}

study_data <- load_study_data(data_dir)
ADSL <- study_data$ADSL
ADAE <- study_data$ADAE
ADLB <- study_data$ADLB

ui <- fluidPage(
  titlePanel("Study ABC123 — Medical Data Review Dashboard"),
  p(
    class = "text-muted",
    "Shiny fallback demo: demographics, TEAE safety table, lab shifts, patient drill-down."
  ),
  sidebarLayout(
    sidebarPanel(
      selectInput("arm", "Treatment Arm", choices = c("All", unique(ADSL$ARM))),
      selectInput("sex", "Sex", choices = c("All", unique(ADSL$SEX))),
      selectInput("saffl", "Safety Population", choices = c("All", "Y", "N"), selected = "Y"),
      selectInput(
        "patient",
        "Patient (MDR drill-down)",
        choices = ADSL$USUBJID
      ),
      hr(),
      tags$small("CtQ alignment: safety reporting, lab monitoring, population integrity")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel(
          "Demographics",
          br(),
          DTOutput("demo_table")
        ),
        tabPanel(
          "Safety Signals",
          br(),
          plotOutput("ae_plot", height = "360px"),
          br(),
          DTOutput("ae_table")
        ),
        tabPanel(
          "Lab Shifts",
          br(),
          plotOutput("lab_plot", height = "360px"),
          br(),
          DTOutput("lab_table")
        ),
        tabPanel(
          "Patient Profile",
          br(),
          DTOutput("patient_demo"),
          br(),
          h4("Adverse Events"),
          DTOutput("patient_ae"),
          br(),
          h4("Laboratory Results"),
          plotOutput("patient_labs", height = "300px")
        )
      )
    )
  )
)

filtered_adsl <- reactive({
  ADSL %>%
    filter(
      if (input$arm != "All") ARM == input$arm else TRUE,
      if (input$sex != "All") SEX == input$sex else TRUE,
      if (input$saffl != "All") SAFFL == input$saffl else TRUE
    )
})

filtered_adae <- reactive({
  ids <- filtered_adsl()$USUBJID
  ADAE %>% filter(USUBJID %in% ids, TRTEMFL == "Y")
})

filtered_adlb <- reactive({
  ids <- filtered_adsl()$USUBJID
  ADLB %>% filter(USUBJID %in% ids)
})

server <- function(input, output, session) {
  output$demo_table <- renderDT({
    filtered_adsl() %>%
      summarise(
        n = n(),
        mean_age = round(mean(AGE), 1),
        pct_female = round(100 * mean(SEX == "F"), 1),
        .by = ARM
      ) %>%
      datatable(options = list(dom = "t"), rownames = FALSE)
  })

  output$ae_table <- renderDT({
    teae_incidence_by_arm(filtered_adae(), filtered_adsl()) %>%
      datatable(options = list(pageLength = 10), rownames = FALSE)
  })

  output$ae_plot <- renderPlot({
    plot_data <- teae_incidence_by_arm(filtered_adae(), filtered_adsl()) %>%
      slice_head(n = 8, by = ARM)

    ggplot(plot_data, aes(x = reorder(AEDECOD, pct), y = pct, fill = ARM)) +
      geom_col(position = position_dodge(width = 0.8), width = 0.7) +
      coord_flip() +
      scale_fill_manual(values = clinical_arm_colors) +
      labs(
        title = "Top Treatment-Emergent Adverse Events",
        subtitle = "Subject incidence (%) by treatment arm",
        x = NULL,
        y = "Incidence (%)"
      ) +
      theme_clinical()
  })

  output$lab_table <- renderDT({
    summarize_lab_shifts(filtered_adlb(), filtered_adsl()) %>%
      datatable(options = list(pageLength = 10), rownames = FALSE)
  })

  output$lab_plot <- renderPlot({
    shift_data <- summarize_lab_shifts(filtered_adlb(), filtered_adsl()) %>%
      filter(shift_flag)

    ggplot(shift_data, aes(x = PARAM, y = n, fill = ARM)) +
      geom_col(position = position_dodge(width = 0.8), width = 0.7) +
      scale_fill_manual(values = clinical_arm_colors) +
      labs(
        title = "Potentially Clinically Relevant Lab Shifts",
        subtitle = "Normal at baseline to low/high at latest post-baseline visit",
        x = NULL,
        y = "Number of subjects"
      ) +
      theme_clinical()
  })

  output$patient_demo <- renderDT({
    filtered_adsl() %>%
      filter(USUBJID == input$patient) %>%
      select(USUBJID, ARM, AGE, SEX, RACE, SAFFL, TRTSDT, TRTEDT) %>%
      datatable(options = list(dom = "t"), rownames = FALSE)
  })

  output$patient_ae <- renderDT({
    filtered_adae() %>%
      filter(USUBJID == input$patient) %>%
      select(AEDECOD, AESOC, AESEV, AESTDTC, AEENDTC, TRTEMFL, AEREL) %>%
      datatable(options = list(dom = "t"), rownames = FALSE)
  })

  output$patient_labs <- renderPlot({
    filtered_adlb() %>%
      filter(USUBJID == input$patient) %>%
      ggplot(aes(x = ADY, y = AVAL, color = PARAM)) +
      geom_line(linewidth = 1) +
      geom_point(size = 2) +
      labs(
        title = paste("Lab trends for", input$patient),
        x = "Study Day",
        y = "Value"
      ) +
      theme_clinical()
  })
}

shinyApp(ui, server)
