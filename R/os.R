# os-release KEY="value" lines -> named character vector, quotes removed.
parse_os_release <- function(lines) {
  kv <- parse_kv(lines[!startsWith(trimws(lines), "#")], sep = "=")
  value <- sub("^([\"'])(.*)\\1$", "\\2", kv)
  names(value) <- names(kv)
  value
}

os_release <- function(ctx) {
  ctx$shared("os_release", function(ctx) {
    lines <- ctx$read("/etc/os-release") %||% ctx$read("/usr/lib/os-release")
    if (is.null(lines)) NULL else parse_os_release(lines)
  })
}

os_release_value <- function(ctx, key) {
  info <- os_release(ctx)
  if (is.null(info) || !key %in% names(info) || !nzchar(info[[key]])) NULL else info[[key]]
}

os_release_part <- function(ctx, i) {
  version <- os_release_value(ctx, "VERSION_ID")
  if (is.null(version)) {
    return(NULL)
  }
  part <- strsplit(version, ".", fixed = TRUE)[[1]][i]
  if (is.na(part)) NULL else part
}

# Values from Sys.info() describe the live system, not a fixture root; the
# source says so.
sys_info <- function(ctx, field) {
  ctx$note("Sys.info()")
  value <- Sys.info()[[field]]
  if (is.null(value) || !nzchar(value)) NULL else value
}

kernel_file <- function(ctx, name) {
  line <- ctx$read(paste0("/proc/sys/kernel/", name), n = 1L)
  if (length(line) && nzchar(line)) line else NULL
}

register_os_facts <- function() {
  linux <- list(os = "linux")

  register(resolver("os.family", \(ctx) ctx$os))

  register(resolver("os.name", confine = linux, \(ctx) os_release_value(ctx, "NAME")))
  register(resolver(
    "os.name",
    weight = 10,
    id = "os.name/Sys.info",
    \(ctx) sys_info(ctx, "sysname")
  ))
  register(resolver("os.id", confine = linux, \(ctx) os_release_value(ctx, "ID")))
  register(resolver("os.id_like", confine = linux, function(ctx) {
    like <- os_release_value(ctx, "ID_LIKE")
    if (is.null(like)) NULL else strsplit(like, "[[:space:]]+")[[1]]
  }))
  register(resolver("os.release.full", confine = linux, \(ctx) os_release_value(ctx, "VERSION_ID")))
  register(resolver("os.release.major", confine = linux, \(ctx) os_release_part(ctx, 1)))
  register(resolver("os.release.minor", confine = linux, \(ctx) os_release_part(ctx, 2)))

  register(resolver("os.kernel.release", confine = linux, \(ctx) kernel_file(ctx, "osrelease")))
  register(resolver(
    "os.kernel.release",
    weight = 10,
    id = "os.kernel.release/Sys.info",
    \(ctx) sys_info(ctx, "release")
  ))
  register(resolver("os.kernel.version", confine = linux, \(ctx) kernel_file(ctx, "version")))
  register(resolver(
    "os.kernel.version",
    weight = 10,
    id = "os.kernel.version/Sys.info",
    \(ctx) sys_info(ctx, "version")
  ))
  register(resolver("os.hostname", confine = linux, \(ctx) kernel_file(ctx, "hostname")))
  register(resolver(
    "os.hostname",
    weight = 10,
    id = "os.hostname/Sys.info",
    \(ctx) sys_info(ctx, "nodename")
  ))
  register(resolver("os.arch", \(ctx) sys_info(ctx, "machine")))

  register(resolver("os.boot_time", confine = linux, function(ctx) {
    stat <- ctx$read("/proc/stat")
    line <- if (!is.null(stat)) stat[startsWith(stat, "btime ")]
    btime <- if (length(line)) suppressWarnings(as.numeric(sub("^btime ", "", line[1])))
    if (!length(btime) || is.na(btime)) {
      return(NULL)
    }
    as.POSIXct(btime, origin = "1970-01-01", tz = "UTC")
  }))

  register(resolver("os.uptime", confine = linux, cache = FALSE, function(ctx) {
    line <- ctx$read("/proc/uptime", n = 1L)
    up <- if (length(line)) suppressWarnings(as.numeric(strsplit(line, " ", fixed = TRUE)[[1]][1]))
    if (!length(up) || is.na(up)) NULL else up
  }))

  # Sys.timezone() can take half a second and warn (e.g. on Alpine, where
  # /etc/localtime is a copy, not a link), so cheaper sources come first.
  register(resolver("os.timezone", cache = FALSE, function(ctx) {
    tz <- ctx$env("TZ")
    if (!is.null(tz) && nzchar(tz)) {
      return(sub("^:", "", tz))
    }
    if (ctx$os != "windows") {
      link <- Sys.readlink(root_path("/etc/localtime", ctx$root))
      if (!is.na(link) && grepl("zoneinfo/", link, fixed = TRUE)) {
        ctx$note("/etc/localtime")
        return(sub("^.*zoneinfo/", "", link))
      }
      line <- ctx$read("/etc/timezone", n = 1L)
      if (length(line) && nzchar(trimws(line))) {
        return(trimws(line))
      }
      # Without /etc/localtime the C library uses UTC.
      if (ctx$os == "linux" && !ctx$exists("/etc/localtime")) {
        ctx$note("/etc/localtime (missing)")
        return("UTC")
      }
    }
    ctx$note("Sys.timezone()")
    tz <- suppressWarnings(Sys.timezone())
    if (is.na(tz) || !nzchar(tz)) NULL else tz
  }))

  register(resolver("os.locale", cache = FALSE, function(ctx) {
    ctx$note("Sys.getlocale()")
    locale <- Sys.getlocale("LC_CTYPE")
    if (nzchar(locale)) locale else NULL
  }))
}
