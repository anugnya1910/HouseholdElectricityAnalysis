# ------------------------------------------------------------------------------
# 04_regression_models.R
# Syllabus: Unit II (Choosing and evaluating models: mapping problems to machine
#           learning tasks, evaluating models);
#           Unit III (Supervised learning: linear regression;
#           Exploring advanced methods: bagging, generalized additive models).
# Target: MonthlyHours (household electricity consumption).
# TariffRate and ElectricityBill are excluded from the predictors because the bill
# is the exact product of hours and tariff, which would constitute target leakage.
# ------------------------------------------------------------------------------
source("R/00_config.R")
suppressPackageStartupMessages({ library(mgcv); library(ipred); library(randomForest) })
set.seed(CONFIG$seed)

df <- read_csv(CONFIG$processed_path, show_col_types = FALSE) |> mutate(City = factor(City))
idx   <- stratified_split(df, "PeakDemand", CONFIG$train_fraction)
train <- df[idx, ]; test <- df[-idx, ]
cat("Training rows:", nrow(train), " Test rows:", nrow(test), "\n")

fml <- as.formula(paste("MonthlyHours ~", MODEL_FORMULA_RHS))

# ---- 1. Linear regression ----------------------------------------------------
m_lm <- lm(fml, data = train)
coef_tbl <- broom::tidy(m_lm, conf.int = TRUE) |> filter(!grepl("^City", term))
save_table(coef_tbl, "linear_model_coefficients")
cat("\nLinear model (appliance and calendar terms):\n"); print(coef_tbl)

# ---- 2. Generalized additive model -------------------------------------------
# Monitor takes only three distinct values, so it enters as a parametric term.
m_gam <- gam(MonthlyHours ~ s(Fan, k = 8) + s(Refrigerator, k = 5) + AirConditioner +
               s(Television, k = 8) + Monitor + DaysInMonth + City,
             data = train, method = "REML")

# ---- 3. Bagged regression trees ----------------------------------------------
m_bag <- bagging(fml, data = train, nbagg = 50, coob = TRUE,
                 control = rpart::rpart.control(cp = 0.001, minsplit = 40))

# ---- 4. Random forest ---------------------------------------------------------
m_rf <- randomForest(fml, data = train, ntree = 300, nodesize = 30, importance = TRUE)

# ---- Evaluation on the held-out test set --------------------------------------
preds <- list(
  `Linear regression`  = predict(m_lm, test),
  `Generalized additive model` = as.numeric(predict(m_gam, test)),
  `Bagged trees`       = predict(m_bag, test),
  `Random forest`      = predict(m_rf, test)
)
results <- bind_rows(lapply(names(preds), function(n) {
  reg_metrics(test$MonthlyHours, preds[[n]]) |> mutate(Model = n, .before = 1)
})) |> arrange(RMSE)
save_table(results, "regression_model_comparison")
print(results)

# 5-fold cross-validation of the linear model for a stability check
folds <- sample(rep(1:5, length.out = nrow(train)))
cv <- bind_rows(lapply(1:5, function(k) {
  fit <- lm(fml, data = train[folds != k, ])
  reg_metrics(train$MonthlyHours[folds == k], predict(fit, train[folds == k, ])) |> mutate(Fold = k)
}))
save_table(cv, "linear_model_cv")
cat("\nLinear model 5-fold CV mean RMSE:", round(mean(cv$RMSE), 2), " mean R2:", round(mean(cv$R2), 3), "\n")

# ---- Figures ------------------------------------------------------------------
best <- results$Model[1]
pl <- tibble(Actual = test$MonthlyHours, Predicted = preds[[best]])
p_ap <- ggplot(pl, aes(Actual, Predicted)) +
  geom_point(alpha = 0.15, colour = PALETTE["secondary"]) +
  geom_abline(colour = PALETTE["accent"], linewidth = 0.9) +
  labs(title = paste("Actual versus Predicted Consumption:", best),
       subtitle = "Held-out test set; red line indicates perfect prediction",
       x = "Actual monthly hours", y = "Predicted monthly hours") + theme_report()
save_plot(p_ap, "13_actual_vs_predicted")

p_res <- tibble(Fitted = fitted(m_lm), Residual = resid(m_lm)) |>
  ggplot(aes(Fitted, Residual)) +
  geom_point(alpha = 0.1, colour = PALETTE["secondary"]) +
  geom_hline(yintercept = 0, colour = PALETTE["accent"]) +
  geom_smooth(se = FALSE, colour = PALETTE["primary"], method = "gam", formula = y ~ s(x)) +
  labs(title = "Residual Diagnostics: Linear Regression",
       x = "Fitted values", y = "Residuals") + theme_report()
save_plot(p_res, "14_linear_residuals")

p_cmp <- results |> pivot_longer(c(RMSE, MAE), names_to = "Metric", values_to = "Value") |>
  ggplot(aes(reorder(Model, -Value), Value, fill = Metric)) +
  geom_col(position = "dodge", width = 0.7) +
  scale_fill_manual(values = c(RMSE = PALETTE["primary"], MAE = PALETTE["neutral"])) +
  coord_flip() + labs(title = "Regression Model Comparison (Test Set Error)", x = NULL, y = "Error (hours)") +
  theme_report()
save_plot(p_cmp, "15_regression_comparison")

imp <- as.data.frame(importance(m_rf)) |> tibble::rownames_to_column("Variable") |>
  as_tibble() |> rename(PctIncMSE = `%IncMSE`)
save_table(imp, "random_forest_importance")
p_imp <- ggplot(imp, aes(reorder(Variable, PctIncMSE), PctIncMSE)) +
  geom_col(fill = PALETTE["primary"], width = 0.7) + coord_flip() +
  labs(title = "Variable Importance: Random Forest Regression",
       subtitle = "Increase in mean squared error when the variable is permuted", x = NULL, y = "% increase in MSE") +
  theme_report()
save_plot(p_imp, "16_variable_importance")

# GAM partial effects
gam_terms <- predict(m_gam, newdata = test, type = "terms")
sm <- bind_rows(lapply(c("s(Fan)", "s(Refrigerator)", "s(Television)"), function(t) {
  v <- sub("s\\((.*)\\)", "\\1", t)
  tibble(Variable = v, Value = test[[v]], Effect = gam_terms[, t])
}))
p_gam <- ggplot(sm, aes(Value, Effect)) +
  geom_line(colour = PALETTE["primary"], linewidth = 1) +
  facet_wrap(~ Variable, scales = "free") +
  labs(title = "Generalized Additive Model: Estimated Smooth Effects",
       subtitle = "Contribution of each appliance to predicted monthly hours", x = "Usage level", y = "Partial effect (hours)") +
  theme_report()
save_plot(p_gam, "17_gam_smooth_effects", width = 9, height = 6)

saveRDS(list(lm = m_lm), "outputs/linear_model.rds")
