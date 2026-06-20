library(readxl)
library(zoo)
library(ggplot2)
library(scales)
library(seasonalview)
library(seasonal)
library(forecast)
library(rugarch)
library(trend)
library(strucchange)
library(tseries)
library(prophet)
library(tidyr)
library(dplyr)
library(here)



# Import Data
electric_consumption <- read_excel(
  here("Data", "PH Electricity Total Consumption 2019-2024.xlsx")
)

View(electric_consumption)

# Convert the data into time series data format
start_year <- as.numeric(format(electric_consumption$Date[1], "%Y"))
start_month <- as.numeric(format(electric_consumption$Date[1], "%m"))

ts_electric_consumption <- ts(
  electric_consumption$`Total consumptions`,
  start = c(start_year, start_month),
  frequency = 12
)

class(ts_electric_consumption)


# RQ1: Long-Term Trend Dynamics -----------------------------------------------
# (STL + Mann-Kendall + Sen’s slope + regime comparison)

# STL decomposition
stl_decomp <- stl(ts_electric_consumption, s.window = "periodic")

# Extract components
trend_comp <- stl_decomp$time.series[, "trend"]
seasonal_comp <- stl_decomp$time.series[, "seasonal"]
remainder_comp <- stl_decomp$time.series[, "remainder"]

# Plot decomposition
thesis_theme <- theme_classic(base_size = 12) +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 13),
    strip.text = element_text(face = "bold"),
    panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.5)
  )

autoplot(stl_decomp) +
  labs(title = "STL Decomposition of Monthly Electricity Consumption",
       x = "Time",
       y = "") +
  thesis_theme +
  scale_y_continuous(
    labels = comma       # removes scientific notation
  ) 

# Mann-Kendall test on trend component
mk_test <- mk.test(trend_comp)
print(mk_test)

# Sen's slope estimator
sen_slope <- sens.slope(trend_comp)
print(sen_slope)

# Visualize Trend vs Actual Data
autoplot(ts_electric_consumption, series = "Actual") +
  autolayer(trend_comp, series = "Trend") +
  
  ggtitle("Actual vs Extracted Trend") +
  xlab("Year") +
  ylab("Electricity Consumption") +
  
  scale_y_continuous(
    labels = comma       # removes scientific notation
  ) +
  
  theme_minimal() +
  theme(
    legend.title = element_blank()
  )

# RQ2: Structural Breaks and Regime Shifts ----------------------------------------------
# (Bai-Perron + regime statistics + break-adjusted forecasting)

# 1. Bai-Perron Multiple Break Test
# Apply breakpoints test
bp_test <- breakpoints(ts_electric_consumption ~ 1)

summary(bp_test)

# Plot breakpoints
plot(bp_test)
lines(bp_test)

# Extract break dates
break_dates <- breakdates(bp_test)

# Convert decimal year → Date
break_dates_formatted <- as.yearmon(break_dates)

# Convert to readable format (e.g., "Dec 2019")
break_dates_label <- format(break_dates_formatted, "%b %Y")

# Convert breakpoints to numeric indices
bp_index <- breakpoints(bp_test)$breakpoints

# Plot
time_index <- time(ts_electric_consumption)
bp_index <- breakpoints(bp_test)$breakpoints
ts_million <- ts_electric_consumption / 1e6
plot(ts_million,
     main = "Electricity Demand with Structural Breaks",
     ylab = "Consumption",
     xlab = "Time")

abline(v = time_index[bp_index], col = "red", lty = 2, lwd = 2)

# Add formatted labels
text(x = time_index[bp_index],
     y = max(ts_million),
     labels = break_dates_label,
     pos = 4,
     cex = 0.8,
     col = "red")



# 2. Regime-Specific Statistics
# Extract break indices
break_index <- breakpoints(bp_test)$breakpoints

# Create regimes
regimes <- breakfactor(bp_test)

# Combine into dataframe
df_regime <- data.frame(
  Date = electric_consumption$Date,
  Consumption = as.numeric(ts_electric_consumption),
  Regime = regimes
)

# Regime mean and variance
aggregate(Consumption ~ Regime, df_regime, mean)
aggregate(Consumption ~ Regime, df_regime, var)

# 3. Volatility from STL Remainder
# Add remainder to dataframe
df_regime$Remainder <- remainder_comp

# Regime volatility
aggregate(Remainder ~ Regime, df_regime, sd)


# Regime Slope
df_regime$TimeIndex <- 1:nrow(df_regime)

regime_trend <- df_regime %>%
  group_by(Regime) %>%
  summarise(
    Trend_Slope = coef(lm(Consumption ~ TimeIndex))[2]
  )

print(regime_trend)



# RQ3: Stationarity & Volatility Diagnostics ----------------------------------------------
# Raw data
adf_raw <- adf.test(ts_electric_consumption)
print(adf_raw)

