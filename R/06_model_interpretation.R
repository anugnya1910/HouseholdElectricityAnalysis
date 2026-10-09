# ------------------------------------------------------------------------------
# 06_model_interpretation.R
# Syllabus: Unit I (Exploring data / explaining predictions);
#           Unit II (Choosing and evaluating models: Local Interpretable
#           Model-agnostic Explanations (LIME) for explaining model predictions).
#
# LIME is implemented directly below so that the project has no dependency on
# packages outside the standard CRAN set. The procedure follows Ribeiro et al.
# (2016): perturb the instance, query the black-box model, weight perturbations
# by proximity, and fit a sparse weighted linear surrogate model.
# ------------------------------------------------------------------------------
source("R/00_config.R")
suppressPackageStartupMessages(library(randomForest))
set.seed(CONFIG$seed)

obj   <- readRDS("outputs/classification_models.rds")
rf    <- obj$rf; train <- obj$train; test <- obj$test
num_f <- c(CONFIG$appliance_vars, "DaysInMonth")

#' Local surrogate explanation for one observation.
#' @param model     fitted black-box model
#' @param instance  one-row data frame
#' @param n_perm    number of perturbed samples
#' @param k         number of features retained in the surrogate
lime_explain <- function(model, instance, train, n_perm = 5000, k = 5, kernel_width = NULL) {
  # 1. Perturb: draw each numeric feature independently from its training distribution.
  perturbed <- as.data.frame(lapply(train[num_f], function(x) sample(x, n_perm, replace = TRUE)))
  perturbed$City <- instance$City                      # hold the categorical feature fixed
  perturbed$City <- factor(perturbed$City, levels = levels(train$City))
  # 2. Query the black-box model.
  p <- predict(model, perturbed, type = "prob")[, "1"]
  # 3. Proximity weights from an exponential kernel on standardised distance.
  sds <- vapply(train[num_f], sd, numeric(1))
  z   <- sweep(sweep(as.matrix(perturbed[num_f]), 2, as.numeric(instance[num_f]), "-"), 2, sds, "/")
  d   <- sqrt(rowSums(z^2))
  if (is.null(kernel_width)) kernel_width <- 0.75 * sqrt(length(num_f))
  w   <- sqrt(exp(-(d^2) / kernel_width^2))
  # 4. Feature selection (forward, by weighted R2) and weighted ridge-free linear surrogate.
  Z <- scale(perturbed[num_f]); dat <- data.frame(p = p, Z)
  chosen <- character(0)
  for (i in seq_len(k)) {
    cand <- setdiff(num_f, chosen)
    r2 <- vapply(cand, function(v) summary(lm(reformulate(c(chosen, v), "p"), dat, weights = w))$r.squared, numeric(1))
    chosen <- c(chosen, cand[which.max(r2)])
  }
  fit <- lm(reformulate(chosen, "p"), dat, weights = w)
  # Contribution of each feature at the instance = coefficient x standardised value
  inst_z <- (as.numeric(instance[chosen]) - colMeans(perturbed[chosen])) / apply(perturbed[chosen], 2, sd)
  tibble(Feature = chosen,
         Value = as.numeric(instance[chosen]),
         Contribution = coef(fit)[chosen] * inst_z) |>
    mutate(ModelProbability = predict(model, instance, type = "prob")[, "1"],
           SurrogateR2 = summary(fit)$r.squared)
}

# ---- Select three illustrative household-months: high, borderline, low risk -------
test$prob <- predict(rf, test, type = "prob")[, "1"]
cases <- bind_rows(
  test |> slice_max(prob, n = 1, with_ties = FALSE) |> mutate(Case = "High predicted risk"),
  test |> slice_min(abs(prob - 0.5), n = 1, with_ties = FALSE) |> mutate(Case = "Borderline"),
  test |> slice_min(prob, n = 1, with_ties = FALSE) |> mutate(Case = "Low predicted risk")
)

expl <- bind_rows(lapply(seq_len(nrow(cases)), function(i) {
  lime_explain(rf, cases[i, ], train) |> mutate(Case = cases$Case[i], .before = 1)
}))
save_table(expl, "lime_explanations")
print(expl)

lbl <- expl |> distinct(Case, ModelProbability) |>
  mutate(Label = sprintf("%s (model probability %.2f)", Case, ModelProbability))
p_lime <- expl |> left_join(lbl, by = c("Case", "ModelProbability")) |>
  mutate(Label = factor(Label, levels = lbl$Label),
         Direction = ifelse(Contribution >= 0, "Supports peak", "Opposes peak")) |>
  ggplot(aes(reorder(paste0(Feature, " = ", Value), Contribution), Contribution, fill = Direction)) +
  geom_col(width = 0.7) + coord_flip() +
  facet_wrap(~ Label, scales = "free_y", ncol = 1) +
  scale_fill_manual(values = c("Supports peak" = unname(PALETTE["accent"]), "Opposes peak" = unname(PALETTE["secondary"]))) +
  labs(title = "Local Explanations of Random Forest Peak-Demand Predictions",
       subtitle = "LIME surrogate contributions to the predicted probability of peak demand",
       x = NULL, y = "Contribution to peak probability") + theme_report()
save_plot(p_lime, "22_lime_explanations", width = 8, height = 8)

# ---- Global permutation importance on the test set for the classifier ---------------
base_auc <- as.numeric(pROC::auc(pROC::roc(test$PeakDemand, test$prob, quiet = TRUE)))
perm <- bind_rows(lapply(c(num_f, "City"), function(v) {
  t2 <- test; t2[[v]] <- sample(t2[[v]])
  a <- as.numeric(pROC::auc(pROC::roc(t2$PeakDemand, predict(rf, t2, type = "prob")[, "1"], quiet = TRUE)))
  tibble(Variable = v, AUC_Drop = base_auc - a)
})) |> arrange(desc(AUC_Drop))
save_table(perm, "permutation_importance_classifier")
p_perm <- ggplot(perm, aes(reorder(Variable, AUC_Drop), AUC_Drop)) +
  geom_col(fill = PALETTE["primary"], width = 0.7) + coord_flip() +
  labs(title = "Permutation Importance: Peak Demand Classifier",
       subtitle = "Reduction in test AUC when a predictor is randomly permuted", x = NULL, y = "AUC reduction") +
  theme_report()
save_plot(p_perm, "23_permutation_importance")
