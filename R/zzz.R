.onLoad <- function(libname, pkgname) {
  register_builtins()
}

# Each namespace adds its resolvers here as it is implemented.
register_builtins <- function() {
  registry_reset()
  invisible()
}
