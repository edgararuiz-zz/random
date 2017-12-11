
score <- function(model){
  UseMethod("score")
}

score.lm <- function(model){
  
  mt <- tidymodel(model) %>%
    mutate(sym_labels = syms(labels))
  
  coefs <- filter(mt, type == "categorical") 
  part1 <- map2(coefs$sym_labels, coefs$vals, 
                function(name, val) expr((!!name) == (!!val)))
  f <- map2(part1, coefs$estimate, 
            function(name, est) expr(ifelse(!!name, (!!est), 0)))
  
  coefs <- filter(mt, type == "continuous") 
  f <- c(f,map2(coefs$sym_labels, coefs$estimate, 
                function(name, val) expr((!!name) * (!!val))))
  
  intercept <- filter(mt, labels == "(Intercept)")
  
  if(nrow(intercept) > 0){
    f <- c(f, intercept$estimate)
  }
  
  
  reduce(f, function(l, r) expr((!!l) + (!!r)))
  
}



