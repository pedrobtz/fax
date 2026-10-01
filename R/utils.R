`%||%` <- function(x, y) if (is.null(x)) y else x

fax_abort <- function(message, ..., class = NULL) {
  if (...length()) {
    message <- sprintf(message, ...)
  }
  cnd <- structure(
    class = c(class, "fax_error", "error", "condition"),
    list(message = message, call = NULL)
  )
  stop(cnd)
}

is_string <- function(x) is.character(x) && length(x) == 1 && !is.na(x)

is_flag <- function(x) is.logical(x) && length(x) == 1 && !is.na(x)
