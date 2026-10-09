# Installs every package required by the project from CRAN.
pkgs <- c("dplyr", "tidyr", "readr", "ggplot2", "scales", "corrplot", "cluster", "mgcv",
          "ipred", "rpart", "randomForest", "kernlab", "pROC", "broom", "tibble",
          "tidytext", "shiny", "DT", "rmarkdown", "knitr", "testthat")
missing <- setdiff(pkgs, rownames(installed.packages()))
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
cat("All required packages are installed.\n")
