
## As suggested by @topepo, brought in from the `pryr` package
## via the `recepies` package

fun_calls <- function(f) {
  if (is.function(f)) {
    fun_calls(body(f))
  } else if (is.call(f)) {
    fname <- as.character(f[[1]])
    # Calls inside .Internal are special and shouldn't be included
    if (identical(fname, ".Internal"))
      return(fname)
    unique(c(fname, unlist(lapply(f[-1], fun_calls), use.names = FALSE)))
  }
}

acceptable_formula <- function(model){
  UseMethod("acceptable_formula")
}

acceptable_formula.default <- function(model){
  
  # Check for invalid contrasts
  if(length(model$contrasts)){
    contr <- model$contrasts
    contr <- contr[!("contr.treatment"  %in% model$contrasts)]
    if(length(contr >0)){
      stop(
        "The treatment contrast is the only one supported at this time. Field(s) with an invalid contrast are: ",
        paste0("`", names(contr), "`", collapse = ","),
        call. = FALSE)     
    }
  }
  
  # Check for in-line formulas
  funs <- fun_calls(model$call)
  funs <- funs[!(funs %in% c("~", "+", "-", "lm", "glm"))]
  if(length(funs) > 0){
    stop(
      "Functions inside the formula are not supported. Functions detected: ",
      paste0("`", funs, "`", collapse = ","), ". Use `dplyr` transformations to prepare the data.",
      call. = FALSE)
  }
}

score <- function(model){
  UseMethod("score")
}

score.default <- function(model){
  
  acceptable_formula(model)
  
  mt <- parsemodel(model) %>%
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
  
  offset <- model$call$offset
  if(!is.null(offset)){
    f <- c(f, offset)
  }
  
  
  reduce(f, function(l, r) expr((!!l) + (!!r)))
  
}



prediction_to_column <- function(df, model,  var = "prediction", ...){
  mutate(df, !!var := (!!score(model)))
}
