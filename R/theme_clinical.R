# Shared ggplot2 theme for consistent clinical visualisations.

suppressPackageStartupMessages(library(ggplot2))

theme_clinical <- function(base_size = 13) {
  theme_minimal(base_size = base_size) %+replace%
    theme(
      plot.title    = element_text(face = "bold", hjust = 0, size = base_size + 2,
                                   margin = margin(b = 4)),
      plot.subtitle = element_text(colour = "grey35", hjust = 0,
                                   margin = margin(b = 8)),
      plot.caption  = element_text(colour = "grey45", size = base_size - 3, hjust = 1),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      axis.title    = element_text(colour = "grey25"),
      legend.position = "bottom",
      legend.title  = element_text(face = "bold"),
      strip.text    = element_text(face = "bold")
    )
}
