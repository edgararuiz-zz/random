
source("model.R")
source("parsemodel.R")


model <- lm(mpg ~ wt + am, data = mtcars)

m2 <- lm(mpg ~ wt + as.factor(am), data = mtcars)

parsemodel(model)



mtcars %>%
  predction_to_column(model) %>%
  head()



