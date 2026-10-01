# cgroup discovery shared by the cgroup, cpu and memory namespaces and by the
# usage probe. See design §6.

cgroup_controllers <- c("cpu", "cpuacct", "cpuset", "memory", "pids")

# mountinfo lines -> data frame of root, mountpoint, fstype, superopts.
parse_mountinfo <- function(lines) {
  empty <- data.frame(
    root = character(),
    mountpoint = character(),
    fstype = character(),
    superopts = character()
  )
  if (is.null(lines)) {
    return(empty)
  }
  rows <- lapply(strsplit(lines, " ", fixed = TRUE), function(p) {
    sep <- match("-", p)
    if (is.na(sep) || sep < 7 || length(p) < sep + 2) {
      return(NULL)
    }
    c(
      unescape_mount(p[4]),
      unescape_mount(p[5]),
      p[sep + 1],
      if (length(p) >= sep + 3) p[sep + 3] else ""
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) {
    return(empty)
  }
  m <- matrix(unlist(rows), ncol = 4, byrow = TRUE)
  data.frame(root = m[, 1], mountpoint = m[, 2], fstype = m[, 3], superopts = m[, 4])
}

unescape_mount <- function(x) {
  x <- gsub("\\040", " ", x, fixed = TRUE)
  x <- gsub("\\011", "\t", x, fixed = TRUE)
  x <- gsub("\\012", "\n", x, fixed = TRUE)
  gsub("\\134", "\\", x, fixed = TRUE)
}

# /proc/self/cgroup lines "id:controllers:path" -> list of entries.
parse_proc_cgroup <- function(lines) {
  m <- regmatches(lines, regexec("^([0-9]+):([^:]*):(.*)$", lines))
  m <- m[lengths(m) == 4]
  lapply(m, function(x) {
    list(
      id = x[2],
      controllers = if (nzchar(x[3])) strsplit(x[3], ",", fixed = TRUE)[[1]] else character(),
      path = x[4]
    )
  })
}

mountinfo <- function(ctx) {
  ctx$shared("mountinfo", \(ctx) parse_mountinfo(ctx$read("/proc/self/mountinfo")))
}

cgroup_layout <- function(ctx) ctx$shared("cgroup_layout", read_cgroup_layout)

# The cgroup version and, per controller, the directory holding this
# process's cgroup files plus the mount point it sits under.
read_cgroup_layout <- function(ctx) {
  lines <- ctx$read("/proc/self/cgroup")
  mounts <- mountinfo(ctx)
  if (is.null(lines) || !nrow(mounts)) {
    return(NULL)
  }
  entries <- parse_proc_cgroup(lines)
  v1_mounts <- mounts[mounts$fstype == "cgroup", , drop = FALSE]
  v2_mounts <- mounts[mounts$fstype == "cgroup2", , drop = FALSE]

  v1 <- list()
  for (ctrl in cgroup_controllers) {
    has <- vapply(strsplit(v1_mounts$superopts, ",", fixed = TRUE), \(o) ctrl %in% o, logical(1))
    entry <- Find(\(e) ctrl %in% e$controllers, entries)
    if (any(has) && !is.null(entry)) {
      mount <- v1_mounts[which(has)[1], ]
      v1[[ctrl]] <- cgroup_location(ctx, mount$mountpoint, mount$root, entry$path)
    }
  }

  v2 <- NULL
  entry <- Find(\(e) e$id == "0" && !length(e$controllers), entries)
  if (nrow(v2_mounts) && !is.null(entry)) {
    mount <- v2_mounts[1, ]
    v2 <- cgroup_location(ctx, mount$mountpoint, mount$root, entry$path)
  }

  version <- if (length(v1) && !is.null(v2)) {
    "hybrid"
  } else if (length(v1)) {
    "1"
  } else if (!is.null(v2)) {
    "2"
  } else {
    NA_character_
  }
  list(version = version, v1 = v1, v2 = v2)
}

# Where a cgroup's files are: the mount point plus the cgroup path relative to
# the mount's root. When that directory is not visible (e.g. a host path seen
# from inside a container), fall back to the mount point itself.
cgroup_location <- function(ctx, mountpoint, root, path) {
  rel <- path
  if (root != "/") {
    rel <- if (startsWith(path, root)) substring(path, nchar(root) + 1) else ""
  }
  rel <- sub("/+$", "", rel)
  dir <- paste0(sub("/+$", "", mountpoint), rel)
  if (!nzchar(dir) || !ctx$exists(dir)) {
    dir <- mountpoint
  }
  list(dir = dir, mount = mountpoint, path = path)
}

# The location to read `controller` files from: its v1 hierarchy if it has
# one, else the unified v2 hierarchy.
cgroup_controller <- function(layout, controller) {
  if (is.null(layout)) {
    return(NULL)
  }
  loc <- layout$v1[[controller]]
  if (!is.null(loc)) {
    return(c(loc, version = 1L))
  }
  if (!is.null(layout$v2)) {
    return(c(layout$v2, version = 2L))
  }
  NULL
}

# A directory and its ancestors up to (and including) the mount point.
cgroup_ancestors <- function(loc) {
  dir <- loc$dir
  mount <- sub("/+$", "", loc$mount)
  out <- dir
  while (nchar(dir) > nchar(mount) && startsWith(dir, mount)) {
    dir <- dirname(dir)
    out <- c(out, dir)
  }
  out
}

cgroup_line <- function(ctx, dir, file) {
  lines <- ctx$read(paste0(dir, "/", file), n = 1L)
  if (length(lines)) lines[1] else NULL
}

# Minimum of a limit over the cgroup and its ancestors: parent limits apply.
cgroup_walk_min <- function(ctx, loc, file, parse = parse_limit) {
  values <- numeric()
  for (dir in cgroup_ancestors(loc)) {
    line <- cgroup_line(ctx, dir, file)
    if (!is.null(line)) {
      values <- c(values, parse(line))
    }
  }
  values <- values[!is.na(values)]
  if (length(values)) min(values) else NULL
}

# "key value" lines of memory.stat / cpu.stat -> named numeric.
cgroup_stat <- function(ctx, dir, file) {
  lines <- ctx$read(paste0(dir, "/", file))
  if (is.null(lines)) {
    return(NULL)
  }
  parts <- strsplit(lines, " ", fixed = TRUE)
  parts <- parts[lengths(parts) == 2]
  values <- suppressWarnings(as.numeric(vapply(parts, `[`, character(1), 2)))
  names(values) <- vapply(parts, `[`, character(1), 1)
  values
}

# cgroup v1 reports "no limit" as a huge page-rounded number.
v1_limit <- function(x) {
  x <- parse_limit(x)
  if (!is.na(x) && x >= 2^62) Inf else x
}

# Resolvers ------------------------------------------------------------

register_cgroup_facts <- function() {
  linux <- list(os = "linux")

  register(resolver("cgroup.version", confine = linux, function(ctx) {
    layout <- cgroup_layout(ctx)
    if (is.null(layout) || is.na(layout$version)) NULL else layout$version
  }))

  register(resolver("cgroup.path", confine = linux, function(ctx) {
    layout <- cgroup_layout(ctx)
    loc <- layout$v2 %||% layout$v1$memory %||% layout$v1[[1]]
    loc$path
  }))

  register(resolver("cgroup.mountpoint", confine = linux, function(ctx) {
    layout <- cgroup_layout(ctx)
    if (is.null(layout) || is.na(layout$version)) {
      return(NULL)
    }
    if (identical(layout$version, "2")) {
      return(layout$v2$mount)
    }
    dirname((layout$v1$memory %||% layout$v1[[1]])$mount)
  }))

  register(resolver("cgroup.namespaced", confine = linux, function(ctx) {
    layout <- cgroup_layout(ctx)
    if (is.null(layout) || is.na(layout$version)) {
      return(NULL)
    }
    paths <- if (!is.null(layout$v2)) layout$v2$path else vapply(layout$v1, `[[`, "", "path")
    all(paths == "/")
  }))

  register(resolver("cgroup.pids.max", confine = linux, function(ctx) {
    loc <- cgroup_controller(cgroup_layout(ctx), "pids")
    if (is.null(loc)) NULL else cgroup_walk_min(ctx, loc, "pids.max")
  }))
}
