# ------------------------------------------------------------------------------
# run_all.R
# Executes the complete analysis pipeline in order. Run from the project root:
#   Rscript run_all.R
# ------------------------------------------------------------------------------
scripts <- c(
  "R/01_data_preparation.R",
  "R/02_exploratory_analysis.R",
  "R/03_unsupervised_learning.R",
  "R/04_regression_models.R",
  "R/05_peak_demand_classification.R",
  "R/06_model_interpretation.R",
  "R/07_text_mining_supplement.R"
)
for (s in scripts) {
  cat("\n=== Running", s, "===\n")
  source(s, local = new.env())
}
cat("\nPipeline complete. Figures: outputs/figures | Tables: outputs/tables\n")
cat("Render the report: rmarkdown::render('reports/analysis_report.Rmd')\n")
cat("Launch the dashboard: shiny::runApp('dashboard')\n")
