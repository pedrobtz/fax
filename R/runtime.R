# Values read from the running R session. Their sources start with "R:" so
# they can be told apart from values read below the root.
r_note <- function(ctx, expr) ctx$note(paste0("R: ", expr))

# Remove credentials from URLs: userinfo and token-like query parameters.
strip_credentials <- function(x) {
  x <- gsub("([A-Za-z][A-Za-z0-9+.-]*://)[^/@[:space:]]+@", "\\1<redacted>@", x)
  gsub(
    "([?&][^=&]*(token|key|auth|sig|secret|password)[^=&]*=)[^&]*",
    "\\1<redacted>",
    x,
    ignore.case = TRUE
  )
}

thread_env_vars <- c(
  "OMP_NUM_THREADS",
  "OMP_THREAD_LIMIT",
  "MKL_NUM_THREADS",
  "OPENBLAS_NUM_THREADS",
  "BLIS_NUM_THREADS",
  "VECLIB_MAXIMUM_THREADS",
  "R_DATATABLE_NUM_THREADS",
  "MC_CORES"
)

register_runtime_facts <- function() {
  register(resolver("runtime.r.version", function(ctx) {
    r_note(ctx, "R.version")
    paste(R.version$major, R.version$minor, sep = ".")
  }))

  register(resolver("runtime.r.platform", function(ctx) {
    r_note(ctx, "R.version$platform")
    R.version$platform
  }))

  register(resolver("runtime.r.home", function(ctx) {
    r_note(ctx, "R.home()")
    R.home()
  }))

  register(resolver("runtime.r.blas", function(ctx) {
    r_note(ctx, "extSoftVersion()")
    blas <- extSoftVersion()[["BLAS"]]
    if (nzchar(blas)) blas else NULL
  }))

  register(resolver("runtime.r.lapack", function(ctx) {
    r_note(ctx, "La_library()")
    c(version = La_version(), library = La_library())
  }))

  register(resolver("runtime.r.libpaths", cache = FALSE, function(ctx) {
    r_note(ctx, ".libPaths()")
    .libPaths()
  }))

  register(resolver("runtime.r.repos", cache = FALSE, function(ctx) {
    r_note(ctx, "getOption(\"repos\")")
    repos <- getOption("repos")
    if (!length(repos)) NULL else strip_credentials(repos)
  }))

  register(resolver("runtime.r.renv", cache = FALSE, function(ctx) {
    project <- ctx$env("RENV_PROJECT")
    if (is.null(project) && file.exists(file.path(getwd(), "renv", "activate.R"))) {
      r_note(ctx, "getwd()")
      project <- getwd()
    }
    if (is.null(project)) {
      not_applicable("No renv project is active.")
    }
    c(project = project, lockfile = file.path(project, "renv.lock"))
  }))

  register(resolver("runtime.threads.env", cache = FALSE, function(ctx) {
    names <- c(
      thread_env_vars,
      grep("^R_PARALLELLY_AVAILABLECORES", names(Sys.getenv()), value = TRUE)
    )
    values <- vapply(names, \(name) ctx$env(name) %||% NA_character_, character(1))
    values[!is.na(values)]
  }))

  register(resolver("runtime.threads.options", cache = FALSE, function(ctx) {
    r_note(ctx, "getOption()")
    c(
      mc.cores = as.numeric(getOption("mc.cores", NA)),
      Ncpus = as.numeric(getOption("Ncpus", NA))
    )
  }))

  register(resolver("runtime.parallelly_cores", cache = FALSE, function(ctx) {
    if (!requireNamespace("parallelly", quietly = TRUE)) {
      not_applicable("The parallelly package is not installed.")
    }
    r_note(ctx, "parallelly::availableCores()")
    as.integer(parallelly::availableCores())
  }))

  # R has a fixed number of connection slots (128 unless R >= 4.4 was started
  # with --max-connections); each parallel worker needs one.
  register(resolver("runtime.r.connections", cache = FALSE, function(ctx) {
    r_note(ctx, "showConnections()")
    arg <- grep("^--max-connections=", commandArgs(), value = TRUE)
    max <- if (length(arg)) as.integer(sub("^.*=", "", arg[1])) else 128L
    used <- nrow(showConnections(all = TRUE))
    c(max = max, used = used, free = max - used)
  }))

  register(resolver("runtime.rlimit.nofile", confine = list(os = "linux"), function(ctx) {
    rlimit(ctx, "Max open files")
  }))
  register(resolver(
    "runtime.rlimit.nofile",
    confine = list(os = \(os) !os %in% c("linux", "windows")),
    id = "runtime.rlimit.nofile/ulimit",
    function(ctx) {
      out <- ctx$cmd("sh", c("-c", shQuote("ulimit -n")))
      value <- if (!is.null(out) && out$status == 0L) trimws(out$stdout[1])
      if (is.null(value)) {
        NULL
      } else if (identical(value, "unlimited")) {
        Inf
      } else {
        parse_limit(value)
      }
    }
  ))

  register(resolver("runtime.pid", cache = FALSE, function(ctx) {
    r_note(ctx, "Sys.getpid()")
    Sys.getpid()
  }))

  register(resolver("runtime.user", function(ctx) {
    r_note(ctx, "Sys.info()")
    user <- Sys.info()[["effective_user"]]
    if (nzchar(user)) user else NULL
  }))

  # Linux: effective ids from /proc/self/status ("Uid: real effective saved fs").
  proc_id <- function(ctx, key) {
    status <- ctx$read_kv("/proc/self/status")
    ids <- if (!is.null(status) && key %in% names(status)) {
      strsplit(status[[key]], "[[:space:]]+")[[1]]
    }
    if (length(ids) < 2) NULL else as.integer(ids[2])
  }
  unix_id <- function(ctx, flag) {
    out <- ctx$cmd("id", flag)
    id <- if (!is.null(out) && out$status == 0L) suppressWarnings(as.integer(out$stdout[1]))
    if (length(id) && !is.na(id)) id else NULL
  }
  linux <- list(os = "linux")
  unix <- list(os = \(os) !os %in% c("linux", "windows"))

  register(resolver("runtime.uid", confine = linux, \(ctx) proc_id(ctx, "Uid")))
  register(resolver("runtime.uid", confine = unix, id = "runtime.uid/id", \(ctx) {
    unix_id(ctx, "-u")
  }))
  register(resolver("runtime.gid", confine = linux, \(ctx) proc_id(ctx, "Gid")))
  register(resolver("runtime.gid", confine = unix, id = "runtime.gid/id", \(ctx) {
    unix_id(ctx, "-g")
  }))

  register(resolver("runtime.privileged", function(ctx) {
    if (ctx$os == "windows") {
      # High (12288) or System (16384) mandatory integrity level: elevated.
      out <- ctx$cmd("whoami", "/groups", timeout = 3)
      if (is.null(out) || out$status != 0L) {
        return(NULL)
      }
      return(any(grepl("S-1-16-12288|S-1-16-16384", out$stdout)))
    }
    uid <- ctx$fact("runtime.uid")
    if (is.na(uid)) NULL else uid == 0L
  }))
}
