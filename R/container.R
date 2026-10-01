# Words in cgroup paths and mount sources that name a container runtime.
runtime_patterns <- c(
  "cri-containerd" = "containerd",
  "containerd" = "containerd",
  "crio" = "cri-o",
  "libpod" = "podman",
  "docker" = "docker",
  "lxc" = "lxc"
)

container_signals <- function(ctx) {
  ctx$shared("container_signals", function(ctx) {
    cgroup <- c(ctx$read("/proc/self/cgroup"), ctx$read("/proc/1/cgroup"))
    mounts <- mountinfo(ctx)
    root <- mounts[mounts$mountpoint == "/", , drop = FALSE]
    pid1 <- ctx$read("/proc/1/comm", n = 1L)
    containerenv <- ctx$read("/run/.containerenv")
    list(
      dockerenv = ctx$exists("/.dockerenv"),
      containerenv = !is.null(containerenv) || ctx$exists("/run/.containerenv"),
      containerenv_engine = parse_kv(containerenv %||% character(), sep = "=")["engine"],
      container_env = ctx$env("container"),
      kubernetes = !is.null(ctx$env("KUBERNETES_SERVICE_HOST")),
      cgroup = cgroup,
      overlay_root = any(root$fstype %in% c("overlay", "aufs", "fuse-overlayfs")),
      mount_text = paste(c(mounts$root, root$superopts), collapse = "\n"),
      pid1 = if (length(pid1)) trimws(pid1[1]) else NA_character_
    )
  })
}

cgroup_runtime <- function(text) {
  for (pattern in names(runtime_patterns)) {
    if (any(grepl(pattern, text, fixed = TRUE))) {
      return(runtime_patterns[[pattern]])
    }
  }
  NULL
}

register_container_facts <- function() {
  linux <- list(os = "linux")

  register(resolver("container.pid1", confine = linux, function(ctx) {
    pid1 <- container_signals(ctx)$pid1
    if (is.na(pid1)) NULL else pid1
  }))

  register(resolver("container.detected", confine = linux, cache = FALSE, function(ctx) {
    s <- container_signals(ctx)
    strong <- s$dockerenv ||
      s$containerenv ||
      !is.null(s$container_env) ||
      s$kubernetes ||
      !is.null(cgroup_runtime(s$cgroup))
    init <- !is.na(s$pid1) && s$pid1 %in% c("systemd", "init")
    strong || (s$overlay_root && !init)
  }))

  register(resolver(
    "container.runtime",
    confine = list(os = "linux", container.detected = TRUE),
    cache = FALSE,
    function(ctx) {
      s <- container_signals(ctx)
      engine <- gsub("\"", "", unname(s$containerenv_engine))
      if (length(engine) && !is.na(engine) && nzchar(engine)) {
        return(sub("-.*$", "", engine))
      }
      if (s$containerenv) {
        return("podman")
      }
      if (s$dockerenv) {
        return("docker")
      }
      env <- s$container_env
      if (!is.null(env) && env %in% c("podman", "docker", "lxc", "systemd-nspawn")) {
        return(env)
      }
      cgroup_runtime(s$cgroup) %||% cgroup_runtime(s$mount_text) %||% "unknown"
    }
  ))

  register(resolver(
    "container.id",
    confine = list(os = "linux", container.detected = TRUE),
    cache = FALSE,
    function(ctx) {
      s <- container_signals(ctx)
      # A 64-hex id in the cgroup path (docker, containerd, cri-o, libpod) or
      # in a runtime directory that is bind-mounted into the container.
      for (text in list(s$cgroup, s$mount_text)) {
        hit <- regmatches(
          text,
          regexpr(
            "(docker|containerd|crio|libpod|containers|overlay-containers)[-/]([0-9a-f]{64})",
            text
          )
        )
        if (length(hit)) {
          return(sub("^.*[-/]", "", hit[1]))
        }
      }
      unavailable("No container id found in cgroup paths or mounts.")
    }
  ))
}
