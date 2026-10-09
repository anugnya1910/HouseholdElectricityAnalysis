# ------------------------------------------------------------------------------
# 02_exploratory_analysis.R
# Syllabus: Unit I (Exploring data: summary statistics, spotting problems with
#           graphics and visualization).
# ------------------------------------------------------------------------------
source("R/00_config.R")
suppressPackageStartupMessages(library(corrplot))

df <- read_csv(CONFIG$processed_path, show_col_types = FALSE) |>
  mutate(MonthName = factor(MonthName, levels = month.abb),
         Season = factor(Season, levels = c("Winter", "Summer", "Monsoon", "Post-monsoon")))
peak_thr <- read_csv(file.path(CONFIG$tab_dir, "peak_threshold.csv"), show_col_types = FALSE)$peak_threshold

# ---- Summary statistics -----------------------------------------------------
num_vars <- c(CONFIG$appliance_vars, "MonthlyHours", "TariffRate", "ElectricityBill")
summary_stats <- df |>
  select(all_of(num_vars)) |>
  pivot_longer(everything(), names_to = "Variable", values_to = "value") |>
  group_by(Variable) |>
  summarise(Mean = mean(value), SD = sd(value), Min = min(value),
            Q1 = quantile(value, .25), Median = median(value),
            Q3 = quantile(value, .75), Max = max(value),
            Skewness = mean((value - mean(value))^3) / sd(value)^3,
            .groups = "drop")
save_table(summary_stats, "summary_statistics")
print(summary_stats)

# ---- Fig 1: distribution of monthly consumption with peak threshold ----------
p1 <- ggplot(df, aes(MonthlyHours)) +
  geom_histogram(bins = 50, fill = PALETTE["secondary"], colour = "white") +
  geom_vline(xintercept = peak_thr, colour = PALETTE["accent"], linewidth = 0.9, linetype = "dashed") +
  annotate("text", x = peak_thr + 8, y = Inf, vjust = 1.8, hjust = 0, colour = PALETTE["accent"],
           label = paste0("Peak threshold: ", peak_thr, " h")) +
  labs(title = "Distribution of Monthly Electricity Consumption",
       subtitle = "Household-month observations, upper quartile classified as peak demand",
       x = "Monthly consumption (hours of use)", y = "Number of household-months") +
  scale_y_continuous(labels = comma) + theme_report()
save_plot(p1, "01_consumption_distribution")

# ---- Fig 2: monthly profile (calendar pattern) -------------------------------
monthly <- df |> group_by(MonthName) |>
  summarise(Mean = mean(MonthlyHours), PeakShare = mean(PeakDemand), .groups = "drop")
save_table(monthly, "monthly_profile")
p2 <- ggplot(monthly, aes(MonthName, Mean, group = 1)) +
  geom_col(aes(fill = PeakShare), width = 0.7) +
  geom_text(aes(label = round(Mean)), vjust = -0.5, size = 3.4) +
  scale_fill_gradient(low = PALETTE["light"], high = PALETTE["primary"], labels = percent, name = "Peak share") +
  labs(title = "Mean Monthly Consumption by Calendar Month",
       subtitle = "Consumption follows the number of days in the month; February is the clear minimum",
       x = NULL, y = "Mean monthly hours") +
  coord_cartesian(ylim = c(0, max(monthly$Mean) * 1.1)) + theme_report()
save_plot(p2, "02_monthly_profile")

# ---- Fig 3: appliance contribution to consumption (boxplots) -----------------
p3 <- df |>
  mutate(AirConditioner = factor(AirConditioner)) |>
  ggplot(aes(AirConditioner, MonthlyHours)) +
  geom_boxplot(fill = PALETTE["light"], colour = PALETTE["primary"], outlier.alpha = 0.2) +
  labs(title = "Monthly Consumption by Number of Air Conditioners",
       x = "Air conditioners in household", y = "Monthly hours") + theme_report()
save_plot(p3, "03_consumption_by_ac")

