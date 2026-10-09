# Syllabus Mapping

This table maps each project component to the topics of the course syllabus (Units I to V).

## Unit I: Introduction to data science, starting with R, exploring data

| Syllabus topic | Where applied |
|---|---|
| The data science process; roles and stages of a project; setting expectations | `docs/project_report.md` (problem statement, objectives, methodology) |
| Starting with R; working with data from files | `R/01_data_preparation.R` (`read_csv`, structure audit) |
| Using summary statistics to spot problems | `R/02_exploratory_analysis.R` (summary table, skewness, IQR outlier counts) |
| Spotting problems with graphics and visualization | `R/02_exploratory_analysis.R` (figures 01 to 08) |

## Unit II: Managing data, choosing and evaluating models

| Syllabus topic | Where applied |
|---|---|
| Cleaning | `R/01_data_preparation.R` (duplicates, zero-variance column, type conversion, integrity check) |
| Data transformations | `R/01_data_preparation.R` (feature engineering: DaysInMonth, Season, PeakDemand) |
| Sampling for modelling and validation | `R/01_data_preparation.R` (stratified sample), `R/00_config.R` (stratified train/test split), `R/04_regression_models.R` (5-fold cross-validation) |
| Mapping problems to machine learning tasks | `docs/methodology.md` (regression, classification, clustering, association) |
| Evaluating models | RMSE, MAE, R-squared; accuracy, precision, recall, F1, AUC, ROC curves, confusion matrix |
| Local interpretable model-agnostic explanations (LIME) | `R/06_model_interpretation.R` |

## Unit III: Supervised and unsupervised learning, advanced methods

| Syllabus topic | Where applied |
|---|---|
| Linear regression | `R/04_regression_models.R` |
| Logistic regression | `R/05_peak_demand_classification.R` |
| Cluster analysis | `R/03_unsupervised_learning.R` (k-means, silhouette, PCA projection) |
| Association rules | `R/03_unsupervised_learning.R` (support, confidence and lift) |
| Bagging | `R/04_regression_models.R`, `R/05_peak_demand_classification.R` (`ipred::bagging`) |
| Generalized additive models | `R/04_regression_models.R` (`mgcv::gam`) |
| Kernel methods for data separation | `R/05_peak_demand_classification.R` (RBF kernel SVM, `kernlab::ksvm`) |

## Unit IV: Documentation, deployment, text mining

| Syllabus topic | Where applied |
|---|---|
| R Markdown for milestone documentation | `reports/analysis_report.Rmd` |
| Comments and version control for running documentation | Commented scripts; `docs/git_workflow.md` |
| Deploying models | `dashboard/app.R` (Shiny application serving regression and logistic models) |
| Text mining with R; tidy text format; `unnest_tokens` | `R/07_text_mining_supplement.R` |

## Unit V: Sentiment analysis, word and document frequency

| Syllabus topic | Where applied |
|---|---|
| Word and document frequency; tf-idf; `bind_tf_idf`; Zipf's law | `R/07_text_mining_supplement.R` |
| Sentiment analysis with tidy data | Not applicable. The dataset has no opinion or review text, so a sentiment analysis would have no valid input. This is stated explicitly in the report. |

## Note on scope

Predicting buzz and the Jane Austen examples in the syllabus are illustrations tied to other datasets.
The corresponding methods (tidy text, tf-idf, Zipf analysis) are demonstrated here on the only text
field available, the provider name.
