# Methodology

## 1. Problem framing

| Business question | Machine learning task | Method |
|---|---|---|
| What drives monthly consumption? | Regression | Linear regression, generalized additive model, bagging, random forest |
| Which households are peak consumers? | Binary classification | Logistic regression, bagging, random forest, kernel SVM |
| Are there distinct household types? | Clustering | k-means with silhouette selection |
| Which appliance combinations co-occur with peak demand? | Association analysis | Support, confidence and lift of single and paired antecedents |
| Why was a particular household flagged? | Model explanation | LIME surrogate models, permutation importance |

## 2. Definition of peak demand

The dataset holds one monthly total per household. Interval readings, which would be required to
identify time-of-day peaks, are not available. Peak demand is therefore defined as a **high-load
household-month**: `MonthlyHours` at or above the 75th percentile (601 hours). The quantile is a
single configurable value (`CONFIG$peak_quantile` in `R/00_config.R`). The resulting peak share is 25.2%.

## 3. Data preparation decisions

* **Zero-variance column.** `MotorPump` equals zero in every record and carries no information.
* **Target leakage.** `ElectricityBill` equals `MonthlyHours` multiplied by `TariffRate` exactly
  (maximum absolute difference below 1e-12). Predicting hours from the bill or tariff would be
  circular, so both are excluded from every predictor set.
* **Calendar control.** Mean consumption is 469 hours in February and 504 to 529 in other months,
  consistent with the number of days. `DaysInMonth` captures this with one numeric variable.
* **City and provider.** City is retained as a categorical predictor to test whether location
  adds information. Provider (`Company`) is excluded from the models because it has 32 levels and no
  plausible causal link to household consumption; it is examined separately in the text mining module.

## 4. Validation design

* Stratified 80/20 train and test split on the peak label, with a fixed seed.
* All reported performance figures come from the held-out test partition.
* The linear model is additionally evaluated with 5-fold cross-validation on the training set
  (mean RMSE 80.6, mean R-squared 0.568), which agrees with the test result and indicates stability.
* Kernel SVM is trained on a random subsample of 8,000 training rows because kernel methods scale
  quadratically with sample size.

## 5. Model specifications

| Model | Implementation | Key settings |
|---|---|---|
| Linear regression | `stats::lm` | Appliances, DaysInMonth, City |
| Generalized additive model | `mgcv::gam`, REML | Smooth terms for Fan, Refrigerator and Television; Monitor, AirConditioner and DaysInMonth parametric |
| Bagged trees | `ipred::bagging` | 50 bootstrap trees, cp = 0.001 |
| Random forest | `randomForest` | 300 trees, node size 30 |
| Logistic regression | `stats::glm`, binomial | Same predictors |
| Kernel SVM | `kernlab::ksvm` | RBF kernel, C = 2, probability model |
| k-means | `stats::kmeans` | Standardised appliance variables, 25 starts; k chosen by silhouette width |

Monitor has only three distinct values and is therefore entered as a parametric term in the GAM,
because a smooth with more degrees of freedom than distinct values cannot be estimated.

## 6. Evaluation metrics

* Regression: root mean squared error, mean absolute error, R-squared.
* Classification: accuracy, precision, recall, F1, specificity, area under the ROC curve (AUC). A
  threshold analysis is included because the cost of missing a peak household can exceed the cost of a
  false alarm.

## 7. Interpretation methods

**LIME.** For a chosen household-month, 5,000 perturbed observations are drawn from the marginal
training distributions of the numeric predictors. The random forest scores each perturbation. A
weighted linear surrogate, with weights from an exponential kernel on standardised distance, is fitted
on five features selected by forward selection. The surrogate coefficients, scaled by the instance
deviation from the mean, are reported as local contributions. The procedure is implemented directly in
`R/06_model_interpretation.R`, following Ribeiro, Singh and Guestrin (2016), so the project depends only
on standard CRAN packages. The surrogate fit (weighted R-squared) is reported with each explanation.

**Permutation importance.** The reduction in test AUC when a predictor is permuted measures its global
contribution to the classifier.

## 8. Reference

Ribeiro, M. T., Singh, S. and Guestrin, C. (2016). "Why Should I Trust You?": Explaining the
Predictions of Any Classifier. Proceedings of the 22nd ACM SIGKDD International Conference on
Knowledge Discovery and Data Mining.