# Trend component
adf_trend <- adf.test(trend_comp)
print(adf_trend)

# Remainder component
adf_remainder <- adf.test(na.omit(remainder_comp))
print(adf_remainder)


# FORECASTING FINAL ---------------------------------------------------
# Train/Test split
train <- window(ts_electric_consumption, end = c(2023,12))
test  <- window(ts_electric_consumption, start = c(2024,1))

# SARIMA --------------------------------
# Fit SARIMA on training data only
baseline_model <- auto.arima(train, seasonal = TRUE)
summary(baseline_model)

# Forecast only the test horizon
fc_baseline <- forecast(baseline_model, h = length(test))

# Plot forecast vs actual
autoplot(train, series = "Training Data") +
  autolayer(fc_baseline$mean, series = "Baseline SARIMA Forecast") +
  autolayer(test, series = "Actual") +
  ggtitle("Baseline SARIMA Forecast vs Actual (Test Set)") +
  xlab("Time") +
  ylab("Electricity Consumption") +
  scale_y_continuous(labels = scales::comma) +
  scale_colour_manual(
    name = "Legend",
    values = c(
      "Training Data" = "black",
      "Baseline SARIMA Forecast" = "blue",
      "Actual" = "red"
    )
  )
# Forecast accuracy based on test set
acc_baseline <- accuracy(fc_baseline, test)
acc_baseline


# Break-Adjusted Model --------------------------------

# Split regimes
regimes_train <- regimes[1:length(train)]
regimes_test  <- regimes[(length(train)+1):length(ts_electric_consumption)]

# Convert to factor
regimes_train <- as.factor(regimes_train)

# Create dummy matrix
dummy_train <- model.matrix(~ regimes_train)[, -1]

# Remove constant columns
dummy_train <- dummy_train[, colSums(dummy_train) > 0, drop = FALSE]

# Fit model
break_model <- auto.arima(
  train,
  xreg = dummy_train,
  seasonal = TRUE
)

summary(break_model)

# Prepare test dummies
regimes_test <- factor(regimes_test, levels = levels(regimes_train))
dummy_test <- model.matrix(~ regimes_test)[, -1]

dummy_test_full <- matrix(
  0,
  nrow = nrow(dummy_test),
  ncol = ncol(dummy_train)
)

colnames(dummy_test_full) <- colnames(dummy_train)

common_cols <- intersect(colnames(dummy_train), colnames(dummy_test))

dummy_test_full[, common_cols] <- dummy_test[, common_cols]

dummy_test <- dummy_test_full

# Forecast
break_fc <- forecast(
  break_model,
  xreg = dummy_test,
  h = length(test)
)
summary(break_fc)
# Plot
autoplot(train, series = "Training Data") +
  autolayer(break_fc$mean, series = "Break-Adjusted Forecast") +
  autolayer(test, series = "Actual") +
  ggtitle("Break-Adjusted Model Forecast vs Actual (Test Set)") +
  xlab("Time") +
  ylab("Electricity Consumption") +
  scale_y_continuous(labels = scales::comma) +
  scale_colour_manual(
    name = "Legend",
    values = c(
      "Training Data" = "black",
      "Break-Adjusted Forecast" = "blue",
      "Actual" = "red"
    )
  )

# Accuracy
acc_break <- accuracy(break_fc, test)
acc_break


# STL-Based Forecast --------------------------------

stl_model <- stlf(train, h = length(test))

# Plot
autoplot(train, series = "Training Data") +
  autolayer(stl_model$mean, series = "STL-Based Forecast") +
  autolayer(test, series = "Actual") +
  ggtitle("STL-Based Forecast vs Actual (Test Set)") +
  xlab("Time") +
  ylab("Electricity Consumption") +
  scale_y_continuous(labels = scales::comma) +
  scale_colour_manual(
    name = "Legend",
    values = c(
      "Training Data" = "black",
      "STL-Based Forecast" = "blue",
      "Actual" = "red"
    )
  )

# Accuracy
acc_stl <- accuracy(stl_model, test)
acc_stl


# Prophet Model --------------------------------
df_prophet <- data.frame(
  ds = electric_consumption$Date,
  y  = electric_consumption$`Total consumptions`
)

# Split train/test
df_train <- df_prophet[df_prophet$ds <= as.POSIXct("2023-12-31"), ]
df_test  <- df_prophet[df_prophet$ds >= as.POSIXct("2024-01-01"), ]

# Fit model
model_prophet <- prophet(df_train)

# Create future dataframe ONLY for test horizon
future <- make_future_dataframe(model_prophet, periods = nrow(df_test), freq = "month")

forecast_prophet <- predict(model_prophet, future)

