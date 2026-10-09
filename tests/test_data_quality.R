# Automated data integrity checks. Run from the project root:
#   Rscript tests/test_data_quality.R
library(testthat)
library(readr)

df <- read_csv("data/processed/electricity_clean.csv", show_col_types = FALSE)

test_that("no missing values remain", { expect_equal(sum(is.na(df)), 0) })
test_that("no duplicated records", { expect_equal(sum(duplicated(df)), 0) })
test_that("bill equals hours multiplied by tariff", {
  expect_lt(max(abs(df$ElectricityBill - df$MonthlyHours * df$TariffRate)), 1e-6)
})
test_that("months are valid calendar months", { expect_true(all(df$Month %in% 1:12)) })
test_that("tariff and hours are positive", {
  expect_true(all(df$TariffRate > 0)); expect_true(all(df$MonthlyHours > 0))
})
test_that("peak label is binary and consistent with threshold", {
  thr <- read_csv("outputs/tables/peak_threshold.csv", show_col_types = FALSE)$peak_threshold
  expect_true(all(df$PeakDemand %in% c(0, 1)))
  expect_true(all((df$MonthlyHours >= thr) == (df$PeakDemand == 1)))
})
test_that("peak share is close to the configured quantile", {
  expect_equal(mean(df$PeakDemand), 0.25, tolerance = 0.03)
})
