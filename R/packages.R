# Package inventories. All three facts are data frames, live in the opt-in
# `packages` namespace, and are read on every call (packages change).

# Debian-style "Key: value" stanzas separated by blank lines -> data frame
# with one row per stanza and one column per field. Continuation lines
# (starting with whitespace) are ignored.
parse_stanzas <- function(lines, fields, sep = ":") {
  stanza <- cumsum(!nzchar(lines))
  keep <- nzchar(lines) & !grepl("^[[:space:]]", lines)
  lines <- lines[keep]
  stanza <- stanza[keep]
  pos <- regexpr(sep, lines, fixed = TRUE)
  key <- ifelse(pos > 0, substr(lines, 1, pos - 1), "")
  value <- trimws(substring(lines, pos + nchar(sep)))
  ids <- unique(stanza)
  out <- lapply(fields, function(field) {
    sel <- key == field
    value[sel][match(ids, stanza[sel])]
  })
  names(out) <- fields
  as.data.frame(out, check.names = FALSE)
}

empty_packages <- function(...) {
  cols <- list(...)
  data.frame(name = character(), version = character(), lapply(cols, \(x) character()))
}

dpkg_packages <- function(ctx) {
  lines <- ctx$read("/var/lib/dpkg/status")
  if (is.null(lines)) {
    # Distroless images keep one stanza per package in status.d instead.
    files <- ctx$list_dir("/var/lib/dpkg/status.d")
    files <- files[!grepl("\\.md5sums$", files)]
    if (!length(files)) {
      return(NULL)
    }
    lines <- unlist(lapply(files, function(f) {
      c(read_lines(file.path("/var/lib/dpkg/status.d", f), ctx$root), "")
    }))
  }
  db <- parse_stanzas(lines, c("Package", "Status", "Version", "Architecture"))
  db <- db[!is.na(db$Status) & endsWith(db$Status, " installed"), ]
  data.frame(name = db$Package, version = db$Version, arch = db$Architecture)
}

apk_packages <- function(ctx) {
  lines <- ctx$read("/lib/apk/db/installed")
  if (is.null(lines)) {
    return(NULL)
  }
  db <- parse_stanzas(lines, c("P", "V", "A"))
  data.frame(name = db$P, version = db$V, arch = db$A)
}

pacman_packages <- function(ctx) {
  dirs <- ctx$list_dir("/var/lib/pacman/local")
  dirs <- setdiff(dirs, "ALPM_DB_VERSION")
  if (!length(dirs)) {
    return(NULL)
  }
  rows <- lapply(dirs, function(dir) {
    desc <- read_lines(file.path("/var/lib/pacman/local", dir, "desc"), ctx$root)
    field <- function(header) {
      i <- match(header, desc)
      if (is.na(i) || i == length(desc)) NA_character_ else desc[i + 1]
    }
    c(field("%NAME%"), field("%VERSION%"), field("%ARCH%"))
  })
  m <- matrix(unlist(rows), ncol = 3, byrow = TRUE)
  out <- data.frame(name = m[, 1], version = m[, 2], arch = m[, 3])
  out[!is.na(out$name), ]
}

rpm_packages <- function(ctx) {
  if (!ctx$exists("/var/lib/rpm") && !ctx$exists("/usr/lib/sysimage/rpm")) {
    return(NULL)
  }
  format <- shQuote("%{NAME}\\t%{VERSION}-%{RELEASE}\\t%{ARCH}\\n")
  out <- ctx$cmd("rpm", c("-qa", "--qf", format), timeout = 30)
  if (is.null(out) || out$status != 0L) {
    return(NULL)
  }
  parts <- strsplit(out$stdout[nzchar(out$stdout)], "\t", fixed = TRUE)
  parts <- parts[lengths(parts) == 3]
  m <- matrix(unlist(parts), ncol = 3, byrow = TRUE)
  data.frame(name = m[, 1], version = m[, 2], arch = m[, 3])
}

homebrew_prefixes <- c("/opt/homebrew", "/usr/local", "/home/linuxbrew/.linuxbrew")

homebrew_packages <- function(ctx) {
  prefixes <- c(ctx$env("HOMEBREW_PREFIX"), homebrew_prefixes)
  prefix <- Find(\(p) ctx$exists(file.path(p, "Cellar")), prefixes)
  if (is.null(prefix)) {
    return(NULL)
  }
  kegs <- function(dir, kind) {
    names <- ctx$list_dir(file.path(prefix, dir)) %||% character()
    rows <- lapply(names, function(name) {
      versions <- setdiff(ctx$list_dir(file.path(prefix, dir, name)) %||% character(), ".metadata")
      if (length(versions)) data.frame(name = name, version = versions, kind = kind)
    })
    do.call(rbind, rows)
  }
  out <- rbind(kegs("Cellar", "formula"), kegs("Caskroom", "cask"))
  if (is.null(out)) empty_packages(kind = "") else out
}

# Uninstall registry entries -> list of named character vectors. A function so
# tests can replace it; readRegistry() only exists on Windows.
read_uninstall_registry <- function() {
  key <- "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
  sources <- list(
    list(hive = "HLM", view = "64-bit"),
    list(hive = "HLM", view = "32-bit"),
    list(hive = "HCU", view = "default")
  )
  read_registry <- get("readRegistry", envir = asNamespace("utils"))
  entries <- lapply(sources, function(src) {
    tryCatch(
      read_registry(key, hive = src$hive, view = src$view, maxdepth = 2),
      error = \(e) list()
    )
  })
  unlist(entries, recursive = FALSE)
}

