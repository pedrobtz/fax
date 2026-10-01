meminfo <- function(ctx) ctx$shared("meminfo", \(ctx) ctx$read_kv("/proc/meminfo"))

meminfo_bytes <- function(ctx, key) {
  info <- meminfo(ctx)
  if (is.null(info) || !key %in% names(info)) {
    return(NULL)
  }
  value <- parse_size(info[[key]])
  if (is.na(value)) NULL else value
}

# Soft limit of a "Max ..." row in /proc/self/limits; "unlimited" -> Inf.
rlimit <- function(ctx, label) {
  lines <- ctx$read("/proc/self/limits")
  if (is.null(lines)) {
    return(NULL)
  }
  line <- lines[startsWith(lines, label)]
  if (!length(line)) {
    return(NULL)
  }
  soft <- strsplit(trimws(substring(line[1], nchar(label) + 1)), "[[:space:]]+")[[1]][1]
  if (identical(soft, "unlimited")) Inf else parse_limit(soft)
}

memory_location <- function(ctx) cgroup_controller(cgroup_layout(ctx), "memory")

register_memory_facts <- function() {
  linux <- list(os = "linux")

  register(resolver("memory.host.total", confine = linux, \(ctx) meminfo_bytes(ctx, "MemTotal")))

  register(resolver("memory.host.available", confine = linux, cache = FALSE, function(ctx) {
    available <- meminfo_bytes(ctx, "MemAvailable")
    if (!is.null(available)) {
      return(available)
    }
    # Kernels before 3.14 have no MemAvailable; approximate it.
    parts <- c(
      meminfo_bytes(ctx, "MemFree"),
      meminfo_bytes(ctx, "Buffers"),
      meminfo_bytes(ctx, "Cached")
    )
    if (length(parts) == 3) sum(parts) else NULL
  }))

  register(resolver("memory.swap.total", confine = linux, \(ctx) meminfo_bytes(ctx, "SwapTotal")))

  register(resolver(
    "memory.swap.free",
    confine = linux,
    cache = FALSE,
    \(ctx) meminfo_bytes(ctx, "SwapFree")
  ))

  register(resolver("memory.cgroup.limit", confine = linux, function(ctx) {
    loc <- memory_location(ctx)
    if (is.null(loc)) {
      return(NULL)
    }
    if (loc$version == 2L) {
      return(cgroup_walk_min(ctx, loc, "memory.max"))
    }
    # v1 computes the minimum over all ancestors itself, including ones that
    # are not visible inside a container.
    stat <- cgroup_stat(ctx, loc$dir, "memory.stat")
    if (!is.null(stat) && !is.na(stat["hierarchical_memory_limit"])) {
      return(v1_limit(stat[["hierarchical_memory_limit"]]))
    }
    cgroup_walk_min(ctx, loc, "memory.limit_in_bytes", v1_limit)
  }))

  register(resolver("memory.cgroup.high", confine = linux, function(ctx) {
    loc <- memory_location(ctx)
    if (is.null(loc)) {
      return(NULL)
    }
    if (loc$version == 1L) {
      not_applicable("cgroup v1 has no memory.high.")
    }
    cgroup_walk_min(ctx, loc, "memory.high")
  }))

  register(resolver("memory.cgroup.usage", confine = linux, cache = FALSE, function(ctx) {
    loc <- memory_location(ctx)
    if (is.null(loc)) {
      return(NULL)
    }
    file <- if (loc$version == 2L) "memory.current" else "memory.usage_in_bytes"
    line <- cgroup_line(ctx, loc$dir, file)
    if (is.null(line)) NULL else parse_limit(line)
  }))

  register(resolver("memory.cgroup.swap_limit", confine = linux, function(ctx) {
    loc <- memory_location(ctx)
    if (is.null(loc)) {
      return(NULL)
    }
    if (loc$version == 2L) {
      return(cgroup_walk_min(ctx, loc, "memory.swap.max"))
    }
    # v1 limits memory + swap together.
    memsw <- cgroup_line(ctx, loc$dir, "memory.memsw.limit_in_bytes")
    limit <- ctx$fact("memory.cgroup.limit")
    if (is.null(memsw) || is.na(limit)) {
      return(NULL)
    }
    memsw <- v1_limit(memsw)
    if (is.infinite(memsw)) Inf else max(0, memsw - limit)
  }))

  register(resolver("memory.cgroup.working_set", confine = linux, cache = FALSE, function(ctx) {
    loc <- memory_location(ctx)
    usage <- ctx$fact("memory.cgroup.usage")
    if (is.null(loc) || is.na(usage)) {
      return(NULL)
    }
    stat <- cgroup_stat(ctx, loc$dir, "memory.stat")
    key <- if (loc$version == 2L) "inactive_file" else "total_inactive_file"
    inactive <- if (is.null(stat)) NA else stat[key]
    if (is.na(inactive)) NULL else max(0, usage - inactive[[1]])
  }))

  register(resolver("memory.cgroup.pressure", confine = linux, cache = FALSE, function(ctx) {
    cgroup_pressure(ctx, "memory", "memory.pressure")
  }))

  # OOM kills in this cgroup since it was created: v2 memory.events, v1
  # memory.oom_control (kernel 4.13+).
  register(resolver("memory.cgroup.oom_kills", confine = linux, cache = FALSE, function(ctx) {
    loc <- memory_location(ctx)
    if (is.null(loc)) {
      return(NULL)
    }
    file <- if (loc$version == 2L) "memory.events" else "memory.oom_control"
    stat <- cgroup_stat(ctx, loc$dir, file)
    if (is.null(stat) || is.na(stat["oom_kill"])) NULL else stat[["oom_kill"]]
  }))

  register(resolver("memory.rlimit.as", confine = linux, \(ctx) rlimit(ctx, "Max address space")))

  register(resolver("memory.rlimit.data", confine = linux, \(ctx) rlimit(ctx, "Max data size")))

  register(resolver("memory.effective.limit", function(ctx) {
    limits <- c(ctx$fact("memory.host.total"), ctx$fact("memory.cgroup.limit"))
    if (all(is.na(limits))) NULL else min(limits, na.rm = TRUE)
  }))

  register(resolver("memory.effective.available", cache = FALSE, function(ctx) {
    limit <- ctx$fact("memory.cgroup.limit")
    used <- ctx$fact("memory.cgroup.working_set") %|NA|% ctx$fact("memory.cgroup.usage")
    values <- c(ctx$fact("memory.host.available"), max(0, limit - used))
    if (all(is.na(values))) NULL else min(values, na.rm = TRUE)
  }))

  register(resolver("memory.lxcfs", confine = linux, function(ctx) {
    mounts <- mountinfo(ctx)
    if (!nrow(mounts)) {
      return(NULL)
    }
    any(mounts$fstype == "fuse.lxcfs" & mounts$mountpoint == "/proc/meminfo")
  }))
}
