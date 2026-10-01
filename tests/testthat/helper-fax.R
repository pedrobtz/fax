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

# Fixture trees ship as tarballs (see data-raw/pack-fixtures.R) and are
# extracted once per session.
fixture_names <- function() {
  sub("\\.tar\\.gz$", "", list.files(test_path("fixtures"), "\\.tar\\.gz$"))
}

fixture_root <- function(name) {
  dir <- file.path(tempdir(), "fax-fixtures", name)
  if (!dir.exists(dir)) {
    utils::untar(test_path("fixtures", paste0(name, ".tar.gz")), exdir = dir, tar = "internal")
  }
  dir
}

# Point fax at a fixture, pretending to be Linux.
local_fixture <- function(name, os = "linux", env = parent.frame()) {
  withr::local_options(fax.root = fixture_root(name), fax.os = os, .local_envir = env)
}

# A writable copy of a fixture, for tests that change files between calls.
local_fixture_copy <- function(name, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  files <- list.files(fixture_root(name), full.names = TRUE, all.files = TRUE, no.. = TRUE)
  file.copy(files, dir, recursive = TRUE)
  withr::local_options(fax.root = dir, fax.os = "linux", .local_envir = env)
  dir
}

# One line per fact, for snapshots: name = value [status] source
fixture_report <- function(name) {
  local_fixture(name)
  df <- facts_df(facts(refresh = TRUE))
  as_text <- \(v) paste(if (is.character(v)) v else format(v), collapse = " ")
  value <- vapply(df$value, as_text, character(1))
  # Values read from the live system (not the fixture) differ between machines.
  live <- grepl("^(Sys\\.|parallel::)", df$source)
  value[live] <- "<live>"
  value <- ifelse(nchar(value) > 60, paste0(substr(value, 1, 57), "..."), value)
  paste0(df$fact, " = ", value, " [", df$status, "] ", df$source)
}

local_usage_reset <- function(env = parent.frame()) {
  reset <- function() {
    .usage$pid <- NULL
    .usage$setup <- NULL
    .usage$prev <- NULL
    .usage$last <- NULL
  }
  reset()
  withr::defer(reset(), envir = env)
}
