# macOS facts from one batched sysctl call, sw_vers and vm_stat.

mac_sysctl_keys <- c(
  "machdep.cpu.brand_string",
  "machdep.cpu.vendor",
  "hw.logicalcpu",
  "hw.physicalcpu",
  "hw.packages",
  "hw.memsize",
  "kern.boottime",
  "vm.loadavg",
  "kern.hv_vmm_present",
  "hw.optional.arm64",
  "machdep.cpu.features",
  "machdep.cpu.leaf7_features",
  "machdep.cpu.extfeatures"
)

# sysctl exits with status 1 when a key does not exist on this machine (e.g.
# hw.optional.arm64 on Intel) but still prints the others, so the status is
# ignored.
mac_sysctl <- function(ctx) {
  ctx$shared("sysctl", function(ctx) {
    out <- ctx$cmd("sysctl", mac_sysctl_keys)
    if (is.null(out) || !length(out$stdout)) NULL else parse_kv(out$stdout)
  })
}

sysctl_value <- function(ctx, key) {
  values <- mac_sysctl(ctx)
  if (is.null(values) || !key %in% names(values) || !nzchar(values[[key]])) NULL else values[[key]]
}

sysctl_number <- function(ctx, key) {
  value <- suppressWarnings(as.numeric(sysctl_value(ctx, key)))
  if (length(value) && !is.na(value)) value else NULL
}

mac_arm64 <- function(ctx) identical(sysctl_value(ctx, "hw.optional.arm64"), "1")

# macOS feature names -> /proc/cpuinfo names used by isa_level().
mac_flag_names <- c(
  "sse3" = "pni",
  "sse4.1" = "sse4_1",
  "sse4.2" = "sse4_2",
  "avx1.0" = "avx",
  "lahf" = "lahf_lm",
  "lzcnt" = "abm"
)

mac_flags <- function(ctx) {
  keys <- c("machdep.cpu.features", "machdep.cpu.leaf7_features", "machdep.cpu.extfeatures")
  words <- unlist(lapply(keys, \(k) strsplit(sysctl_value(ctx, k) %||% "", " ", fixed = TRUE)[[1]]))
  flags <- tolower(words[nzchar(words)])
  known <- flags %in% names(mac_flag_names)
  flags[known] <- mac_flag_names[flags[known]]
  if (length(flags)) flags else NULL
}

sw_vers <- function(ctx) {
  ctx$shared("sw_vers", function(ctx) {
    out <- ctx$cmd("sw_vers")
    if (is.null(out) || out$status != 0L) NULL else parse_kv(out$stdout)
  })
}

sw_vers_value <- function(ctx, key) {
  values <- sw_vers(ctx)
  if (is.null(values) || !key %in% names(values)) NULL else values[[key]]
}

mac_boot_time <- function(ctx) {
  text <- sysctl_value(ctx, "kern.boottime") %||% ""
  sec <- regmatches(text, regexpr("sec = [0-9]+", text))
  if (!length(sec)) {
    return(NULL)
  }
  as.POSIXct(as.numeric(sub("sec = ", "", sec)), origin = "1970-01-01", tz = "UTC")
}

register_macos_facts <- function() {
  mac <- list(os = "darwin")
  reg <- function(name, fun, cache = TRUE) {
    register(resolver(name, confine = mac, cache = cache, id = paste0(name, "/macos"), fun))
  }

  reg("os.name", \(ctx) sw_vers_value(ctx, "ProductName"))
  reg("os.id", \(ctx) "macos")
  reg("os.release.full", \(ctx) sw_vers_value(ctx, "ProductVersion"))
  reg("os.release.major", function(ctx) {
    version <- sw_vers_value(ctx, "ProductVersion")
    if (is.null(version)) NULL else strsplit(version, ".", fixed = TRUE)[[1]][1]
  })
  reg("os.release.minor", function(ctx) {
    version <- sw_vers_value(ctx, "ProductVersion")
    part <- if (!is.null(version)) strsplit(version, ".", fixed = TRUE)[[1]][2]
    if (length(part) && !is.na(part)) part else NULL
  })
  reg("os.boot_time", mac_boot_time)
  reg(
    "os.uptime",
    function(ctx) {
      boot <- mac_boot_time(ctx)
      if (is.null(boot)) NULL else as.numeric(Sys.time()) - as.numeric(boot)
    },
    cache = FALSE
  )

  reg("cpu.model", \(ctx) sysctl_value(ctx, "machdep.cpu.brand_string"))
  reg("cpu.vendor", function(ctx) {
    if (mac_arm64(ctx)) {
      return("Apple")
    }
    vendor <- sysctl_value(ctx, "machdep.cpu.vendor")
    if (is.null(vendor)) NULL else unname(x86_vendors[vendor] %|NA|% vendor)
  })
  reg("cpu.flags", mac_flags)
  reg("cpu.isa_level", function(ctx) {
    if (mac_arm64(ctx)) {
      return("arm64")
    }
    flags <- mac_flags(ctx)
    if (is.null(flags)) NULL else isa_level(flags, x86 = TRUE)
  })
  reg("cpu.host.logical", \(ctx) sysctl_number(ctx, "hw.logicalcpu"))
  reg("cpu.host.physical", \(ctx) sysctl_number(ctx, "hw.physicalcpu"))
  reg("cpu.host.sockets", \(ctx) sysctl_number(ctx, "hw.packages"))
  reg(
    "cpu.load",
    function(ctx) {
      text <- sysctl_value(ctx, "vm.loadavg")
      if (is.null(text)) {
        return(NULL)
      }
      load <- suppressWarnings(as.numeric(regmatches(text, gregexpr("[0-9.]+", text))[[1]]))
      if (length(load) < 3 || anyNA(load[1:3])) {
        return(NULL)
      }
      c(`1min` = load[1], `5min` = load[2], `15min` = load[3])
    },
    cache = FALSE
  )

  reg("memory.host.total", \(ctx) sysctl_number(ctx, "hw.memsize"))
  # Free + inactive + speculative pages: memory that can be handed out without
  # swapping. An approximation, like MemAvailable on Linux.
  reg(
    "memory.host.available",
    function(ctx) {
      out <- ctx$cmd("vm_stat")
      if (is.null(out) || out$status != 0L) {
        return(NULL)
      }
      page <- suppressWarnings(as.numeric(sub(
        ".*page size of ([0-9]+) bytes.*",
        "\\1",
        out$stdout[1]
      )))
      stats <- parse_kv(out$stdout[-1])
      pages <- suppressWarnings(as.numeric(sub(
        "\\.$",
        "",
        stats[c("Pages free", "Pages inactive", "Pages speculative")]
      )))
      if (is.na(page) || anyNA(pages)) NULL else sum(pages) * page
    },
    cache = FALSE
  )

  reg("virtualization.type", function(ctx) {
    vmm <- sysctl_value(ctx, "kern.hv_vmm_present")
    if (is.null(vmm)) {
      NULL
    } else if (vmm == "1") {
      "vm"
    } else {
      "physical"
    }
  })
  reg("virtualization.hypervisor", function(ctx) {
    if (!identical(sysctl_value(ctx, "kern.hv_vmm_present"), "1")) {
      not_applicable("No hypervisor detected.")
    }
    # On Apple silicon every macOS guest runs on Apple's Virtualization framework.
    if (mac_arm64(ctx)) "apple" else "unknown"
  })
}
