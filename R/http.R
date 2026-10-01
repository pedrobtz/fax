# HTTP access is limited to instance metadata endpoints. Anything not on the
# allowlist is refused before any connection is made, so identity and token
# endpoints can never be reached.
http_allowlist <- c(
  "^http://169\\.254\\.169\\.254/metadata/instance\\?api-version=[0-9-]+$"
)

http_allowed <- function(url) {
  is_string(url) && any(vapply(http_allowlist, \(p) grepl(p, url), logical(1)))
}

# Returns list(status, body). Tests replace the transport with
# `options(fax.http_mock = function(url, headers) ...)`.
http_get <- function(url, headers = character(), timeout = 1) {
  if (!http_allowed(url)) {
    fax_abort("Refusing to request %s: not on the fax allowlist.", url, class = "fax_http_refused")
  }
  mock <- getOption("fax.http_mock")
  if (is.function(mock)) {
    return(mock(url, headers))
  }
  http_transport(url, headers, timeout)
}

http_transport <- function(url, headers, timeout) {
  unavailable("HTTP transport is not implemented yet.")
}
