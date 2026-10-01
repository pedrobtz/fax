# Environment variable names whose values are hidden by default.
secret_name_pattern <- paste0(
  "key|token|secret|password|passwd|credential|auth|conn(ection)?_?str|sas|header|",
  "(^|_)pat($|_)"
)

redact_env <- function(vars, mode = "default", allowlist = character()) {
  vars <- strip_credentials(vars)
  if (mode == "none") {
    return(vars)
  }
  if (mode == "allowlist") {
    return(vars[names(vars) %in% allowlist])
  }
  secret <- grepl(secret_name_pattern, names(vars), ignore.case = TRUE) &
    !names(vars) %in% allowlist
  vars[secret] <- "<redacted>"
  vars
}

proxy_vars <- c("http_proxy", "https_proxy", "no_proxy", "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY")

register_env_facts <- function() {
  register(resolver("env.vars", cache = FALSE, function(ctx) {
    mode <- getOption("fax.redact", "default")
    if (!mode %in% c("default", "allowlist", "none")) {
      stop("`fax.redact` must be \"default\", \"allowlist\" or \"none\".", call. = FALSE)
    }
    r_note(ctx, "Sys.getenv()")
    vars <- Sys.getenv()
    vars <- stats::setNames(as.character(vars), names(vars))
    redact_env(vars, mode, getOption("fax.redact_allowlist", character()))
  }))

  register(resolver("env.proxies", cache = FALSE, function(ctx) {
    values <- vapply(proxy_vars, \(name) ctx$env(name) %||% NA_character_, character(1))
    values <- values[!is.na(values)]
    if (!length(values)) {
      not_applicable("No proxy is configured.")
    }
    strip_credentials(values)
  }))
}
