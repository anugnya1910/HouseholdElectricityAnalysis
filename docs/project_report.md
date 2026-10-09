# Household Electricity Consumption Pattern Analysis and Peak Demand Prediction Using R

**Course:** Introduction to Data Science, Artificial Intelligence and Data Science
**Submission type:** Case study
**Student:** Anugnya.S  |  **Roll number:** 1601-24-771-023  |  **Institution:** Chaitanya Bharathi Institute of Technology

---

## Abstract

This case study analyses 45,345 household-month electricity records from 16 Indian cities in order to
characterise consumption patterns and to predict peak demand. The data were audited, cleaned and
enriched with calendar features. Exploratory analysis, k-means clustering and association rules
describe the structure of the data. Linear regression, a generalized additive model, bagging and
random forests model monthly consumption; logistic regression, bagging, random forests and a kernel
support vector machine classify households as peak or non-peak. A linear model explains 57.9% of the
variance in monthly consumption on held-out data, and logistic regression separates peak households
with an AUC of 0.875. LIME and permutation importance show that television, monitor, fan and air
conditioner usage drive predictions, whereas city and provider contribute nothing. Results are delivered through a
reproducible R Markdown report and a Shiny dashboard.

## 1. Problem statement

Electricity utilities must anticipate which customers will place heavy load on the network. At household
level, consumption depends on the appliance stock and on how intensively it is used. The problem addressed
here is twofold: to quantify how household characteristics relate to monthly electricity consumption, and to
predict whether a household will fall into the highest-demand quartile.

## 2. Objectives

1. Describe consumption patterns across appliances, months, seasons, cities and providers.
2. Identify distinct household segments and appliance combinations associated with peak demand.
3. Compare regression models for monthly consumption.
4. Compare classification models for peak demand and explain individual predictions.
5. Communicate the results through visualisations and an interactive dashboard.

## 3. Data

The dataset (`data/raw/electricity_bill_dataset.csv`) contains 45,345 records and 12 variables:
five appliance usage variables, a motor pump variable, month, city, provider, monthly hours of use, tariff
rate and electricity bill. Variable definitions are in `docs/data_dictionary.md`.

### 3.1 Data quality findings

| Check | Result |
|---|---|
| Missing values | None |
| Duplicate records | None |
| Zero-variance variables | `MotorPump` (constant zero); removed |
| Bill integrity | `ElectricityBill` equals `MonthlyHours` multiplied by `TariffRate` exactly |
| Outliers (1.5 x IQR rule) | 115 in monthly hours and 161 in bill; retained as plausible values |
| Skewness | Monitor (1.74) and refrigerator (-1.56) are skewed; other variables are symmetric |

The bill identity has a methodological consequence. Because the bill is a deterministic product of hours
and tariff, it cannot be predicted meaningfully from them, and it must not be used as a predictor of
consumption. Consumption (`MonthlyHours`) is therefore the modelling target, and bills are derived from
predicted hours and the city tariff.

### 3.2 Definition of peak demand

The data contain monthly totals, not interval readings. A household-month is classified as **peak
demand** when `MonthlyHours` is at least 601, the 75th percentile. This yields a peak share of 25.2%.
Time-of-day peaks cannot be studied with these data.

## 4. Methodology

The workflow follows the data science process: problem definition, data collection, cleaning and
transformation, exploration, modelling, evaluation, communication and deployment. Modelling decisions,
validation design and model specifications are documented in `docs/methodology.md`. In brief:

* Stratified 80/20 train and test split with a fixed random seed.
* Predictors: five appliance variables, days in the month and city.
* Regression metrics: RMSE, MAE, R-squared. Classification metrics: accuracy, precision, recall, F1, AUC.
* Interpretation by LIME and permutation importance.

## 5. Results

### 5.1 Consumption patterns

Monthly consumption is approximately symmetric around 515 hours (standard deviation 123). Mean
consumption follows the length of the month: 469 hours in February against 504 to 529 hours in other months,
and the share of peak households is 13.3% in February against 21.7% to 28.9% elsewhere (Figures 02 and 07).

Mean monthly bills differ across cities from about INR 3,807 in Ratnagiri to INR 4,783 in Navi Mumbai.
Mean consumption is almost the same in every city (about 511 to 519 hours), so the bill gap is explained by tariff
rates, which range from 7.4 to 9.3 INR per unit (Figures 05 and 06).

### 5.2 Household segments

The silhouette criterion selects three segments (mean silhouette width 0.319).

| Segment | Households | Mean fan | Mean monitor | Mean hours | Peak share |
|---|---|---|---|---|---|
| 1: heavy monitor use | 6,720 | 16.3 | 11.6 | 618 | 55.9% |
| 2: typical | 27,240 | 16.2 | 1.0 | 525 | 25.7% |
| 3: low fan and refrigerator use | 11,385 | 7.4 | 2.2 | 431 | 5.9% |

### 5.3 Association rules

