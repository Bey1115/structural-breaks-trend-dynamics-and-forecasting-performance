# Structural Breaks, Trend Dynamics, and Forecasting Performance of Philippine Electricity Demand (2019–2024)

## Overview

Electricity demand is a critical indicator of economic activity, infrastructure development, and energy security. However, demand patterns are often influenced by seasonality, economic disruptions, policy changes, and unexpected events such as the COVID-19 pandemic. These factors can introduce structural changes that affect forecasting accuracy.

This study examines the trend dynamics, structural breaks, and forecasting performance of Philippine monthly electricity demand from January 2019 to December 2024. Using statistical trend analysis, structural break detection, and multiple forecasting approaches, the study evaluates whether accounting for structural changes improves forecast accuracy.


## Research Questions

1. Does Philippine electricity demand exhibit a statistically significant long-term trend after controlling for seasonality?

2. Are there significant structural breaks that indicate regime shifts in electricity demand?

3. Is the deseasonalized and detrended series stationary?

4. How does accounting for structural breaks affect forecasting performance?


## Objectives

* Decompose electricity demand into trend, seasonal, and remainder components using STL decomposition.
* Test for long-term trends using the Mann-Kendall Test and Sen’s Slope Estimator.
* Detect multiple structural breakpoints using the Bai-Perron method.
* Compare regime-specific statistics including:

  * Mean
  * Variance
  * Volatility
  * Trend Slope
* Evaluate stationarity using the Augmented Dickey-Fuller (ADF) Test.
* Compare forecasting performance across:

  * SARIMA
  * Break-Adjusted ARIMA
  * STL-Based Forecasting
  * Prophet
* Evaluate forecast accuracy using RMSE, MAE, and MAPE.


## Dataset

**Period:** January 2019 – December 2024

**Frequency:** Monthly

**Variable:** Total Philippine Electricity Consumption

The analysis focuses on a univariate time series framework and does not incorporate external variables such as GDP, weather conditions, fuel prices, or policy indicators.


## Methodology

### Data Processing

* Data Cleaning
* Exploratory Analysis
* Time Series Diagnostics

### Trend Analysis

* STL Decomposition
* Mann-Kendall Trend Test
* Sen's Slope Estimator

### Structural Break Analysis

* Bai-Perron Multiple Breakpoint Detection
* Regime-Specific Analysis

### Stationarity Testing

* Augmented Dickey-Fuller (ADF) Test

### Forecasting Models

* SARIMA
* Break-Adjusted ARIMA
* STL-Based Forecasting
* Prophet

### Model Evaluation

Forecast accuracy was assessed using:

* Root Mean Squared Error (RMSE)
* Mean Absolute Error (MAE)
* Mean Absolute Percentage Error (MAPE)


## Key Findings

### Trend Analysis

* A significant upward trend was detected in Philippine electricity demand.
* Mann-Kendall Test indicated statistical significance (p < 0.01).
* Sen's Slope estimated an average increase of approximately **35,180 MWh per month**, equivalent to roughly **422,000 MWh annually**.

### Structural Break Analysis

* Four structural breakpoints were identified.
* The series was divided into five distinct regimes.
* Results suggest that electricity demand evolved through multiple demand patterns rather than a single stable process.

### Stationarity Analysis

| Series              | Stationarity   |
| ------------------- | -------------- |
| Original Series     | Non-Stationary |
| Trend Component     | Non-Stationary |
| Remainder Component | Stationary     |

The findings indicate that long-term growth persists while short-term shocks tend to be temporary and mean-reverting.


## Forecasting Performance

| Model                 | RMSE        | MAE       | MAPE  |
| --------------------- | ----------- | --------- | ----- |
| SARIMA                | 637,334.4   | 582,950.7 | 5.47% |
| Break-Adjusted ARIMA  | 500,174.0   | 388,447.9 | 3.60% |
| STL-Based Forecasting | 1,031,012.1 | 991,592.3 | 9.31% |
| Prophet               | 530,191.7   | 409,177.9 | 3.82% |

### Best Performing Model

**Break-Adjusted ARIMA (1,0,0)(1,0,0)[12]**

This model achieved the lowest RMSE, MAE, and MAPE, demonstrating that incorporating structural breaks significantly improves forecasting accuracy.


## Conclusions

* Philippine electricity demand exhibits a significant long-term upward trend.
* The series is structurally evolving and cannot be adequately described by a single regime.
* Four structural breaks were identified during the study period.
* Long-term movements are persistent, while short-term fluctuations are temporary.
* Models that account for structural changes outperform conventional forecasting approaches.
* Break-Adjusted ARIMA produced the most accurate forecasts among all models evaluated.


## Future Research

* Incorporate external variables such as weather, GDP, and energy prices.
* Explore hybrid forecasting approaches.
* Evaluate machine learning and deep learning models.
* Extend the analysis to longer time horizons and regional electricity demand datasets.


## Authors

**Bea Jane Lazona**
* Data Engineer | Data Scientist | Statistician
* LinkedIn: https://www.linkedin.com/in/bea-jane-lazona-81a90915b/
  
**Patricia Clanor**
* IT Professor
* LinkedIn: https://www.linkedin.com/in/patricia-paula-clanor-6a0b193a9/

## Citation

If you use this work, please cite:

Lazona, B. J., & Clanor, P. (2026). Structural Breaks, Trend Dynamics, and Forecasting Performance of Philippine Electricity Demand: Evidence from 2019–2024.


## License

This repository is intended for academic and research purposes.
