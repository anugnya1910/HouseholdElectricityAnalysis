# ------------------------------------------------------------------------------
# 01_data_preparation.R
# Syllabus: Unit I (Starting with R, working with data from files);
#           Unit II (Managing data: cleaning, transformation, sampling).
# Reads the raw CSV, validates it, engineers features and writes the clean file.
# ------------------------------------------------------------------------------
source("R/00_config.R")
set.seed(CONFIG$seed)

raw <- read_csv(CONFIG$raw_path, show_col_types = FALSE)
cat("Raw dimensions:", nrow(raw), "rows x", ncol(raw), "columns\n")

# ---- Data quality audit -----------------------------------------------------
audit <- tibble(
  Variable      = names(raw),
  Type          = vapply(raw, function(x) class(x)[1], character(1)),
  Missing       = vapply(raw, function(x) sum(is.na(x)), integer(1)),
  DistinctValues = vapply(raw, n_distinct, integer(1)),
  Min           = vapply(raw, function(x) if (is.numeric(x)) min(x, na.rm = TRUE) else NA_real_, numeric(1)),
  Max           = vapply(raw, function(x) if (is.numeric(x)) max(x, na.rm = TRUE) else NA_real_, numeric(1))
)
save_table(audit, "data_quality_audit")
print(audit, n = Inf)

cat("Duplicate rows:", sum(duplicated(raw)), "\n")

# ---- Cleaning ---------------------------------------------------------------
clean <- raw |>
  distinct() |>
  select(-where(~ is.numeric(.x) && n_distinct(.x) == 1)) |>   # drops zero-variance columns (MotorPump)
  mutate(
    City    = factor(trimws(City)),
    Company = factor(trimws(Company)),
    Month   = as.integer(Month)
  ) |>
  drop_na()

dropped <- setdiff(names(raw), names(clean))
cat("Zero-variance columns removed:", paste(dropped, collapse = ", "), "\n")

# ---- Integrity check: the billed amount must equal hours x tariff -----------
bill_gap <- max(abs(clean$ElectricityBill - clean$MonthlyHours * clean$TariffRate))
cat("Maximum |Bill - Hours x Tariff|:", bill_gap, "\n")

# ---- Feature engineering ----------------------------------------------------
peak_threshold <- as.numeric(quantile(clean$MonthlyHours, CONFIG$peak_quantile))

clean <- clean |>
  mutate(
    MonthName   = factor(month.abb[Month], levels = month.abb),
    DaysInMonth = DAYS_IN_MONTH[Month],
    Season      = factor(case_when(
      Month %in% c(12, 1, 2)  ~ "Winter",
      Month %in% c(3, 4, 5)   ~ "Summer",
      Month %in% c(6, 7, 8, 9) ~ "Monsoon",
      TRUE                    ~ "Post-monsoon"
    ), levels = c("Winter", "Summer", "Monsoon", "Post-monsoon")),
    HoursPerDay = MonthlyHours / DaysInMonth,
    TotalAppliances = Fan + Refrigerator + AirConditioner + Television + Monitor,
    PeakDemand  = as.integer(MonthlyHours >= peak_threshold)
  )

cat("Peak threshold (", CONFIG$peak_quantile * 100, "th percentile of MonthlyHours): ",
    peak_threshold, " hours; peak share = ", round(mean(clean$PeakDemand), 3), "\n", sep = "")

write_csv(clean, CONFIG$processed_path)
write_csv(tibble(peak_threshold = peak_threshold), file.path(CONFIG$tab_dir, "peak_threshold.csv"))

# ---- Sampling demonstration (Unit II): stratified sample preserves peak share
sample_check <- bind_rows(
  population = clean |> summarise(n = n(), PeakShare = mean(PeakDemand)),
  stratified_sample = clean |> group_by(PeakDemand) |> slice_sample(prop = 0.10) |>
    ungroup() |> summarise(n = n(), PeakShare = mean(PeakDemand)),
  .id = "Set"
)
save_table(sample_check, "sampling_check")
print(sample_check)
