
predction_to_column <- function(df, model,  var = "prediction", ...){

      mutate(df, !! var := score(model))
}