# ---- Fig 4: correlation matrix ----------------------------------------------
cm <- cor(df |> select(all_of(CONFIG$appliance_vars), DaysInMonth, MonthlyHours, TariffRate, ElectricityBill))
png(file.path(CONFIG$fig_dir, "04_correlation_matrix.png"), width = 1100, height = 1000, res = 150, bg = "white")
corrplot(cm, method = "color", type = "upper", addCoef.col = "black", number.cex = 0.7,
         tl.col = "black", tl.srt = 45, col = colorRampPalette(c(PALETTE["accent"], "white", PALETTE["primary"]))(200),
         title = "Correlation Matrix of Numeric Variables", mar = c(0, 0, 2, 0))
dev.off()

# ---- Fig 5: city comparison --------------------------------------------------
city <- df |> group_by(City) |>
  summarise(Households = n(), MeanHours = mean(MonthlyHours), MeanTariff = mean(TariffRate),
            MeanBill = mean(ElectricityBill), PeakShare = mean(PeakDemand), .groups = "drop") |>
  arrange(desc(MeanBill))
save_table(city, "city_summary")
p5 <- ggplot(city, aes(reorder(City, MeanBill), MeanBill)) +
  geom_col(fill = PALETTE["primary"], width = 0.7) +
  geom_text(aes(label = comma(round(MeanBill))), hjust = -0.15, size = 3.3) +
  coord_flip(ylim = c(0, max(city$MeanBill) * 1.12)) +
  labs(title = "Mean Monthly Electricity Bill by City",
       subtitle = "Bill differences are driven mainly by the city tariff rate, not by usage",
       x = NULL, y = "Mean bill (INR)") + theme_report()
save_plot(p5, "05_bill_by_city")

p6 <- ggplot(city, aes(MeanTariff, MeanBill, label = City)) +
  geom_point(colour = PALETTE["accent"], size = 3) +
  geom_text(vjust = -0.9, size = 3.2, check_overlap = TRUE) +
  labs(title = "City Tariff Rate versus Mean Bill",
       x = "Mean tariff rate (INR per unit)", y = "Mean bill (INR)") + theme_report()
save_plot(p6, "06_tariff_vs_bill")

# ---- Fig 7: city x month heatmap of peak share -------------------------------
heat <- df |> group_by(City, MonthName) |> summarise(PeakShare = mean(PeakDemand), .groups = "drop")
p7 <- ggplot(heat, aes(MonthName, City, fill = PeakShare)) +
  geom_tile(colour = "white") +
  scale_fill_gradient(low = PALETTE["light"], high = PALETTE["accent"], labels = percent, name = "Peak share") +
  labs(title = "Share of Peak-Demand Households by City and Month", x = NULL, y = NULL) +
  theme_report() + theme(legend.key.width = unit(1.5, "cm"))
save_plot(p7, "07_peak_heatmap", width = 9, height = 6)

# ---- Fig 8: appliance usage versus consumption (faceted scatter with trend) ---
p8 <- df |>
  select(MonthlyHours, all_of(setdiff(CONFIG$appliance_vars, "AirConditioner"))) |>
  pivot_longer(-MonthlyHours, names_to = "Appliance", values_to = "Usage") |>
  ggplot(aes(Usage, MonthlyHours)) +
  geom_point(alpha = 0.04, colour = PALETTE["secondary"]) +
  geom_smooth(method = "lm", formula = y ~ x, colour = PALETTE["accent"], se = FALSE) +
  facet_wrap(~ Appliance, scales = "free_x") +
  labs(title = "Appliance Usage and Monthly Consumption",
       subtitle = "Linear trend shown in red", x = "Appliance usage level", y = "Monthly hours") +
  theme_report()
save_plot(p8, "08_appliance_scatter", width = 9, height = 6)

# ---- Spotting problems (Unit I): outliers by the 1.5 x IQR rule ---------------
outliers <- df |>
  summarise(across(c(MonthlyHours, ElectricityBill), list(
    outliers = ~ sum(.x < quantile(.x, .25) - 1.5 * IQR(.x) | .x > quantile(.x, .75) + 1.5 * IQR(.x))
  )))
save_table(outliers, "outlier_counts")
print(outliers)
