# Calls into the optional ps package, NULL when it is missing or fails. One
# function so tests can replace it.
ps_call <- function(fun, ...) {
  if (!requireNamespace("ps", quietly = TRUE)) {
    return(NULL)
  }
  tryCatch(getExportedValue("ps", fun)(...), error = \(e) NULL)
}
