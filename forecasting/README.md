# Revenue Forecasting

Time series forecasting layer for the E-commerce Analytics Platform. Compares classical statistical, modern, and gradient-boosted approaches against naive baselines on daily revenue from the Brazilian E-Commerce (Olist) dataset.

## Why daily, not monthly

Aggregated monthly the series is too short for serious modelling: roughly 25 months with the first and last partial. SARIMA and Prophet expect ~50+ points for stable parameter estimates, and a LightGBM with seasonal lags would have almost no training rows.

Daily aggregation gives ~600 points spanning two years, exposes weekly seasonality (consumer e-commerce typically peaks mid-week and softens on weekends), and lets each model learn meaningful patterns. Monthly aggregates can still be derived from the daily forecast for business reporting.

## Methods

| Family | Model | Why included |
|---|---|---|
| Baseline | Naive (last value) | Floor for any model to beat |
| Baseline | Seasonal naive (lag 7) | Captures weekly cycle without modelling |
| Modern | Prophet | Native trend + seasonality decomposition, easy CI |
| Machine learning | LightGBM with lag features | Lags 1, 7, 14, 28 + rolling means + Black Friday flag |
| Machine learning | XGBoost | Same features, different tree implementation - sanity check |

## Data cleaning

- Trimmed warm-up period: dropped everything before 2017-01-31 (first date with consistent daily order volume; first weeks averaged 1-3 orders/day during marketplace ramp-up).
- Trimmed truncated tail: dropped everything after 2018-08-21 (later days have incomplete `delivered` status due to the snapshot cutoff; Olist median delivery is ~12 days, so the trail of incomplete days extends ~2 weeks back).
- Final cleaned series: 568 days, 2017-01-31 to 2018-08-21.

> **CLEANED_SERIES**

## Seasonality

STL decomposition (weekly period = 7) confirms three structural components:

- **Trend**: strong upward growth through 2017, plateau in 2018.
- **Weekly cycle**: amplitude scales with the revenue level, so the series is closer to multiplicative than additive seasonality.
- **Residual**: small except for the Black Friday 2017 spike (~125k residual on Nov 24, 2017).

Day-of-week confirms the cycle: Mon-Thu noticeably higher than Sat-Sun. Classic B2C e-commerce pattern.

> **STL**

## Train/test split

- Train: 508 days, 2017-01-31 to 2018-06-22.
- Test: last 60 days, 2018-06-23 to 2018-08-21.
- Black Friday 2017 stays in training. Removing it would inflate metrics but lie about real-world performance - the model has to learn that such days exist.
- Iterative forecasting for tree models: predict t+1, feed the prediction back into lag features when predicting t+2, etc.

## Results

| Model | MAE | RMSE | MAPE % |
|---|---|---|---|
| Naive | 10063.59 | 12359.97 | 28.79 |
| Seasonal naive | 7797.61 | 9905.16 | 23.83 |
| Prophet | 7677.04 | 9497.03 | 27.32 |
| LightGBM | 6375.25 | 8352.34 | 22.21 |
| **XGBoost** | **6060.08** | **8197.58** | **22.23** |

Tree-based models win by a clear margin. LightGBM and XGBoost land within ~5% of each other across all three metrics - the choice between them is taste, the underlying pipeline is the same. Both beat Prophet by ~17% on MAE and seasonal naive by ~22%.

Prophet barely improves on seasonal naive. SARIMA was tested in an earlier iteration and underperformed seasonal naive, so it was dropped. Together this confirms that on a series this short with this much weekly seasonality, sophistication without good features adds nothing - the win comes from engineered lags and the holiday flag.

> **FORECAST_COMPARISON**

## Feature importance

> **FEATURE_IMPORTANCE**

`is_bf` tops the gain ranking, but only because the four Black Friday days carry an extreme target jump in training. The flag is always 0 in the test window, so on the held-out forecast the working features are really `roll_7`, `dow`, and the lag terms (`lag_1`, `lag_7`, `lag_28`). This is a known gotcha with gain-based importance on rare-event features - high gain on training does not imply high contribution at inference time when the feature is dormant.

## Limitations

- 60-day single holdout, no walk-forward refit. A proper production setup would expand the train window weekly and re-fit. On a 600-day series the single split gives a fair read.
- Black Friday is a one-shot event in this dataset. The manual flag worked here because the date is known in advance, but the model has no way to recognise an unannounced future spike.
- No hyperparameter tuning beyond defaults plus a sensible `n_estimators`. Both trees already win, so tuning would be polish, not a regime change.
- Prophet was used without the full Brazilian holiday calendar. Adding it might help marginally on this short series but not enough to change the ranking.

## Files

```
forecasting/
├── 01_revenue_forecast.ipynb   # full notebook: EDA, models, evaluation
├── data/
│   └── daily_revenue.csv       # aggregated from the Postgres view
└── README.md
```

## How to run

The notebook reads `data/daily_revenue.csv`, which is committed for reproducibility (~25 KB). To regenerate from the raw database:

```sql
SELECT
    o.order_purchase_timestamp::date AS day,
    SUM(oi.price + oi.freight_value) AS revenue,
    COUNT(DISTINCT o.order_id) AS orders
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY 1
ORDER BY 1;
```
