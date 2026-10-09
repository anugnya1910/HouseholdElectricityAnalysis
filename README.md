# Household Electricity Consumption Pattern Analysis and Peak Demand Prediction Using R

Case study for **Introduction to Data Science** (Artificial Intelligence and Data Science).

The project analyses 45,345 household-month electricity records from 16 Indian cities, models the
drivers of monthly consumption, classifies households as peak-demand or non-peak, and presents the
results through a static report and an interactive Shiny dashboard. All work is implemented in R.

## Objectives

1. Describe household consumption patterns by appliance, calendar month, season, city and provider.
2. Segment households with cluster analysis and identify appliance combinations linked to peak demand.
3. Build and compare regression models for monthly consumption.
4. Build and compare classification models for peak demand, and explain individual predictions.
5. Deliver the findings as a reproducible report and a deployed dashboard.

## Key results

| Task | Best model | Test performance |
|---|---|---|
| Consumption regression | Linear regression / generalized additive model | R-squared 0.579, RMSE 79.5 hours |
| Peak demand classification | Logistic regression | AUC 0.875, accuracy 0.818 |
| Household segmentation | k-means, k = 3 | Mean silhouette width 0.319 |

Peak demand is defined as monthly consumption at or above the 75th percentile (601 hours).

## Repository structure

```
.
├── data/
│   ├── raw/                     Original dataset (electricity_bill_dataset.csv)
│   └── processed/               Cleaned dataset with engineered features (generated)
├── R/
│   ├── 00_config.R              Configuration, theme and helper functions
│   ├── 01_data_preparation.R    Audit, cleaning, feature engineering, sampling
│   ├── 02_exploratory_analysis.R  Summary statistics and visualisation
│   ├── 03_unsupervised_learning.R k-means clustering, PCA, association rules
│   ├── 04_regression_models.R   Linear regression, GAM, bagging, random forest
│   ├── 05_peak_demand_classification.R  Logistic regression, bagging, random forest, kernel SVM
│   ├── 06_model_interpretation.R  LIME local explanations, permutation importance
│   └── 07_text_mining_supplement.R  Tidy text analysis of provider names
├── dashboard/app.R              Shiny dashboard
├── reports/
│   ├── analysis_report.Rmd      R Markdown report source
│   └── analysis_report.html     Rendered report
├── outputs/
│   ├── figures/                 25 figures (PNG)
│   └── tables/                  Result tables (CSV)
├── docs/                        Project documentation (see below)
├── tests/test_data_quality.R    Automated data integrity checks
├── run_all.R                    Runs the full pipeline
└── install_packages.R           Installs required packages
```

## Documentation

| Document | Content |
|---|---|
| [docs/project_report.md](docs/project_report.md) | Full case study write-up |
| [docs/methodology.md](docs/methodology.md) | Modelling decisions and justification |
| [docs/data_dictionary.md](docs/data_dictionary.md) | Variable definitions |
| [docs/syllabus_mapping.md](docs/syllabus_mapping.md) | Mapping of project components to syllabus units |
| [docs/git_workflow.md](docs/git_workflow.md) | Version control conventions used in this project |

## Requirements

R version 4.1 or later (the native pipe operator is used). Install the packages with:

```r
source("install_packages.R")
```

## Usage

Run all commands from the project root.

```r
source("run_all.R")                                  # regenerate all tables and figures
rmarkdown::render("reports/analysis_report.Rmd")     # rebuild the report
shiny::runApp("dashboard")                           # launch the dashboard
source("tests/test_data_quality.R")                  # run data integrity tests
```

From a terminal: `Rscript run_all.R`.

## Dashboard

The dashboard has four tabs: consumption patterns (monthly profile, distribution, city and appliance
comparisons), peak demand (city by month heatmap, appliance profile of peak households), a prediction
tool (predicted monthly hours, peak probability and estimated bill for a user-defined household), and
a filterable data table. Sidebar filters for city, season and air conditioner count apply to all views.

## Limitations

The dataset contains monthly totals rather than interval meter readings, so peak demand is defined at
the household-month level and not by time of day. The distribution of cities, months and providers is
close to uniform, which suggests a synthetic or standardised dataset. Findings should be read as a
methodological demonstration. Details are given in the project report.

## Licence

Released under the MIT Licence.
