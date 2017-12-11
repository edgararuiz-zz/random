


df <- mtcars %>%
  mutate(am = paste0("am", am),
         cyl = paste0("cyl", cyl))

model <-    lm(mpg ~ am + wt + cyl, df)


test_predict <- df %>%
  mutate(
    prediction = !!score(model))

test_predict

df %>%
  predction_to_column(model)