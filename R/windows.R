# Windows facts from environment variables, the registry and (optionally) ps.

# Values of one registry key under HKEY_LOCAL_MACHINE, NULL if unreadable. One
# function so tests can replace it; readRegistry() only exists on Windows.
windows_registry <- function(key) {
  tryCatch(
    get("readRegistry", envir = asNamespace("utils"))(key, hive = "HLM"),
    error = \(e) NULL
  )
}

registry_value <- function(ctx, key, name) {
  values <- ctx$shared(paste0("registry:", key), function(ctx) {
    ctx$note(paste0("registry: HKLM\\", key))
    windows_registry(key)
  })
  value <- values[[name]]
  if (is.null(value) || !nzchar(trimws(value[1]))) NULL else trimws(as.character(value[1]))
}

cpu_key <- "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0"
bios_key <- "HARDWARE\\DESCRIPTION\\System\\BIOS"

# Windows BIOS registry values in the shape of Linux DMI fields.
windows_dmi <- function(ctx) {
  values <- c(
    sys_vendor = registry_value(ctx, bios_key, "SystemManufacturer") %||% NA_character_,
    product_name = registry_value(ctx, bios_key, "SystemProductName") %||% NA_character_,
    board_vendor = registry_value(ctx, bios_key, "BaseBoardManufacturer") %||% NA_character_,
    bios_vendor = registry_value(ctx, bios_key, "BIOSVendor") %||% NA_character_,
    chassis_asset_tag = NA_character_
  )
  if (all(is.na(values))) NULL else values
}

windows_memory <- function(ctx) {
  ctx$shared("windows_memory", function(ctx) {
    mem <- ps_call("ps_system_memory")
    if (!is.null(mem)) {
      ctx$note("ps::ps_system_memory()")
      return(c(total = mem$total, available = mem$avail))
    }
    # Without ps: one CIM query, in kB.
    query <- paste(
      "Get-CimInstance Win32_OperatingSystem |",
      "ForEach-Object { \"$($_.TotalVisibleMemorySize) $($_.FreePhysicalMemory)\" }"
    )
    out <- ctx$cmd(
      "powershell",
      c("-NoProfile", "-NonInteractive", "-Command", shQuote(query, "cmd")),
      timeout = 10
    )
    kb <- if (!is.null(out) && out$status == 0L) {
      suppressWarnings(as.numeric(strsplit(trimws(out$stdout[1]), " ")[[1]]))
    }
    if (length(kb) != 2 || anyNA(kb)) NULL else c(total = kb[1], available = kb[2]) * 1024
  })
}

register_windows_facts <- function() {
  win <- list(os = "windows")
  reg <- function(name, fun, cache = TRUE) {
    register(resolver(name, confine = win, cache = cache, id = paste0(name, "/windows"), fun))
  }

  reg("os.name", function(ctx) {
    r_note(ctx, "utils::osVersion")
    version <- utils::osVersion
    if (is.null(version)) NULL else sub(" x64.*$| x86.*$", "", version)
  })
  reg("os.id", \(ctx) "windows")
  reg("os.release.full", function(ctx) {
    build <- sub("^build ", "", Sys.info()[["version"]])
    r_note(ctx, "Sys.info()")
    if (grepl("^[0-9]+$", build)) paste0("10.0.", build) else NULL
  })
  reg("os.boot_time", function(ctx) {
    boot <- ps_call("ps_boot_time")
    if (is.null(boot)) {
      return(NULL)
    }
    ctx$note("ps::ps_boot_time()")
    as.POSIXct(as.numeric(boot), origin = "1970-01-01", tz = "UTC")
  })
  reg(
    "os.uptime",
    function(ctx) {
      boot <- ctx$fact("os.boot_time")
      if (is.na(boot)) NULL else as.numeric(Sys.time()) - as.numeric(boot)
    },
    cache = FALSE
  )

  reg("cpu.model", function(ctx) {
    registry_value(ctx, cpu_key, "ProcessorNameString") %||% ctx$env("PROCESSOR_IDENTIFIER")
  })
  reg("cpu.vendor", function(ctx) {
    vendor <- registry_value(ctx, cpu_key, "VendorIdentifier")
    if (is.null(vendor)) {
      id <- ctx$env("PROCESSOR_IDENTIFIER")
      vendor <- if (!is.null(id)) trimws(sub("^.*,", "", id))
    }
    if (is.null(vendor)) NULL else unname(x86_vendors[vendor] %|NA|% vendor)
  })
  reg("cpu.host.logical", function(ctx) {
    n <- suppressWarnings(as.numeric(ctx$env("NUMBER_OF_PROCESSORS")))
    if (length(n) && !is.na(n)) n else NULL
  })

  reg("memory.host.total", function(ctx) {
    mem <- windows_memory(ctx)
    if (is.null(mem)) NULL else mem[["total"]]
  })
  reg(
    "memory.host.available",
    function(ctx) {
      mem <- windows_memory(ctx)
      if (is.null(mem)) NULL else mem[["available"]]
    },
    cache = FALSE
  )
}
