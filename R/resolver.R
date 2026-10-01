# A resolver computes one fact. Several resolvers may provide the same fact;
# the highest-weight one whose `confine` predicates pass is used, falling
# through to the next one when it reports "unavailable".
#
# `confine` is a named list. The name "os" matches against fax_os(); any other
# name is a fact whose value is checked. Each element is either a vector of
# accepted values or a function(value) returning TRUE/FALSE.
resolver <- function(
  name,
  resolve,
  confine = list(),
  weight = 100,
  network = FALSE,
  cache = TRUE,
  id = name
) {
  if (!is_string(name) || !grepl(fact_name_pattern, name)) {
    fax_abort("`name` must be a dotted lower-case fact name, not %s.", format(name)[1])
  }
  if (!is.function(resolve)) {
    fax_abort("`resolve` must be a function.")
  }
  if (!is.list(confine) || (length(confine) && is.null(names(confine)))) {
    fax_abort("`confine` must be a named list.")
  }
  if (!is.numeric(weight) || length(weight) != 1 || is.na(weight)) {
    fax_abort("`weight` must be a single number.")
  }
  if (!is_flag(network) || !is_flag(cache)) {
    fax_abort("`network` and `cache` must be TRUE or FALSE.")
  }
  structure(
    list(
      name = name,
      resolve = resolve,
      confine = confine,
      weight = weight,
      network = network,
      cache = cache,
      id = id
    ),
    class = "fax_resolver"
  )
}

fact_name_pattern <- "^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$"

# Signalled by resolvers to set a status other than "ok".
unavailable <- function(message = "No data found.") {
  stop(structure(
    class = c("fax_unavailable", "condition"),
    list(message = message, call = NULL)
  ))
}

not_applicable <- function(message) {
  stop(structure(
    class = c("fax_not_applicable", "condition"),
    list(message = message, call = NULL)
  ))
}

# Registry ---------------------------------------------------------------

.fax <- new.env(parent = emptyenv())
.fax$resolvers <- list()
.fax$opt_in <- "packages"
.fax$cache <- new.env(parent = emptyenv())
.fax$python_probe <- list()
.fax$imds <- list()

namespace_order <- c(
  "os",
  "cpu",
  "memory",
  "cgroup",
  "virtualization",
  "container",
  "k8s",
  "cloud",
  "runtime",
  "env",
  "disk",
  "packages"
)

register <- function(r) {
  existing <- setdiff(names(.fax$resolvers) %||% character(), r$name)
  clash <- startsWith(existing, paste0(r$name, ".")) |
    startsWith(r$name, paste0(existing, "."))
  if (any(clash)) {
    fax_abort(
      "Fact `%s` clashes with `%s`: a fact cannot also be a group of facts.",
      r$name,
      existing[clash][1]
    )
  }
  current <- .fax$resolvers[[r$name]]
  current <- Filter(\(x) !identical(x$id, r$id), current)
  current <- c(current, list(r))
  weights <- vapply(current, `[[`, numeric(1), "weight")
  .fax$resolvers[[r$name]] <- current[order(weights, decreasing = TRUE)]
  invisible(r)
}

registry_reset <- function() {
  .fax$resolvers <- list()
  cache_clear()
}

cache_clear <- function() {
  .fax$cache <- new.env(parent = emptyenv())
  .fax$python_probe <- list()
  .fax$imds <- list()
}

fact_namespace <- function(name) sub("\\..*$", "", name)

known_facts <- function(namespace = NULL) {
  facts <- names(.fax$resolvers)
  if (!is.null(namespace)) {
    facts <- facts[fact_namespace(facts) == namespace]
  }
  facts
}

known_namespaces <- function() {
  ns <- unique(fact_namespace(names(.fax$resolvers)))
  ns[order(match(ns, namespace_order), ns)]
}

default_namespaces <- function() setdiff(known_namespaces(), .fax$opt_in)