Combinations of above-median fan and monitor usage reach a lift of 2.51 for peak demand (confidence
63.2%, support 9.5%), followed by television with monitor (lift 2.43) and refrigerator with monitor
(lift 2.28). Households with these combinations are at least twice as likely to be peak consumers as the
average household.

### 5.4 Regression for monthly consumption

| Model | RMSE (hours) | MAE (hours) | R-squared |
|---|---|---|---|
| Generalized additive model | 79.52 | 68.62 | 0.579 |
| Linear regression | 79.52 | 68.62 | 0.579 |
| Random forest | 81.13 | 69.68 | 0.561 |
| Bagged trees | 85.16 | 72.18 | 0.517 |

The generalized additive model and the linear model are equivalent, which shows that the relationship between
appliance usage and consumption is approximately linear. The ensemble methods do not improve on it. The
linear coefficients give interpretable effects: one additional air conditioner adds about 30 hours per
month, one refrigerator level about 15 hours, one television level about 9 hours, one monitor level about
9 hours and one fan level about 6 hours. Each additional day in the month adds about 19 hours. Five-fold cross-validation
(mean RMSE 80.6, mean R-squared 0.568) agrees with the test result.

### 5.5 Classification of peak demand

| Model | AUC | Accuracy | Precision | Recall | F1 |
|---|---|---|---|---|---|
| Logistic regression | 0.875 | 0.818 | 0.682 | 0.519 | 0.589 |
| Random forest | 0.864 | 0.812 | 0.703 | 0.438 | 0.540 |
| Kernel SVM (RBF) | 0.837 | 0.807 | 0.712 | 0.396 | 0.509 |
| Bagged trees | 0.805 | 0.811 | 0.700 | 0.436 | 0.537 |

Logistic regression is the strongest model and also the most interpretable. Odds ratios per unit increase
are 1.88 for air conditioners, 1.44 for refrigerator level, 1.21 for television, 1.19 for monitor, 1.14 for
fan, and 1.59 per additional day in the month.

Because peak households are a minority class, recall at the default 0.5 threshold is 52%. The threshold analysis shows
that a threshold of 0.25 raises recall to 81% at a precision of 54% (F1 0.646, the maximum), which would suit an
operator for whom a missed peak household is costlier than a false alarm.

### 5.6 Model explanation

Permutation importance on the random forest ranks television (AUC reduction 0.125), monitor (0.074), fan
(0.057) and air conditioner (0.052) highest. Refrigerator and days in the month contribute little, and city has no
effect (reduction of -0.001, that is, zero within noise). LIME explanations for a high-risk, a borderline and a
low-risk household identify which appliance levels raise or lower the predicted probability of peak demand in
each case (Figure 22).

### 5.7 Text mining of provider names

The provider name is the only text field. After tokenisation and removal of stop words and corporate suffixes,
the leading terms are "power" and "transmission", and their relative frequencies are almost identical in the peak and
non-peak segments, so the tf-idf scores are zero. Provider vocabulary therefore carries no information about demand.
This is a negative result and is reported as such. Sentiment analysis was not performed because the dataset
contains no opinion text.

## 6. Dashboard

The Shiny dashboard (`dashboard/app.R`) deploys the fitted regression and logistic models. It provides
KPI tiles, city and season filters, consumption and peak-demand views, a prediction tool that returns predicted
monthly hours, peak probability and estimated bill for a user-defined household, and a filterable data table.

## 7. Discussion

Appliance usage and the length of the month account for the explainable variation in consumption. City and
provider add no predictive information, and the apparent cost differences between cities arise from tariffs.
The close agreement of linear, additive and tree-based models suggests that the available features have been
exploited fully and that the remaining 42% of variance reflects information absent from the dataset, such as
household size, appliance efficiency or time-of-use behaviour.

## 8. Limitations

* Monthly totals do not permit analysis of time-of-day peaks; the peak definition is a high-load household-month.
* The units of the appliance variables are not documented in the source file.
* The near-uniform spread of cities, months and providers suggests a synthetic or standardised dataset, which
  limits generalisation to real households.
* Predicted bills depend on a single tariff per city and ignore slab pricing and fixed charges.

## 9. Conclusion

Monthly household consumption is driven by appliance usage and the number of days in the month. A linear model
explains 58% of its variance, and logistic regression identifies peak-demand households with an AUC of 0.875.
Households combining heavy fan, television and monitor use are more than twice as likely as average to be peak
consumers. The project delivers a reproducible pipeline, a report and a dashboard that together cover the
syllabus topics of data exploration, data management, supervised and unsupervised learning, model
interpretation, documentation and deployment.

## 10. Future work

* Obtain interval meter data to define peak demand by time of day.
* Add household size, appliance efficiency ratings and weather variables.
* Evaluate gradient boosting and calibrated probability models.
* Deploy the dashboard on a hosted Shiny service.

## 11. Reproducibility

```r
source("install_packages.R")
source("run_all.R")
rmarkdown::render("reports/analysis_report.Rmd")
shiny::runApp("dashboard")
```

Figures are in `outputs/figures/` and tables in `outputs/tables/`.