# Extract forecast for test period
prophet_fc <- tail(forecast_prophet$yhat, nrow(df_test))

# Plot
ggplot() +
  geom_line(data = df_train, aes(ds, y, colour = "Training Data")) +
  geom_line(data = df_test, aes(ds, y, colour = "Actual")) +
  geom_line(data = forecast_prophet, aes(ds, yhat, colour = "Prophet Forecast")) +
  ggtitle("Prophet Forecast vs Actual (Test Set)") +
  xlab("Time") +
  ylab("Electricity Consumption") +
  scale_y_continuous(labels = scales::comma) +
  scale_colour_manual(
    name = "Legend",
    values = c(
      "Training Data" = "black",
      "Prophet Forecast" = "blue",
      "Actual" = "red"
    )
  ) +
  theme_minimal()

# Accuracy
acc_prophet <- accuracy(prophet_fc, df_test$y)
acc_prophet

accuracy_table <- rbind(
  SARIMA = acc_baseline["Test set", c("ME","RMSE","MAE","MPE","MAPE")],
  Break_Adjusted = acc_break["Test set", c("ME","RMSE","MAE","MPE","MAPE")],
  STL = acc_stl["Test set", c("ME","RMSE","MAE","MPE","MAPE")],
  Prophet = acc_prophet[1, c("ME","RMSE","MAE","MPE","MAPE")]
)

accuracy_table



# ------------------------------
# Combine forecasts for plotting
# ------------------------------

# Create data frame for forecasts
forecast_df <- data.frame(
  Date = as.numeric(time(test)),
  Test_Data = as.numeric(test),
  SARIMA = as.numeric(fc_baseline$mean),
  Break_Adjusted = as.numeric(break_fc$mean),
  STL = as.numeric(stl_model$mean),
  Prophet = as.numeric(prophet_fc)
)

train_df <- data.frame(
  Date = as.numeric(time(train)),
  Training = as.numeric(train)
)

library(tidyr)

forecast_long <- pivot_longer(
  forecast_df,
  cols = -Date,
  names_to = "Series",
  values_to = "Value"
)

train_long <- data.frame(
  Date = train_df$Date,
  Series = "Training Data",
  Value = train_df$Training
)

plot_data <- rbind(train_long, forecast_long)

library(ggplot2)

ggplot(plot_data, aes(x = Date, y = Value, colour = Series)) +
  
  geom_line(size = 1.2) +
  
  labs(
    title = "Electricity Consumption Forecast Comparison",
    subtitle = "Comparison of Forecasting Models vs Actual Test Data",
    x = "Year",
    y = "Electricity Consumption",
    colour = "Series"
  ) +
  
  scale_y_continuous(labels = scales::comma) +
  
  scale_colour_manual(
    values = c(
      "Training Data" = "black",
      "Test_Data" = "red",
      "SARIMA" = "#2C7FB8",
      "Break_Adjusted" = "#31A354",
      "STL" = "#756BB1",
      "Prophet" = "#FF8C00"
    )
  ) +
  
  theme_minimal(base_size = 14) +
  
  theme(
    plot.title = element_text(size = 18, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(size = 12, hjust = 0.5),
    axis.title = element_text(size = 14),
    axis.text = element_text(size = 11),
    legend.title = element_text(size = 13),
    legend.text = element_text(size = 11),
    legend.position = "right",
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "grey85")
  )
















# FORECASTING SECTION ----------------------------------------------
# Baseline Model: SARIMA (No Break Adjustment)
# Automatic SARIMA
# Split data
train <- window(ts_electric_consumption, end = c(2023,12))
test  <- window(ts_electric_consumption, start = c(2024,1))

# Fit baseline SARIMA on training set
baseline_model <- auto.arima(train, seasonal = TRUE)
summary(baseline_model)

# Forecast next 12 months
baseline_fc <- forecast(baseline_model, h = 12)

autoplot(baseline_fc) +
  ggtitle("Baseline SARIMA Forecast")+
  scale_y_continuous(labels = scales::comma) 



# Break-Adjusted Model (Dummy Variables)
# Create dummy variables for breaks
regimes <- as.factor(regimes)

dummy_matrix <- model.matrix(~ regimes)[, -1]
break_model <- auto.arima(
  ts_electric_consumption,
  xreg = dummy_matrix,
  seasonal = TRUE
)

summary(break_model)

# Identify last regime
last_regime <- tail(regimes, 1)

# Create future regime vector
future_regimes <- factor(
  rep(last_regime, 12),
  levels = levels(regimes)
)

# Create future dummy matrix
future_dummies <- model.matrix(~ future_regimes)[, -1]
break_fc <- forecast(
  break_model,
  xreg = future_dummies,
  h = 12
)

