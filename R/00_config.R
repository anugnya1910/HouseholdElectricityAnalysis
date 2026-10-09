# ------------------------------------------------------------------------------
# 00_config.R
# Project-wide configuration, package loading and shared helper functions.
# Every analysis script sources this file first.
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(scales)
})

CONFIG <- list(
  seed            = 2026,
  raw_path        = "data/raw/electricity_bill_dataset.csv",
  processed_path  = "data/processed/electricity_clean.csv",
  fig_dir         = "outputs/figures",
  tab_dir         = "outputs/tables",
  peak_quantile   = 0.75,   # a household-month is "peak demand" above this quantile of MonthlyHours
  train_fraction  = 0.80,
  appliance_vars  = c("Fan", "Refrigerator", "AirConditioner", "Television", "Monitor")
)

for (d in c(CONFIG$fig_dir, CONFIG$tab_dir, dirname(CONFIG$processed_path))) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# Number of days per calendar month (non-leap year); used as a calendar control.
DAYS_IN_MONTH <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)

# Consistent, restrained visual theme for all figures.
PALETTE <- c(primary = "#1F3A5F", secondary = "#4F7CAC", accent = "#C8553D",
             neutral = "#8D99AE", light = "#E9EDF2")

theme_report <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title      = element_text(face = "bold", colour = PALETTE["primary"]),
      plot.subtitle   = element_text(colour = "grey35"),
      axis.title      = element_text(colour = "grey25"),
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      strip.text      = element_text(face = "bold")
    )
}

save_plot <- function(plot, name, width = 8, height = 5) {
  ggsave(file.path(CONFIG$fig_dir, paste0(name, ".png")), plot,
         width = width, height = height, dpi = 150, bg = "white")
}

save_table <- function(df, name) {
  write_csv(df, file.path(CONFIG$tab_dir, paste0(name, ".csv")))
}

# Regression and classification metrics -----------------------------------------
reg_metrics <- function(actual, predicted) {
  tibble(
    RMSE = sqrt(mean((actual - predicted)^2)),
    MAE  = mean(abs(actual - predicted)),
    R2   = 1 - sum((actual - predicted)^2) / sum((actual - mean(actual))^2)
  )
}

class_metrics <- function(actual, prob, threshold = 0.5) {
  pred <- as.integer(prob >= threshold)
  tp <- sum(pred == 1 & actual == 1); tn <- sum(pred == 0 & actual == 0)
  fp <- sum(pred == 1 & actual == 0); fn <- sum(pred == 0 & actual == 1)
  precision <- ifelse(tp + fp == 0, NA, tp / (tp + fp))
  recall    <- ifelse(tp + fn == 0, NA, tp / (tp + fn))
  tibble(
    Accuracy    = (tp + tn) / length(actual),
    Precision   = precision,
    Recall      = recall,
    F1          = 2 * precision * recall / (precision + recall),
    Specificity = tn / (tn + fp)
  )
}

# Stratified train/test split so the peak share is preserved in both partitions.
stratified_split <- function(df, strata, frac) {
  df |>
    mutate(.row = row_number()) |>
    group_by(.data[[strata]]) |>
    slice_sample(prop = frac) |>
    ungroup() |>
    pull(.row)
}

# Predictor set shared by all supervised models.
MODEL_FORMULA_RHS <- "Fan + Refrigerator + AirConditioner + Television + Monitor + DaysInMonth + City"
