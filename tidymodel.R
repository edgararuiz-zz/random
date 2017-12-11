# 
library(dplyr)
library(purrr)
library(rlang)
library(tibble)

tidymodel <- function(model){
  UseMethod("tidymodel")
}


tidymodel.lm <- function(model){
  
  
  terms <- model$terms
  
  labels <- attr(terms, "term.labels")
  
  tidy <- tibble(labels)
  
  xl <- model$xlevels
  xlevels <- names(xl) %>%
    map({~tibble(
      labels = .x,
      vals = as.character(xl[[.x]])) %>%
        rowid_to_column("row")}
    ) %>%
    bind_rows() %>%
    filter(row > 1) %>%
    select(-row)
  
  tidy <- tidy %>%
    left_join(xlevels, by = "labels") %>%
    mutate(vals = ifelse(is.na(vals), "", vals))
  
  i <- attr(terms, "intercept")
  if(!is.null(i)){
    tidy <-
      tibble(
        labels = "(Intercept)",
        vals = ""
      ) %>%
      bind_rows(tidy) 
  }
  
  
  c <- summary(model)$coefficients 
  coef_labels <- attr(c, "dimnames")[[1]]
  
  coef <- as_tibble(c) %>%
    mutate(coef_labels = coef_labels)
  
  tidy <- tidy %>%
    bind_cols(coef) %>%
    mutate(confirm_label = paste0(labels, vals),
           confirm = coef_labels == confirm_label) %>%
    mutate(
      type = case_when(
        labels == "(Intercept)" ~ "intercept",
        vals == "" ~ "continuous",
        vals != "" ~ "categorical",
        TRUE ~ "error"
      ))
  
  errors <- nrow(filter(tidy, type == "error"))
  
  if(all(tidy$confirm) & errors == 0){
    tidy %>%
      select(
        -confirm,
        -confirm_label,
        -coef_labels
      ) %>%
      rename(
        pr = `Pr(>|t|)`,
        t_value = `t value`,
        std_error = `Std. Error`,
        estimate = Estimate
      ) 
  } else {
    stop(
      "Error parsing the model"
    )
  }
  
}