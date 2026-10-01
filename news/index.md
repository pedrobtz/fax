# Changelog

## fax (development version)

- Initial CRAN submission.
- [`effective_cores()`](https://pedrobtz.github.io/fax/reference/effective_cores.md)
  and
  [`effective_memory()`](https://pedrobtz.github.io/fax/reference/effective_cores.md)
  return the CPU cores and memory the process can actually use, taking
  cgroup v1/v2 limits, cpusets and CPU affinity into account.
- [`facts()`](https://pedrobtz.github.io/fax/reference/facts.md),
  [`fact()`](https://pedrobtz.github.io/fax/reference/fact.md) and
  [`facts_df()`](https://pedrobtz.github.io/fax/reference/facts_df.md)
  provide a lazy, cached snapshot of facts with per-fact status and
  source. Resolver errors never escape unless `strict = TRUE`.
- Facts describe the OS (`os.*`), CPU, memory and cgroups, and where the
  process runs: bare metal or VM (`virtualization.*`, including WSL),
  container (`container.*`), Kubernetes pod (`k8s.*`, including the
  Downward API) and cloud provider (`cloud.provider`).
- [`facts_json()`](https://pedrobtz.github.io/fax/reference/facts_json.md)
  writes facts as JSON, optionally with their status and source;
  [`print()`](https://rdrr.io/r/base/print.html) on a
  [`facts()`](https://pedrobtz.github.io/fax/reference/facts.md)
  snapshot shows a short summary of where the process runs and what it
  can use.
- Runtime facts describe R (version, BLAS/LAPACK, library paths,
  repositories with credentials removed, renv, thread settings), the
  process (pid, user, uid, privileges) and Python (interpreter, version,
  venv/uv/conda/system, site-packages) without starting Python inside R.
- `env.vars` reports environment variables with secrets redacted by
  default (`fax.redact`, `fax.redact_allowlist`); `env.proxies` and
  `disk.tmpdir.*` describe proxies and the temporary directory.
- [`usage()`](https://pedrobtz.github.io/fax/reference/usage.md) and
  [`usage_line()`](https://pedrobtz.github.io/fax/reference/usage.md)
  report current process and container CPU and memory use cheaply enough
  to call on every log line.