windows_packages <- function(ctx) {
  ctx$note("registry: HKLM/HKCU ...\\CurrentVersion\\Uninstall")
  entries <- read_uninstall_registry()
  field <- function(entry, name) {
    value <- entry[[name]]
    if (is.null(value) || !nzchar(value[1])) NA_character_ else as.character(value[1])
  }
  rows <- lapply(entries, function(entry) {
    if (!is.list(entry) || identical(entry[["SystemComponent"]], 1L)) {
      return(NULL)
    }
    name <- field(entry, "DisplayName")
    if (is.na(name)) {
      return(NULL)
    }
    data.frame(
      name = name,
      version = field(entry, "DisplayVersion"),
      publisher = field(entry, "Publisher")
    )
  })
  out <- unique(do.call(rbind, rows))
  if (is.null(out)) empty_packages(publisher = "") else out
}

system_managers <- list(
  list(id = "dpkg", fun = dpkg_packages, os = "linux"),
  list(id = "rpm", fun = rpm_packages, os = "linux"),
  list(id = "apk", fun = apk_packages, os = "linux"),
  list(id = "pacman", fun = pacman_packages, os = "linux"),
  list(id = "homebrew", fun = homebrew_packages, os = c("darwin", "linux")),
  list(id = "windows", fun = windows_packages, os = "windows")
)

# R packages ------------------------------------------------------------

r_packages <- function(ctx) {
  r_note(ctx, "installed.packages()")
  fields <- c("Repository", "RemoteType", "RemoteSha")
  ip <- utils::installed.packages(fields = fields)
  source <- ifelse(is.na(ip[, "RemoteType"]), ip[, "Repository"], ip[, "RemoteType"])
  out <- data.frame(
    name = unname(ip[, "Package"]),
    version = unname(ip[, "Version"]),
    libpath = unname(ip[, "LibPath"]),
    priority = unname(ip[, "Priority"]),
    built = unname(ip[, "Built"]),
    source = unname(source),
    remote_sha = unname(ip[, "RemoteSha"])
  )
  rownames(out) <- NULL
  out
}

# Python packages -------------------------------------------------------

pep503 <- function(name) gsub("[-_.]+", "-", tolower(name))

# "<name>-<version>.dist-info" or "<name>-<version>[-pyX.Y].egg-info".
site_packages_rows <- function(ctx, dir) {
  entries <- ctx$list_dir(dir) %||% character()
  meta <- entries[grepl("\\.(dist|egg)-info$", entries)]
  if (!length(meta)) {
    return(NULL)
  }
  stem <- sub("\\.(dist|egg)-info$", "", meta)
  name <- sub("-.*$", "", stem)
  version <- ifelse(grepl("-", stem, fixed = TRUE), sub("^[^-]*-", "", stem), NA_character_)
  version <- sub("-py[0-9.]+$", "", version)
  installer <- vapply(
    meta,
    function(m) {
      line <- read_lines(file.path(dir, m, "INSTALLER"), ctx$root, n = 1L)
      if (length(line)) trimws(line[1]) else NA_character_
    },
    character(1),
    USE.NAMES = FALSE
  )
  data.frame(
    name = pep503(name),
    version = version,
    location = dir,
    installer = installer,
    source = "site-packages"
  )
}

# conda-meta/<name>-<version>-<build>.json
conda_rows <- function(ctx, prefix) {
  files <- grep(
    "\\.json$",
    ctx$list_dir(file.path(prefix, "conda-meta")) %||% character(),
    value = TRUE
  )
  if (!length(files)) {
    return(NULL)
  }
  stem <- sub("\\.json$", "", files)
  m <- regmatches(stem, regexec("^(.*)-([^-]+)-([^-]+)$", stem))
  m <- m[lengths(m) == 4]
  data.frame(
    name = vapply(m, `[`, "", 2),
    version = vapply(m, `[`, "", 3),
    location = file.path(prefix, "conda-meta"),
    installer = "conda",
    source = "conda"
  )
}

register_packages_facts <- function() {
  for (i in seq_along(system_managers)) {
    manager <- system_managers[[i]]
    local({
      fun <- manager$fun
      register(resolver(
        "packages.system.installed",
        confine = list(os = manager$os),
        weight = 100 - i,
        cache = FALSE,
        id = paste0("packages.system.installed/", manager$id),
        function(ctx) fun(ctx)
      ))
    })
  }

  register(resolver("packages.system.manager", cache = FALSE, function(ctx) {
    rec <- ctx$fact_record("packages.system.installed")
    if (rec$status != "ok") {
      not_applicable("No supported package manager found.")
    }
    sub("^packages\\.system\\.installed/", "", rec$resolver)
  }))

  register(resolver("packages.system.count", cache = FALSE, function(ctx) {
    installed <- ctx$fact("packages.system.installed")
    if (!is.data.frame(installed)) NULL else nrow(installed)
  }))

  register(resolver("packages.r", cache = FALSE, r_packages))

  register(resolver("packages.python", cache = FALSE, function(ctx) {
    sites <- ctx$fact("runtime.python.site_packages")
    if (anyNA(sites)) {
      not_applicable("No Python site-packages found.")
    }
    rows <- lapply(sites, \(dir) site_packages_rows(ctx, dir))
    prefix <- ctx$fact("runtime.python.env_path")
    if (identical(ctx$fact("runtime.python.env_type"), "conda") && !is.na(prefix)) {
      rows <- c(rows, list(conda_rows(ctx, prefix)))
    }
    out <- do.call(rbind, rows)
    if (is.null(out)) {
      out <- data.frame(
        name = character(),
        version = character(),
        location = character(),
        installer = character(),
        source = character()
      )
    }
    out
  }))
}