autoplot(break_fc) +
  ggtitle("Break-Adjusted Model Forecast") +
  scale_y_continuous(labels = scales::comma) 


# STL-Based Forecasting (Enhanced Model)
# Forecast Trend
trend_model <- auto.arima(na.omit(trend_comp))
trend_fc <- forecast(trend_model, h = 12)

# Forecast Remainder
remainder_model <- auto.arima(na.omit(remainder_comp))
remainder_fc <- forecast(remainder_model, h = 12)

# Combine components
seasonal_pattern <- tail(seasonal_comp, 12)

# Combine as numeric vector
final_forecast_vec <- as.numeric(trend_fc$mean) +
  as.numeric(remainder_fc$mean) +
  as.numeric(tail(seasonal_comp, 12))


# Convert explicitly to ts
final_forecast_ts <- ts(
  final_forecast_vec,
  start = tsp(trend_comp)[2] + 1/frequency(trend_comp),
  frequency = frequency(trend_comp)
)

# Convert to ts properly
final_forecast_ts <- ts(
  final_forecast_vec,
  start = end(time(trend_comp)) + 1/frequency(trend_comp),
  frequency = frequency(trend_comp)
)
autoplot(final_forecast_ts) + 
  ggtitle("STL-Based Reconstructed Forecast")

stl_model <- stlf(ts_electric_consumption, h = 12)

autoplot(stl_model) +
  ggtitle("STL-Based Forecast") +
  scale_y_continuous(labels = scales::comma) 



# Adding Prophet Model (Robustness Check)
df_prophet <- data.frame(
  ds = electric_consumption$Date,
  y  = electric_consumption$`Total consumptions`
)

model_prophet <- prophet(df_prophet)
future <- make_future_dataframe(model_prophet, periods = 12, freq = "month")
forecast_prophet <- predict(model_prophet, future)
plot(model_prophet, forecast_prophet)


ggplot(forecast_prophet, aes(x = ds)) +
  
  # Historical data
  geom_line(
    data = model_prophet$history,
    aes(x = ds, y = y),
    color = "black"
  ) +
  
  # Forecast mean
  geom_line(aes(y = yhat), color = "blue") +
  
  # Confidence interval
  geom_ribbon(
    aes(ymin = yhat_lower, ymax = yhat_upper),
    fill = "blue",
    alpha = 0.2
  ) +
  
  ggtitle("Prophet Forecast") +
  xlab("Time") +
  ylab("Electric Consumption") +
  theme_minimal() +
  scale_y_continuous(labels = scales::comma) 


# Forecast Accuracy Comparison
train <- window(ts_electric_consumption, end = c(2023,12))
test  <- window(ts_electric_consumption, start = c(2024,1))

class(fc_baseline)

start(fc_baseline$mean)
end(fc_baseline$mean)

start(test)
end(test)


# Baseline model
fc_baseline <- forecast(baseline_model, h = length(test))
acc_baseline <- accuracy(fc_baseline, test)
acc_baseline


# Break model
regimes <- ts(
  regimes,
  start = start(ts_electric_consumption),
  frequency = frequency(ts_electric_consumption)
)

regimes_train <- window(regimes, end = c(2023,12))
regimes_test  <- window(regimes, start = c(2024,1))

regimes_train <- as.factor(regimes_train)
regimes_test  <- as.factor(regimes_test)

dummy_train <- model.matrix(~ regimes_train)[, -1]

break_model_train <- auto.arima(
  train,
  xreg = dummy_train,
  seasonal = TRUE
)

regimes_test <- factor(regimes_test, levels = levels(regimes_train))

dummy_test <- model.matrix(~ regimes_test)[, -1]

break_fc <- forecast(
  break_model_train,
  xreg = dummy_test,
  h = length(test)
)

acc_break <- accuracy(break_fc, test)
acc_break

# STL model accuracy
# STL forecast on TRAIN only
fc_stl <- stlf(train, h = length(test))

# Check alignment
start(fc_stl$mean)
start(test)

# Compute accuracy
acc_stl <- accuracy(fc_stl, test)
acc_stl


# Prophet Model accuracy
# Convert training data
df_train <- data.frame(
  ds = as.Date(time(train)),
  y  = as.numeric(train)
)

model_prophet <- prophet(df_train)

# Create future dataframe
future <- make_future_dataframe(model_prophet, periods = length(test), freq = "month")

forecast_prophet <- predict(model_prophet, future)

# Extract only forecast period
prophet_fc_values <- tail(forecast_prophet$yhat, length(test))

acc_prophet <- accuracy(prophet_fc_values, test)
acc_prophet


# Combine All Accuracy Results
rbind(
  Baseline = acc_baseline[2,],
  Break_Adjusted = acc_break[2,],
  STL = acc_stl[2,],
  Prophet = acc_prophet[1,]
)

