#' Shared clinical visualization theme
#'
#' Keeps plot styling consistent across the tutorial apps and notebooks.
theme_clinical <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 2),
      plot.subtitle = ggplot2::element_text(color = "#4A5568"),
      axis.title = ggplot2::element_text(face = "bold"),
      legend.position = "bottom",
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold")
    )
}

#' Treatment arm color palette used across demo outputs
clinical_arm_colors <- c(
  "Placebo" = "#4C78A8",
  "Drug 10mg" = "#F58518"
)
