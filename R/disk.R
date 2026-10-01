# The mount containing `path`: the longest mount point that is a prefix of it.
mount_for <- function(mounts, path) {
  points <- mounts$mountpoint
  hit <- points == "/" | path == points | startsWith(path, paste0(sub("/$", "", points), "/"))
  if (!any(hit)) {
    return(NULL)
  }
  mounts[hit, , drop = FALSE][which.max(nchar(points[hit])), ]
}

# Mount points from ps (macOS, Windows), shaped like parse_mountinfo().
ps_mounts <- function(ctx) {
  parts <- ps_call("ps_disk_partitions", all = TRUE)
  if (is.null(parts)) {
    return(NULL)
  }
  ctx$note("ps::ps_disk_partitions()")
  data.frame(root = "/", mountpoint = parts$mountpoint, fstype = parts$fstype, superopts = "")
}

register_disk_facts <- function() {
  register(resolver("disk.tmpdir.path", cache = FALSE, function(ctx) {
    r_note(ctx, "tempdir()")
    tempdir()
  }))

  register(resolver(
    "disk.tmpdir.fstype",
    confine = list(os = "linux"),
    cache = FALSE,
    function(ctx) {
      path <- normalizePath(tempdir(), winslash = "/", mustWork = FALSE)
      mount <- mount_for(mountinfo(ctx), path)
      if (is.null(mount)) NULL else mount$fstype
    }
  ))

  register(resolver(
    "disk.tmpdir.fstype",
    confine = list(os = \(os) os != "linux"),
    cache = FALSE,
    id = "disk.tmpdir.fstype/ps",
    function(ctx) {
      mounts <- ps_mounts(ctx)
      path <- normalizePath(tempdir(), winslash = "/", mustWork = FALSE)
      if (!is.null(mounts)) {
        mounts$mountpoint <- sub("\\\\$", "/", gsub("\\\\", "/", mounts$mountpoint))
      }
      mount <- if (!is.null(mounts)) mount_for(mounts, path)
      if (is.null(mount)) NULL else mount$fstype
    }
  ))

  register(resolver(
    "disk.tmpdir.free",
    confine = list(os = "windows"),
    cache = FALSE,
    id = "disk.tmpdir.free/ps",
    function(ctx) {
      usage <- ps_call("ps_disk_usage", tempdir())
      if (is.null(usage)) {
        return(NULL)
      }
      ctx$note("ps::ps_disk_usage()")
      as.numeric(usage$available[1])
    }
  ))

  register(resolver(
    "disk.tmpdir.free",
    confine = list(os = \(os) os != "windows"),
    cache = FALSE,
    function(ctx) {
      out <- ctx$cmd("df", c("-Pk", shQuote(tempdir())), timeout = 3)
      if (is.null(out) || out$status != 0L || length(out$stdout) < 2) {
        return(NULL)
      }
      fields <- strsplit(trimws(out$stdout[2]), "[[:space:]]+")[[1]]
      available <- suppressWarnings(as.numeric(fields[4]))
      if (is.na(available)) NULL else available * 1024
    }
  ))
}
