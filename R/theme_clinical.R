# Shared ggplot2 theme for consistent, publication-style clinical visualisations.
# Clean and minimal, in line with FDA ST&F / pharmaverse figure conventions.

suppressPackageStartupMessages(library(ggplot2))

# Shared palette tokens (kept in sync with the app CSS).
clinical_ink  <- "#1f2d3d"  # headings / dark text
clinical_grey <- "#5b6770"  # secondary text
clinical_mute <- "#8a949e"  # captions
clinical_grid <- "#e9edf1"  # gridlines

theme_clinical <- function(base_size = 13) {
  theme_minimal(base_size = base_size) %+replace%
    theme(
      text          = element_text(colour = clinical_ink),
      plot.title    = element_text(face = "bold", hjust = 0, size = base_size + 3,
                                   colour = clinical_ink, margin = margin(b = 3)),
      plot.subtitle = element_text(colour = clinical_grey, hjust = 0,
                                   size = base_size - 1, margin = margin(b = 12)),
      plot.caption  = element_text(colour = clinical_mute, size = base_size - 4,
                                   hjust = 1, margin = margin(t = 10)),
      plot.margin   = margin(14, 18, 10, 12),
      panel.grid.minor   = element_blank(),
      panel.grid.major   = element_line(colour = clinical_grid, linewidth = 0.5),
      panel.grid.major.x = element_blank(),
      axis.title    = element_text(colour = clinical_grey, size = base_size - 1),
      axis.title.x  = element_text(margin = margin(t = 8)),
      axis.title.y  = element_text(margin = margin(r = 8), angle = 90),
      axis.text     = element_text(colour = clinical_grey),
      axis.ticks    = element_blank(),
      legend.position  = "bottom",
      legend.title     = element_text(face = "bold", size = base_size - 1),
      legend.text      = element_text(size = base_size - 1),
      legend.key.size  = unit(0.9, "lines"),
      strip.text       = element_text(face = "bold", colour = clinical_ink),
      strip.background = element_rect(fill = "#f1f4f7", colour = NA)
    )
}
