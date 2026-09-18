library(tsibble)
library(lubridate)
library(feasts)
library(corrplot)
library(dplyr)
library(ggplot2)
library(here)

data <- read.csv(here("data", "clean_data.csv"))

# Change type of Date column to Date
data <- data %>% mutate(Date = as.Date(as.character(Date), format = "%Y-%m-%d"))

# Turn Date into time series
ts_data <- as_tsibble(data, index = Date)

# ----------------- Descriptive Statistics ----------------#
summary(ts_data)
sd(ts_data$Price)

# Plot the data
plot(ts_data$Date, ts_data$Price, type = "l",
     main = "EUR/VND Exchange Rate",
     xlab = "Year", ylab = "Exchange Rate (VND)",
     col = "blue", lwd = 1)

# Correlation matrix
M <- cor(ts_data[,-1])
corrplot(M, method = 'number')

# Scatter plots of independent and dependent variables
ggplot(ts_data, aes(x = High, y = Price)) +
  geom_point(color = "black", alpha = 0.6) +
  geom_smooth(method = "lm", se = FALSE, color = "red") +
  labs(title = "Price vs High (EUR/VND)",
       x = "High",
       y = "Price") +
  theme_minimal()

ggplot(ts_data, aes(x = Low, y = Price)) +
  geom_point(color = "black", alpha = 0.6) +
  geom_smooth(method = "lm", se = FALSE, color = "red") +
  labs(title = "Price vs Low (EUR/VND)",
       x = "Low",
       y = "Price") +
  theme_minimal()

ggplot(ts_data, aes(x = Open, y = Price)) +
  geom_point(color = "black", alpha = 0.6) +
  geom_smooth(method = "lm", se = FALSE, color = "red") +
  labs(title = "Price vs Open (EUR/VND)",
       x = "Open",
       y = "Price") +
  theme_minimal()

ggplot(ts_data, aes(x = Price_lag1, y = Price)) +
  geom_point(color = "black", alpha = 0.6) +
  geom_smooth(method = "lm", se = FALSE, color = "red") +
  labs(title = "Price vs Previous Day Price (EUR/VND)",
       x = "Previous Day Price",
       y = "Price") +
  theme_minimal()

ggplot(ts_data, aes(x = TimeIndex, y = Price)) +
  geom_point(color = "black", alpha = 0.6) +
  geom_smooth(method = "lm", se = FALSE, color = "red") +
  labs(title = "Price vs TimeIndex (EUR/VND)",
       x = "Time Index",
       y = "Price") +
  theme_minimal()

ggplot(ts_data, aes(x = Change, y = Price)) +
  geom_point(color = "black", alpha = 0.6) +
  geom_smooth(method = "lm", se = FALSE, color = "red") +
  labs(title = "Price vs Change (EUR/VND)",
       x = "Change",
       y = "Price") +
  theme_minimal()

#------------- Autoregressive Regression (AR) ---------------#
model_ar <- lm(Price ~ Price_lag1 + Price_lag2, data = ts_data)
summary(model_ar)

# Predict
ts_data$ARPredicted <- predict(model_ar)

# Residuals
res <- signif(residuals(model_ar), 3)
plot(ts_data$Date, ts_data$Price)
segments(ts_data$Date, ts_data$Price, 
         ts_data$Date, ts_data$ARPredicted, col="blue")

acf(res, main = "ACF of AR Residuals")

# Calculate and plot the standardised residuals
model_ar.stdRes = rstandard(model_ar)
plot(model_ar.stdRes, col="blue")
abline(0,0, col="red", lwd=2)

hist(model_ar.stdRes)

# Forecast next day
last_lag1 <- tail(ts_data$Price, 1)        # last trading day
last_lag2 <- tail(ts_data$Price, 2)[1]     # second-last trading day

next_day <- data.frame(
  Price_lag1 = last_lag1,
  Price_lag2 = last_lag2
)

forecast_ar <- predict(model_ar, newdata = next_day)
forecast_ar

# Evaluation
summary(model_ar)$r.squared  #R2

# MAE and MSE
errors_ar <- ts_data$Price - ts_data$ARPredicted
MAE_AR <- mean(abs(errors_ar))
MAE_AR
MSE_AR <- mean(errors_ar^2)
MSE_AR
RMSE_AR <- sqrt(MSE_AR)
RMSE_AR

#------------- Multiple Linear Regression -------------#
model_mlr <- lm(Price ~ Price_lag1 + Price_lag2 + Open + 
                      High + Low + TimeIndex, 
                    data = ts_data)

summary(model_mlr)

# Predict
ts_data$MLRPredicted <- predict(model_mlr)

# Visualize actual vs predicted
ggplot(ts_data, aes(Date)) +
  geom_line(aes(y = Price, color = "Actual"), size = 1) +
  geom_line(aes(y = MLRPredicted, color = "Predicted"), size = 1) +
  scale_color_manual(values = c("Actual" = "blue", "Predicted" = "red")) +
  labs(title = "Linear Regression Prediction for EUR/VND",
       y = "EUR/VND Price") +
  theme_minimal()

# Residual
res3 <- signif(residuals(model_mlr), 3)
plot(ts_data$Date, ts_data$Price)
segments(ts_data$Date, ts_data$Price, 
         ts_data$Date, ts_data$MLRPredicted, col="blue")

# Calculate and plot the standardised residuals
model_mlr.stdRes = rstandard(model_mlr)
plot(model_mlr.stdRes, col="blue")
abline(0,0, col="red", lwd=2)

hist(model_mlr.stdRes)

acf(res3, main = "ACF of MLR Residuals")

# Forecast next day
last <- tail(ts_data, 1)

next_input <- data.frame(
  Price_lag1 = last$Price_lag1,
  Price_lag2 = last$Price_lag2,
  Open = last$Open,
  High = last$High,
  Low  = last$Low,
  TimeIndex = last$TimeIndex + 1
)

forecast_mlr <- predict(model_mlr, newdata = next_input)
forecast_mlr

#-------------- Evaluation -------------#
# R2
summary(model_mlr)$r.squared

# MAE and MSE
errors_mlr <- ts_data$Price - ts_data$MLRPredicted
MAE_MLR <- mean(abs(errors_mlr))
MAE_MLR
MSE_MLR <- mean(errors_mlr^2)
MSE_MLR
RMSE_MLR <- sqrt(MSE_MLR)
RMSE_MLR

#--------------- PCA -------------------#
eur_data <- ts_data[, c("Open", "High", "Low",
                        "Change", "Price_lag1", "Price_lag2")]
eur_scaled <- scale(eur_data)

# Extraction method: eigenvalue decomposition
pca_eur <- prcomp(eur_scaled, center = TRUE, scale. = TRUE)

# Total Variance Explained
summary(pca_eur)

# Component Matrix
pca_eur$rotation

# Scree plot
plot(pca_eur, type = "l",
     main = "Scree Plot for EUR/VND PCA")

# Communalities
communalities <- rowSums(pca_eur$rotation^2)
communalities

# Component scores
eur_scores <- as.data.frame(pca_eur$x)
head(eur_scores)

# Component Plot
ggplot(eur_scores, aes(PC1, PC2)) +
  geom_point(alpha = 0.6, color = "blue") +
  labs(title = "Component Plot (PC1 vs PC2)",
       x = "PC1",
       y = "PC2") +
  theme_minimal()
