# Replace the registry with the given resolvers for the rest of the test.
local_registry <- function(..., opt_in = "packages", env = parent.frame()) {
  old_resolvers <- .fax$resolvers
  old_opt_in <- .fax$opt_in
  .fax$resolvers <- list()
  .fax$opt_in <- opt_in
  cache_clear()
  for (r in list(...)) {
    register(r)
  }
  withr::defer(
    {
      .fax$resolvers <- old_resolvers
      .fax$opt_in <- old_opt_in
      cache_clear()
    },
    envir = env
  )
  invisible()
}

# Write `files` (a named list of path = lines) under a temporary root and point
# `fax.root` at it for the rest of the test.
local_root <- function(files = list(), env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  for (path in names(files)) {
    full <- file.path(root, path)
    dir.create(dirname(full), recursive = TRUE, showWarnings = FALSE)
    writeLines(files[[path]], full)
  }
  withr::local_options(fax.root = root, .local_envir = env)
  root
}

# A resolver that counts how often it runs.
counting_resolver <- function(name, value = 1, ...) {
  calls <- 0
  r <- resolver(
    name,
    function(ctx) {
      calls <<- calls + 1
      value
    },
    ...
  )
  r$calls <- function() calls
  r
}
