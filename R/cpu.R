# /proc/cpuinfo -> list of named character vectors, one per blank-line block.
cpuinfo <- function(ctx) {
  ctx$shared("cpuinfo", function(ctx) {
    lines <- ctx$read("/proc/cpuinfo")
    if (is.null(lines)) {
      return(NULL)
    }
    blank <- !nzchar(trimws(lines))
    blocks <- split(lines[!blank], cumsum(blank)[!blank])
    unname(lapply(blocks, parse_kv))
  })
}

cpuinfo_processors <- function(ctx) {
  Filter(\(b) "processor" %in% names(b), cpuinfo(ctx) %||% list())
}

# First value of `key` in any cpuinfo block.
cpuinfo_value <- function(ctx, key) {
  for (block in cpuinfo(ctx)) {
    if (key %in% names(block) && nzchar(block[[key]])) {
      return(unname(block[[key]]))
    }
  }
  NULL
}

arm_implementers <- c(
  "0x41" = "ARM",
  "0x42" = "Broadcom",
  "0x43" = "Cavium",
  "0x46" = "Fujitsu",
  "0x48" = "HiSilicon",
  "0x4e" = "NVIDIA",
  "0x50" = "Applied Micro",
  "0x51" = "Qualcomm",
  "0x53" = "Samsung",
  "0x56" = "Marvell",
  "0x61" = "Apple",
  "0x69" = "Intel",
  "0xc0" = "Ampere"
)

x86_vendors <- c(GenuineIntel = "Intel", AuthenticAMD = "AMD", HygonGenuine = "Hygon")

# Feature flags required by each x86-64 microarchitecture level, as named in
# /proc/cpuinfo (pni = SSE3, abm = LZCNT). From the x86-64 psABI.
x86_levels <- list(
  "x86-64-v2" = c("cx16", "lahf_lm", "popcnt", "pni", "sse4_1", "sse4_2", "ssse3"),
  "x86-64-v3" = c("avx", "avx2", "bmi1", "bmi2", "f16c", "fma", "abm", "movbe", "xsave"),
  "x86-64-v4" = c("avx512f", "avx512bw", "avx512cd", "avx512dq", "avx512vl")
)

isa_level <- function(flags, x86) {
  if (x86) {
    level <- "x86-64"
    for (name in names(x86_levels)) {
      if (!all(x86_levels[[name]] %in% flags)) break
      level <- name
    }
    return(level)
  }
  level <- if ("asimd" %in% flags) "arm64" else "arm"
  extensions <- intersect(c("sve", "sve2"), flags)
  paste(c(level, extensions), collapse = "+")
}

