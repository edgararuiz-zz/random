dplyr and in-database scoring
================

-   [Motivation](#motivation)
-   [Functions](#functions)
    -   [Parse an R model](#parse-an-r-model)
    -   [Save results (w/o importing them into memory)](#save-results-wo-importing-them-into-memory)
-   [Quick demo](#quick-demo)
    -   [Local data](#local-data)
    -   [`lm` Model](#lm-model)
    -   [`score()`](#score)
    -   [Database](#database)
-   [`db_update()`](#db_update)
    -   [Confirm accurracy](#confirm-accurracy)
-   [`parsemodel()`](#parsemodel)
-   [`prediction_to_column()`](#prediction_to_column)

Motivation
----------

Even if the capability to run models inside the database would be available today, R users may still elect to fit the model locally in R with samples. Running `predict()` may be an entirely different story. It is more likely that predictions need to be run over the entire data set.

The idea is to use the same approach as `dbplot` of using `dplyr` and `rlang` to create a generic formula that can then be translated to SQL appropriate syntax.

Functions
---------

### Parse an R model

The `score()` function decomposes the model variables and builds a `dplyr` formula. The `score()` function uses the model’s `class` to use the correct parser.

``` r
source("parsemodel.R")
source("model.R")
```

### Save results (w/o importing them into memory)

The `db_update()` function sends uses the `UPDATE` clause to apply the formula created in `score()`. This enables the entire calculation and recording the new values exclusively inside the database. The function uses the `sql_translate()` command to translate the `dplyr` formula into a vendor appropriate SQL statement:

``` r
db_update <- function(con, table, data, model, prediction_var = NULL ) {
  UseMethod("db_update")
}

db_update.DBIConnection <- function(con, table, data, model, prediction_var = NULL ) {
  
  f <- score(model)
  
  dbSendQuery(con, build_sql("UPDATE ", table ," SET ", prediction_var, " = ", translate_sql(!!f, con = con)))

}
```

Quick demo
----------

### Local data

``` r
df <- tibble(
  x = c(1, 2, 3, 4, 5, 6, 7, 8 , 9),
  y = c(1.1, 2.5, 3.5, 4.75, 5.25, 6.55, 7.66, 8.2, 10),
  z = c("a", "a", "a", "b", "a", "a", "b", "b", "b"),
  score = c(0,0,0,0,0,0,0,0,0)
)
```

### `lm` Model

``` r
model <- lm(y ~ x + z, df)
summary(model)
```

    ## 
    ## Call:
    ## lm(formula = y ~ x + z, data = df)
    ## 
    ## Residuals:
    ##     Min      1Q  Median      3Q     Max 
    ## -0.4730 -0.1628  0.1167  0.1487  0.3065 
    ## 
    ## Coefficients:
    ##             Estimate Std. Error t value Pr(>|t|)    
    ## (Intercept)  0.31026    0.21251   1.460    0.195    
    ## x            1.02051    0.05037  20.260 9.39e-07 ***
    ## zb           0.19865    0.26173   0.759    0.477    
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ## Residual standard error: 0.2813 on 6 degrees of freedom
    ## Multiple R-squared:  0.9928, Adjusted R-squared:  0.9904 
    ## F-statistic: 415.7 on 2 and 6 DF,  p-value: 3.677e-07

### `score()`

The `score()` function can be used in-place of `predict()`. It breaks down the model data to create a formula that can be parsed by `dplyr`, and thus can be potentially parsed by any database that has a `dplyr` translation:

``` r
score(model)
```

    ## ((ifelse((z) == ("b"), (0.198653846153846), 0)) + ((x) * (1.02051282051282))) + 
    ##     (0.31025641025641)

### Database

Open an RSQLite connection:

``` r
con <- dbConnect(RSQLite::SQLite(), path = ":memory:")
dbWriteTable(con, "df", df)
```

`db_update()`
-------------

Run `db_update()` to save the new results inside the `score` field.

``` r
db_update(con, "df", tbl(con, "df"), model, "score")
```

    ## <SQLiteResult>
    ##   SQL  UPDATE 'df' SET 'score' = ((CASE WHEN ((`z`) = ('b')) THEN ((0.198653846153846)) ELSE (0.0) END) + ((`x`) * (1.02051282051282))) + (0.31025641025641)
    ##   ROWS Fetched: 0 [complete]
    ##        Changed: 9

### Confirm accurracy

``` r
tbl(con, "df")
```

    ## # Source:   table<df> [?? x 4]
    ## # Database: sqlite 3.19.3 []
    ##       x     y     z    score
    ##   <dbl> <dbl> <chr>    <dbl>
    ## 1     1  1.10     a 1.330769
    ## 2     2  2.50     a 2.351282
    ## 3     3  3.50     a 3.371795
    ## 4     4  4.75     b 4.590962
    ## 5     5  5.25     a 5.412821
    ## 6     6  6.55     a 6.433333
    ## 7     7  7.66     b 7.652500
    ## 8     8  8.20     b 8.673013
    ## 9     9 10.00     b 9.693526

The results from `predict()` are the exact same as those returned by `score()`

``` r
predict(model, df)
```

    ##        1        2        3        4        5        6        7        8 
    ## 1.330769 2.351282 3.371795 4.590962 5.412821 6.433333 7.652500 8.673013 
    ##        9 
    ## 9.693526

`parsemodel()`
--------------

The `parsemodel()` function makes a quick tidy table from the model. This helps simplify the`socre()` code. The source code is inside the `tidymodel.R` script.

``` r
parsemodel(model)
```

    ## # A tibble: 3 x 7
    ##        labels  vals  estimate  std_error    t_value           pr
    ##         <chr> <chr>     <dbl>      <dbl>      <dbl>        <dbl>
    ## 1 (Intercept)       0.3102564 0.21251009  1.4599608 1.945945e-01
    ## 2           x       1.0205128 0.05036972 20.2604416 9.394300e-07
    ## 3           z     b 0.1986538 0.26172876  0.7590066 4.765978e-01
    ## # ... with 1 more variables: type <chr>

`prediction_to_column()`
------------------------

The `score()` function can be called inside a `dplyr` verb, so it can also be used with local data. A function similar to `tibble::rowid_to_column`, currently called `prediction_to_column()` can be used with a local `data.frame` to easily add a column with the fitted values.

``` r
df %>%
  prediction_to_column(model)
```

    ## # A tibble: 9 x 5
    ##       x     y     z score prediction
    ##   <dbl> <dbl> <chr> <dbl>      <dbl>
    ## 1     1  1.10     a     0   1.330769
    ## 2     2  2.50     a     0   2.351282
    ## 3     3  3.50     a     0   3.371795
    ## 4     4  4.75     b     0   4.590962
    ## 5     5  5.25     a     0   5.412821
    ## 6     6  6.55     a     0   6.433333
    ## 7     7  7.66     b     0   7.652500
    ## 8     8  8.20     b     0   8.673013
    ## 9     9 10.00     b     0   9.693526
