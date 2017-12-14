
source("model.R")
source("parsemodel.R")


m1 <- lm(mpg ~ wt + am, weights = cyl, data = mtcars)
summary(m1)

m2 <- lm(mpg ~ wt + am, data = mtcars)
summary(m2)

m3 <- lm(mpg ~ wt + am, offset = cyl, data = mtcars)
summary(m3)

df <- mtcars %>%
  mutate(am = paste0("am", am))
  
m4 <- lm(mpg ~ wt + am, data = df)

a1 <- as.numeric(predict(m1, mtcars))
a2 <- as.numeric(predict(m2, mtcars))
a3 <- as.numeric(predict(m3, mtcars))
a4 <- as.numeric(predict(m4, df))


b1 <- prediction_to_column(mtcars, m1) %>% pull()
b2 <- prediction_to_column(mtcars, m2) %>% pull()
b3 <- prediction_to_column(mtcars, m3) %>% pull()
b4 <- prediction_to_column(df, m4) %>% pull()


sum(a1 - b1 > 0.0001)
sum(a2 - b2 > 0.0001)
sum(a3 - b3 > 0.0001)
sum(a4 - b4 > 0.0001) 



