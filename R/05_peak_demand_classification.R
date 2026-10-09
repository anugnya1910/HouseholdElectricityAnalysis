# ------------------------------------------------------------------------------
# 05_peak_demand_classification.R
# Syllabus: Unit III (Supervised learning: logistic regression;
#           Exploring advanced methods: bagging, kernel methods for data separation).
# Task: classify a household-month as peak demand (MonthlyHours at or above the
#       75th percentile) from appliance profile, calendar length and city.
# ------------------------------------------------------------------------------
source("R/00_config.R")
suppressPackageStartupMessages({ library(ipred); library(randomForest); library(kernlab); library(pROC) })
set.seed(CONFIG$seed)

df <- read_csv(CONFIG$processed_path, show_col_types = FALSE) |> mutate(City = factor(City))
idx   <- stratified_split(df, "PeakDemand", CONFIG$train_fraction)
train <- df[idx, ]; test <- df[-idx, ]
fml <- as.formula(paste("factor(PeakDemand) ~", MODEL_FORMULA_RHS))

# ---- Logistic regression ------------------------------------------------------
m_glm <- glm(as.formula(paste("PeakDemand ~", MODEL_FORMULA_RHS)), data = train, family = binomial)
or_tbl <- broom::tidy(m_glm, conf.int = TRUE, exponentiate = TRUE) |> filter(!grepl("^City", term)) |>
  rename(OddsRatio = estimate)
save_table(or_tbl, "logistic_odds_ratios")
print(or_tbl)

# ---- Bagging, random forest, kernel SVM ---------------------------------------
m_bag <- bagging(fml, data = train, nbagg = 50,
                 control = rpart::rpart.control(cp = 0.001, minsplit = 40))
m_rf  <- randomForest(fml, data = train, ntree = 300, nodesize = 30)
svm_idx <- sample(nrow(train), 8000)                       # kernel methods scale quadratically; subsample
m_svm <- ksvm(fml, data = train[svm_idx, ], kernel = "rbfdot", prob.model = TRUE, C = 2)

probs <- list(
  `Logistic regression` = predict(m_glm, test, type = "response"),
  `Bagged trees`        = predict(m_bag, test, type = "prob")[, "1"],
  `Random forest`       = predict(m_rf, test, type = "prob")[, "1"],
  `Kernel SVM (RBF)`    = predict(m_svm, test, type = "probabilities")[, "1"]
)

roc_list <- lapply(probs, function(p) roc(test$PeakDemand, p, quiet = TRUE))
results <- bind_rows(lapply(names(probs), function(n) {
  class_metrics(test$PeakDemand, probs[[n]], 0.5) |>
    mutate(AUC = as.numeric(auc(roc_list[[n]])), Model = n, .before = 1)
})) |> arrange(desc(AUC))
save_table(results, "classification_model_comparison")
print(results)

# ---- Threshold analysis for the best model (peak demand is the costly miss) ----
best <- results$Model[1]
thr <- tibble(Threshold = seq(0.1, 0.9, by = 0.05)) |>
  rowwise() |> mutate(m = list(class_metrics(test$PeakDemand, probs[[best]], Threshold))) |>
  unnest(m) |> ungroup()
save_table(thr, "threshold_analysis")

# ---- Figures --------------------------------------------------------------------
roc_df <- bind_rows(lapply(names(roc_list), function(n) {
  tibble(Model = n, FPR = 1 - roc_list[[n]]$specificities, TPR = roc_list[[n]]$sensitivities)
}))
p_roc <- ggplot(roc_df, aes(FPR, TPR, colour = Model)) +
  geom_line(linewidth = 0.9) +
  geom_abline(linetype = "dashed", colour = "grey50") +
  scale_colour_manual(values = unname(PALETTE[c("primary", "accent", "secondary", "neutral")])) +
  labs(title = "ROC Curves for Peak Demand Classification",
       subtitle = "Held-out test set", x = "False positive rate", y = "True positive rate") +
  theme_report()
save_plot(p_roc, "18_roc_curves")

cm <- test |> mutate(Predicted = ifelse(probs[[best]] >= 0.5, "Peak", "Non-peak"),
                     Actual = ifelse(PeakDemand == 1, "Peak", "Non-peak")) |> count(Actual, Predicted)
p_cm <- ggplot(cm, aes(Predicted, Actual, fill = n)) +
  geom_tile(colour = "white") + geom_text(aes(label = comma(n)), colour = "white", size = 5) +
  scale_fill_gradient(low = PALETTE["neutral"], high = PALETTE["primary"], guide = "none") +
  labs(title = paste("Confusion Matrix:", best), subtitle = "Classification threshold 0.5") + theme_report()
save_plot(p_cm, "19_confusion_matrix", width = 5.5, height = 4.5)

p_thr <- thr |> select(Threshold, Precision, Recall, F1) |>
  pivot_longer(-Threshold, names_to = "Metric", values_to = "Value") |>
  ggplot(aes(Threshold, Value, colour = Metric)) + geom_line(linewidth = 0.9) +
  scale_colour_manual(values = unname(PALETTE[c("secondary", "accent", "primary")])) +
  labs(title = paste("Precision and Recall by Decision Threshold:", best), x = "Threshold", y = NULL) +
  theme_report()
save_plot(p_thr, "20_threshold_analysis")

p_or <- or_tbl |> filter(term != "(Intercept)") |>
  ggplot(aes(reorder(term, OddsRatio), OddsRatio, ymin = conf.low, ymax = conf.high)) +
  geom_pointrange(colour = PALETTE["primary"]) + geom_hline(yintercept = 1, linetype = "dashed", colour = PALETTE["accent"]) +
  scale_y_log10() + coord_flip() +
  labs(title = "Logistic Regression Odds Ratios for Peak Demand",
       subtitle = "Per one-unit increase; log scale, 95% confidence intervals", x = NULL, y = "Odds ratio") +
  theme_report()
save_plot(p_or, "21_odds_ratios")

saveRDS(list(glm = m_glm, rf = m_rf, train = train, test = test, best = best), "outputs/classification_models.rds")
