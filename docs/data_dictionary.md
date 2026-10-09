# Data Dictionary

Source file: `data/raw/electricity_bill_dataset.csv` (45,345 rows, 12 columns, no missing values,
no duplicate rows).

## Original variables

| Variable | Type | Range or levels | Description |
|---|---|---|---|
| Fan | integer | 5 to 23 | Fan usage level of the household. The unit is not documented in the source file. |
| Refrigerator | numeric | 17 to 23 | Refrigerator usage level. |
| AirConditioner | numeric | 0 to 3 | Number of air conditioners (or usage level; four distinct values). |
| Television | numeric | 3 to 22 | Television usage level. |
| Monitor | numeric | 1, intermediate value, 12 | Monitor usage level (three distinct values). |
| MotorPump | integer | 0 | Constant in every record; removed during cleaning. |
| Month | integer | 1 to 12 | Calendar month of the billing record. |
| City | categorical | 16 cities | City of the household. |
| Company | categorical | 32 providers | Electricity provider name. |
| MonthlyHours | integer | 95 to 926 | Monthly consumption expressed in hours of use. |
| TariffRate | numeric | 7.4 to 9.3 | Tariff in INR per unit; constant within a city. |
| ElectricityBill | numeric | 807.5 to 8,286.3 | Monthly bill in INR; equals MonthlyHours multiplied by TariffRate. |

## Derived variables (created in `R/01_data_preparation.R`)

| Variable | Definition |
|---|---|
| MonthName | Abbreviated month name, ordered January to December. |
| DaysInMonth | Number of days in the calendar month (non-leap year). |
| Season | Winter (Dec to Feb), Summer (Mar to May), Monsoon (Jun to Sep), Post-monsoon (Oct to Nov). |
| HoursPerDay | MonthlyHours divided by DaysInMonth. |
| TotalAppliances | Sum of the five appliance variables. |
| PeakDemand | 1 if MonthlyHours is at or above the 75th percentile (601 hours), otherwise 0. |

## Notes

* ElectricityBill is an exact function of MonthlyHours and TariffRate. Both are excluded from the
  predictors in all consumption and peak models to prevent target leakage.
* The appliance variables are used as given. Their exact measurement units are not stated in the
  source data and should be confirmed with the dataset provider before external use.
