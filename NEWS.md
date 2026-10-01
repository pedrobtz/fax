# fax (development version)

* Initial CRAN submission.
* `effective_cores()` and `effective_memory()` return the CPU cores and memory
  the process can actually use, taking cgroup v1/v2 limits, cpusets and CPU
  affinity into account.
* `facts()`, `fact()` and `facts_df()` provide a lazy, cached snapshot of
  facts with per-fact status and source. Resolver errors never escape unless
  `strict = TRUE`.
* Facts describe the OS (`os.*`), CPU, memory and cgroups, and where the
  process runs: bare metal or VM (`virtualization.*`, including WSL),
  container (`container.*`), Kubernetes pod (`k8s.*`, including the Downward
  API) and cloud provider (`cloud.provider`).
* `usage()` and `usage_line()` report current process and container CPU and
  memory use cheaply enough to call on every log line.