register_cpu_facts <- function() {
  linux <- list(os = "linux")

  register(resolver("cpu.model", confine = linux, function(ctx) {
    cpuinfo_value(ctx, "model name") %||% cpuinfo_value(ctx, "Model")
  }))

  register(resolver("cpu.vendor", confine = linux, function(ctx) {
    vendor <- cpuinfo_value(ctx, "vendor_id")
    if (!is.null(vendor)) {
      return(unname(x86_vendors[vendor] %|NA|% vendor))
    }
    implementer <- cpuinfo_value(ctx, "CPU implementer")
    if (is.null(implementer)) {
      return(NULL)
    }
    unname(arm_implementers[tolower(implementer)] %|NA|% implementer)
  }))

  register(resolver("cpu.flags", confine = linux, function(ctx) {
    flags <- cpuinfo_value(ctx, "flags") %||% cpuinfo_value(ctx, "Features")
    if (is.null(flags)) NULL else strsplit(trimws(flags), "[[:space:]]+")[[1]]
  }))

  register(resolver("cpu.isa_level", confine = linux, function(ctx) {
    flags <- ctx$fact("cpu.flags")
    if (anyNA(flags)) {
      return(NULL)
    }
    isa_level(flags, x86 = !is.null(cpuinfo_value(ctx, "flags")))
  }))

  register(resolver("cpu.host.logical", confine = linux, function(ctx) {
    online <- ctx$read("/sys/devices/system/cpu/online", n = 1L)
    cpus <- if (length(online)) parse_range_list(online)
    if (length(cpus)) {
      return(length(cpus))
    }
    n <- length(cpuinfo_processors(ctx))
    if (n) n else NULL
  }))

  register(resolver(
    "cpu.host.logical",
    weight = 10,
    id = "cpu.host.logical/detectCores",
    function(ctx) {
      ctx$note("parallel::detectCores()")
      n <- parallel::detectCores(logical = TRUE)
      if (is.na(n)) NULL else n
    }
  ))

  register(resolver("cpu.host.physical", confine = linux, function(ctx) {
    topo <- cpu_topology(ctx)
    if (is.null(topo)) NULL else nrow(unique(topo))
  }))

  register(resolver(
    "cpu.host.physical",
    weight = 10,
    id = "cpu.host.physical/detectCores",
    function(ctx) {
      ctx$note("parallel::detectCores(logical = FALSE)")
      n <- parallel::detectCores(logical = FALSE)
      if (is.na(n)) NULL else n
    }
  ))

  register(resolver("cpu.host.sockets", confine = linux, function(ctx) {
    topo <- cpu_topology(ctx)
    if (is.null(topo)) NULL else length(unique(topo$socket))
  }))

  register(resolver("cpu.affinity", confine = linux, function(ctx) {
    status <- ctx$read_kv("/proc/self/status")
    cpus <- if (!is.null(status)) parse_range_list(status["Cpus_allowed_list"])
    if (length(cpus)) length(cpus) else NULL
  }))

  register(resolver("cpu.load", confine = linux, cache = FALSE, function(ctx) {
    line <- ctx$read("/proc/loadavg", n = 1L)
    fields <- if (length(line)) strsplit(line, " ", fixed = TRUE)[[1]][1:3]
    load <- suppressWarnings(as.numeric(fields))
    if (length(load) != 3 || anyNA(load)) {
      return(NULL)
    }
    c(`1min` = load[1], `5min` = load[2], `15min` = load[3])
  }))

  register(resolver("cpu.cgroup.quota", confine = linux, function(ctx) {
    loc <- cgroup_controller(cgroup_layout(ctx), "cpu")
    if (is.null(loc)) {
      return(NULL)
    }
    if (loc$version == 2L) {
      return(cgroup_walk_min(ctx, loc, "cpu.max", parse_cpu_max))
    }
    quotas <- numeric()
    for (dir in cgroup_ancestors(loc)) {
      quota <- cgroup_line(ctx, dir, "cpu.cfs_quota_us")
      period <- cgroup_line(ctx, dir, "cpu.cfs_period_us")
      if (!is.null(quota) && !is.null(period)) {
        quotas <- c(quotas, cfs_cores(parse_limit(quota), parse_limit(period)))
      }
    }
    quotas <- quotas[!is.na(quotas)]
    if (length(quotas)) min(quotas) else NULL
  }))

  register(resolver("cpu.cgroup.cpuset", confine = linux, function(ctx) {
    loc <- cgroup_controller(cgroup_layout(ctx), "cpuset")
    if (is.null(loc)) {
      return(NULL)
    }
    files <- if (loc$version == 2L) {
      "cpuset.cpus.effective"
    } else {
      c("cpuset.effective_cpus", "cpuset.cpus")
    }
    # The nearest cgroup that has the file: v2 only exposes it where the
    # cpuset controller is enabled, and the effective set already reflects
    # every ancestor.
    for (dir in cgroup_ancestors(loc)) {
      for (file in files) {
        line <- cgroup_line(ctx, dir, file)
        cpus <- if (!is.null(line)) parse_range_list(line)
        if (length(cpus)) {
          return(length(cpus))
        }
      }
    }
    NULL
  }))

  register(resolver("cpu.cgroup.weight", confine = linux, function(ctx) {
    loc <- cgroup_controller(cgroup_layout(ctx), "cpu")
    if (is.null(loc)) {
      return(NULL)
    }
    if (loc$version == 2L) {
      line <- cgroup_line(ctx, loc$dir, "cpu.weight")
      return(if (is.null(line)) NULL else parse_limit(line))
    }
    shares <- cgroup_line(ctx, loc$dir, "cpu.shares")
    if (is.null(shares)) {
      return(NULL)
    }
    # The conversion used by systemd and Kubernetes from v1 shares to v2 weight.
    round(1 + ((parse_limit(shares) - 2) * 9999) / 262142)
  }))

  register(resolver("cpu.effective", function(ctx) {
    limits <- cpu_limits(ctx)
    if (is.null(limits)) {
      return(NULL)
    }
    limits["quota"] <- ceiling(limits["quota"])
    as.integer(max(1, min(limits, na.rm = TRUE)))
  }))

  register(resolver("cpu.effective_exact", function(ctx) {
    limits <- cpu_limits(ctx)
    if (is.null(limits)) NULL else min(limits, na.rm = TRUE)
  }))
}

parse_cpu_max <- function(line) {
  parts <- strsplit(trimws(line), " ", fixed = TRUE)[[1]]
  cfs_cores(parse_limit(parts[1]), parse_limit(parts[2] %|NA|% "100000"))
}

cfs_cores <- function(quota, period) {
  if (is.na(quota) || is.na(period) || period <= 0) {
    return(NA_real_)
  }
  if (is.infinite(quota) || quota < 0) Inf else quota / period
}

cpu_limits <- function(ctx) {
  limits <- c(
    host = ctx$fact("cpu.host.logical"),
    affinity = ctx$fact("cpu.affinity"),
    cpuset = ctx$fact("cpu.cgroup.cpuset"),
    quota = ctx$fact("cpu.cgroup.quota")
  )
  if (all(is.na(limits))) NULL else limits
}

# Unique (socket, core) pairs from cpuinfo, else from sysfs topology.
cpu_topology <- function(ctx) {
  procs <- cpuinfo_processors(ctx)
  has_ids <- length(procs) &&
    all(vapply(procs, \(b) all(c("physical id", "core id") %in% names(b)), logical(1)))
  if (has_ids) {
    return(data.frame(
      socket = vapply(procs, \(b) b[["physical id"]], character(1)),
      core = vapply(procs, \(b) b[["core id"]], character(1))
    ))
  }
  cpus <- grep("^cpu[0-9]+$", ctx$list_dir("/sys/devices/system/cpu"), value = TRUE)
  if (!length(cpus)) {
    return(NULL)
  }
  read_id <- function(cpu, file) {
    line <- ctx$read(sprintf("/sys/devices/system/cpu/%s/topology/%s", cpu, file), n = 1L)
    if (length(line)) line[1] else NA_character_
  }
  topo <- data.frame(
    socket = vapply(cpus, read_id, character(1), file = "physical_package_id", USE.NAMES = FALSE),
    core = vapply(cpus, read_id, character(1), file = "core_id", USE.NAMES = FALSE)
  )
  if (anyNA(topo$core)) NULL else topo
}
