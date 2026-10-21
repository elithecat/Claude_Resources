# Schematic curve for the "Using LLMs in research" deck: how a new user's
# impression of AI changes with use (skeptical, then impressed, then mixed).
# Writes four PDFs so that the slide can show one callout per click:
#   llm_curve_0 (no callouts) ... llm_curve_3 (all three callouts).
# House style: boxed ggplot panel, Brown red line, blue italic callouts,
# no gridlines, no axis units (schematic). Run from the repo root.

.libPaths(c("~/Rlibs", .libPaths()))
library(ggplot2)
library(data.table)

trt_col  <- "#8B1A1A"
ann_col  <- "#1F5FA8"

theme_sch <- function() theme_bw(base_size = 19) +
  theme(panel.grid = element_blank(),
        axis.text = element_blank(), axis.ticks = element_blank(),
        legend.position = "none")

x <- seq(0, 8, by = 0.02)
y <- 0.2 + 0.35 * plogis((x - 3) * 3) + 0.45 * exp(-((x - 3.5) / 0.8)^2)
dt <- data.table(x = x, y = y)

callouts <- list(
  list(x = 0.2,  y = 0.34, label = "Probably\nnot that good", hjust = 0, vjust = 0),
  list(x = 3.5,  y = 1.03, label = "This is amazing",         hjust = 0.5, vjust = 0),
  list(x = 7.9,  y = 0.42, label = "Some good, some not",     hjust = 1, vjust = 0.5))

base <- ggplot(dt, aes(x, y)) +
  geom_line(colour = trt_col, linewidth = 1.1) +
  scale_y_continuous(limits = c(0, 1.18), expand = c(0, 0)) +
  scale_x_continuous(expand = expansion(mult = c(0.01, 0.02))) +
  labs(x = "Time using AI", y = "Impression of AI") +
  theme_sch()

for (k in 0:3) {
  p <- base
  for (j in seq_len(k)) {
    a <- callouts[[j]]
    p <- p + annotate("text", x = a$x, y = a$y, label = a$label,
                      colour = ann_col, fontface = "italic", size = 5.4,
                      hjust = a$hjust, vjust = a$vjust, lineheight = 0.9)
  }
  ggsave(sprintf("beamer_template/figures/llm_curve_%d.pdf", k), p, width = 5.6, height = 3.8)
}
