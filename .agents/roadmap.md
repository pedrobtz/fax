# fax — roadmap to 0.1.0 (first CRAN release)

Companion to [fax-design.md](fax-design.md), which is the source of truth for fact names, formulas and decisions. Section references (§) point there.

Status: **final** — 2026-10-01 · Progress: Stages 0–1 done

---

## 0.1.0 in one paragraph

A pure-R, zero-dependency package that answers *"where am I running?"*, *"what can I actually use?"* and *"what is installed?"* on Linux bare metal, VMs, Docker/Podman containers, Kubernetes pods and Azure, with host-level facts on macOS and Windows. It ships the resolver engine; the `os`, `cpu`, `memory`, `cgroup`, `virtualization`, `container`, `k8s`, `cloud`, `runtime` (R and Python), `env` and `disk.tmpdir` facts; package inventories (system, R, Python); Azure detection offline and via IMDS (opt-in); `effective_cores()` / `effective_memory()`; and list / data frame / JSON / printed output.

## Scope

| In 0.1.0 | Deferred |
|---|---|
| Engine: resolvers, registry, root-aware readers, `run_cmd()`, `http_get()`, mocks, session cache, opt-in namespaces, `fax.skip` (§4) | Public `register_resolver()`, external facts `facts.d` / `FAX_FACT_*` (0.2.0) |
| Linux `os`, `cpu` (incl. `isa_level`), `memory` (incl. working set, rlimits), `cgroup` v1/v2/hybrid, effective values (§5.1–5.4, §6) | AWS and GCP IMDS, Azure scheduled events (0.2.0) |
| `virtualization`, `container` (incl. `pid1`), `k8s` (env + Downward API), WSL (§5.5–5.7) | `facts_duckdb()`, CLI, exported `capture_fixture()` (0.2.0) |
| `cloud`: provider guess from DMI; Azure platform detection offline; Azure IMDS with `cloud = TRUE` (§5.8) | `disk.mounts`, `network.interfaces`, tmpdir inodes (0.2.0) |
| `runtime`: R, Python, uid/privileged; `env` with redaction; `disk.tmpdir` (§5.9–5.11) | `dmi.*`, FIPS/SELinux (0.2.0) |
| `packages`: system, R, Python inventories (§5.12) | Cross-session fact cache with TTL (later) |
| macOS & Windows: `os`, `cpu.host.*`, `memory.host.*`, `runtime`, `env`, `packages` | Process facts, Windows containers, Rust core (later / maybe never) |
| `facts()`, `fact()`, `facts_df()`, `facts_json()`, `print()`, `effective_cores()`, `effective_memory()` (§7) | Sensors, users/sessions, other languages (non-goals, §2) |
| `usage()` / `usage_line()`: fast CPU/memory usage probe for logging, ≤ 200 µs on Linux (§4.6) | |

---

## Stage 0 — Housekeeping

**Goal:** a clean, correctly described empty package. Design decisions are already recorded in §12.

- [x] Add `^\.agents$` to `.Rbuildignore` (otherwise it ends up in the tarball and `R CMD check` notes it).
- [x] Fill in `DESCRIPTION`: Title, Description, `Authors@R` (**todo:** real name, ORCID if available), `BugReports`, `URL` with the GitHub repo, `Depends: R (>= 4.1.0)`, Suggests per §10.
- [x] `README.Rmd` stub with the motivation from §1.
- [x] Check the name `fax` on CRAN, the CRAN archive and r-universe (§12 #1): free as of 2026-10-01.
- [x] Add a `lintr` config (no CI lint job yet).

**Done when:** `R CMD check` is clean on the empty package in CI.

---

## Stage 1 — Engine

**Goal:** the machinery every fact uses (§4), exercised with toy resolvers.

Files (suggested): `R/resolver.R`, `R/registry.R`, `R/context.R`, `R/read.R`, `R/cmd.R`, `R/http.R`, `R/cache.R`, `R/facts.R`, `R/df.R`, `R/types.R`.

- [x] `resolver()` constructor and validation: `name`, `confine`, `weight`, `depends`, `network`, `resolve` (§4.1). Internal in 0.1.0.
- [x] Registry: built-ins registered at load time; highest-weight resolver whose `confine` predicates pass wins; `not_applicable` when none pass.
- [x] Confine predicates on `os` and on other facts' values, evaluated lazily.
- [x] Namespaces: default vs opt-in (`packages`); `network = TRUE` resolvers run only with `cloud = TRUE` / `fax.cloud`; `fax.skip` blocklist (§4.2). Each case sets `status` and `message`.
- [x] Context `ctx`: `root`, `read()`, `cmd()`, `http()`, `fact()` (dependency resolution, cycle detection).
- [x] Readers `read_file()`, `read_lines()`, `read_kv()`, `list_dir()`, `file_exists()` with root prefix; `NULL` on missing/unreadable; path recorded as `source` (§4.3).
- [x] `run_cmd()`: `Sys.which()` check, `system2(timeout = )`, stdout/stderr capture, `fax.cmd_mock` hook.
- [x] `http_get()` skeleton: URL allowlist, `fax.http_mock` hook (real transport comes in Stage 6).
- [x] Fact record with `value`, `status`, `source`, `resolver`, `elapsed`, `message`; error containment; `strict`.
- [x] Session cache keyed by fact + root; `refresh = TRUE`; invalidated when `fax.root` changes.
- [x] `facts()` lazy `fax` object (§4.5) with `$`, `[[`, `names()`, `as.list()`; `fact()`; `facts_df()` with list-column for vector and `df` values.
- [x] Type helpers: bytes, cores, range lists (`0-3,8`), `"max"` → `Inf`, kB/MiB parsing.

Tests: toy resolvers covering weight selection, confinement, opt-in namespaces, network gating, `fax.skip`, dependencies, cycles, error → status, strict, cache/refresh, root switching, command and HTTP mocks.

**Done when:** a toy resolver set produces a correct `facts_df()` against a fixture root, and errors never escape `facts()` unless strict.

---

## Stage 2 — Linux CPU, memory and cgroups

**Goal:** host vs effective CPU and memory, correct under cgroup v1, v2 and hybrid (§5.2–5.4, §6).

- [ ] `cgroup.*` from `/proc/self/cgroup` and `/proc/self/mountinfo`, v1/v2/hybrid.
- [ ] v2 readers: `cpu.max`, `cpuset.cpus.effective`, `memory.max`, `memory.high`, `memory.current`, `memory.swap.max`, `memory.stat`; walk up the visible hierarchy taking the minimum.
- [ ] v1 readers: CFS quota/period, `cpuset.cpus`, `hierarchical_memory_limit` (fallback `memory.limit_in_bytes`, ≈2^63 → `Inf`), `memory.usage_in_bytes`, `total_inactive_file`, soft limit.
- [ ] `cpu.host.*`, `cpu.model`, `cpu.vendor`, `cpu.flags`, `cpu.isa_level` (x86-64 v1–v4; arm64 features), `cpu.affinity`, `cpu.load`.
- [ ] `cpu.cgroup.quota/cpuset/weight`; `cpu.effective` and `cpu.effective_exact` (§6).
- [ ] `memory.host.*`, `memory.swap.*`, `memory.cgroup.*` incl. `working_set`; `memory.rlimit.as/data` from `/proc/self/limits`; `memory.lxcfs`.
- [ ] `memory.effective.limit` and `memory.effective.available` (working-set based, §6).
- [ ] `effective_cores()` (integer ≥ 1; falls back to `parallel::detectCores()`, then 1) and `effective_memory(what = c("limit", "available"))` (`Inf` → host total).

Fast usage probe (§4.6), built on the same parsers but outside the engine:
- [ ] Static setup cached in a package environment: cgroup dir and available usage files, page size (`/proc/self/auxv` `AT_PAGESZ` via `readBin`, fallback `getconf PAGESIZE` once, fallback 4096), `cpu.effective_exact`, `memory.effective.limit`. Recomputed when the pid or `fax.root` changes.
- [ ] Per-call reads: `proc.time()`, `/proc/self/statm`, cgroup `memory.current` / `memory.usage_in_bytes`, cgroup `cpu.stat` / `cpuacct.usage`. Optional `extra = c("host", "working_set")`.
- [ ] Rates from the previous sample (process CPU, cgroup CPU, throttling); reset after fork; `max_age` reuse.
- [ ] `usage()` returns a named double vector of class `fax_usage`; `format()` / `print()` / `usage_line()`.
- [ ] Micro-optimize the readers used here: benchmark `readLines(n = 1)`, `readChar()` and `readBin()` on `/proc` files and use the fastest; `strsplit(fixed = TRUE)`, no regex; never `gc()`.
- [ ] Never errors: every field falls back to `NA`.

Fixtures (`tests/testthat/fixtures/<scenario>/`, minimal files only): `linux-baremetal`, `docker-v1-cpus1.5-mem512m`, `docker-v2-unlimited`, `docker-v2-cpus2-mem1g`, `k8s-v2-limits` (limit on a parent cgroup), `cpuset-pinned`, `lxcfs`, `hybrid`. Include a `memory.stat` with a large `inactive_file` to test the working set. Build them with an internal capture helper (or `data-raw/capture_fixture.sh`) that copies only the files resolvers read.

Tests: per-fixture expectations on effective values; `expect_snapshot()` of `facts_df()` per scenario; malformed/empty/missing files → `unavailable`, never `error`. For `usage()`: rates computed from two fixture states (swap fixture files between calls), first-call behaviour, pid-change reset, `max_age`, `NA` on missing files, `usage_line()` snapshot.

**Done when:** every fixture gives the right `effective_cores()` / `effective_memory()`; on the CI Ubuntu runner both return sane values (≥ 1, ≤ host); and `usage()` has a median ≤ 200 µs there.

---

## Stage 3 — Linux OS and substrate detection

**Goal:** answer *"where am I running?"* on Linux (§5.1, §5.5–5.7, offline part of §5.8).

- [ ] `os.*` from `Sys.info()` and os-release; boot time and uptime; timezone, locale.
- [ ] `virtualization.type/hypervisor` from DMI, cpuinfo `hypervisor` flag, `/sys/hypervisor/type`; `virtualization.wsl`.
- [ ] `container.detected/runtime/id/pid1` from the §5.6 signals; document which signal wins.
- [ ] `k8s.*`: detection, namespace (never the token), Downward API env mapping with defaults (`fax.k8s.env`), labels/annotations volume (`fax.k8s.podinfo`), limits derived from cgroup when not mapped.
- [ ] `cloud.provider` from DMI (Azure asset tag / Microsoft + waagent, Amazon EC2, Google Compute Engine).

Fixtures (add): `azure-vm`, `aws-ec2`, `gcp-vm`, `wsl2`, `podman-rootless`, `aks-pod-downward-api`.

Tests: per-fixture classification; "no false positives" on bare metal (physical, no container, no k8s, no cloud).

**Done when:** each fixture is classified correctly and the GitHub Ubuntu runner reports `vm` / `azure`.

---

## Stage 4 — Runtime (R and Python), environment, outputs

**Goal:** language-runtime facts, safe environment reporting, every output format (§5.9–5.11, §7).

R and process:
- [ ] `runtime.r.*` (version, platform, home, BLAS/LAPACK, libpaths, repos with credentials stripped, renv detection), `runtime.threads.*`, `runtime.parallelly_cores`, `runtime.pid/user`.
- [ ] `runtime.uid/gid/privileged`: Linux `/proc/self/status`; macOS `id`; Windows `whoami /groups` lazily, `NA` if too slow.

Python, without starting Python in the R session:
- [ ] Interpreter discovery order per §5.9; the winning source recorded as `source`.
- [ ] `pyvenv.cfg` and `conda-meta/python-*.json` first; otherwise one probe command printing JSON (`sys.version_info`, `sys.implementation.name`, `sys.prefix`, `sys.base_prefix`, `site.getsitepackages()`, `site.getusersitepackages()`), 5 s timeout.
- [ ] `runtime.python.reticulate` only if reticulate is loaded and already initialized; never call `py_config()` or anything that initializes Python.

Environment:
- [ ] `env.vars` with the §5.10 pattern and modes; URL userinfo stripping; `env.proxies`.
- [ ] Redaction test table: `AZURE_STORAGE_CONNECTION_STRING`, `AZURE_CLIENT_SECRET`, `IDENTITY_HEADER`, `MSI_SECRET`, `GITHUB_PAT`, `AWS_SECRET_ACCESS_KEY`, `DATABASE_URL` with password, `*_SAS`; and must-not-redact: `PATH`, `R_HOME`, `PWD`.
- [ ] `disk.tmpdir`: path, fs type, free space.

Outputs:
- [ ] `print.fax()`: substrate line (bare metal / VM / container / pod, cloud, Azure platform), host-vs-effective table for CPU and memory, R and Python versions; human-readable bytes; no `cli` dependency; package counts only if already resolved.
- [ ] `facts_json()` via jsonlite (clear error if missing); `Inf` → `"Inf"`; `metadata = FALSE` default.
- [ ] `format()` / `str()` that don't force resolution.

Fixtures (add): venv tree with `pyvenv.cfg`, conda prefix with `conda-meta/`, recorded Python probe output.

Tests: `print()` snapshots per fixture; JSON round-trip (`Inf`, `NA`, named vectors, lists, `df`); redaction table; reticulate never initialized (skip if not installed).

**Done when:** `print(facts())` on the `k8s-v2-limits` fixture shows pod limits next to node values on one screen, and `runtime.python.*` is right for the venv, conda and system fixtures.

---

## Stage 5 — Package inventories

**Goal:** answer *"what is installed?"* (§5.12). Opt-in namespace; one `df` fact per source.

- [ ] `packages.system.installed`, one resolver per manager, highest applicable weight wins: dpkg (installed entries only), apk, pacman, rpm (`rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\t%{ARCH}\n'`), Homebrew (`HOMEBREW_PREFIX` or standard prefixes; `Cellar/` and `Caskroom/` listing), Windows (`readRegistry()` on HKLM, HKLM WOW6432Node and HKCU `Uninstall` keys, behind a mockable wrapper). Plus `packages.system.manager` and `packages.system.count`.
- [ ] `packages.r` from `installed.packages(fields = c("Repository", "RemoteType", "RemoteSha"))`.
- [ ] `packages.python` from dist-info/egg-info directory names (read `METADATA` only when the name can't be parsed), `INSTALLER`, conda `conda-meta/*.json`.

Fixtures (add): `dpkg-status`, `apk-installed`, `pacman-local`, recorded `rpm -qa`, Homebrew Cellar tree, mocked registry listing, site-packages tree.

Tests: parser per manager; malformed entries skipped; `packages` never resolved by `print(facts())` / `as.list(facts())`.

**Done when:** on each CI OS `facts("packages")` returns non-empty system and R inventories, and the Python inventory matches `pip list` in a CI venv.

---

## Stage 6 — Azure

**Goal:** know which Azure service the process runs on, and fetch instance metadata when allowed (§5.8).

- [ ] **Spike first:** confirm base R `url(method = "libcurl", headers = c(Metadata = "true"))` can reach IMDS with a reliable 1 s timeout and proxy bypass (temporarily set `no_proxy` for `169.254.169.254`). If not, use `curl` from Suggests and report `unavailable` without it. Record the outcome in §12.
- [ ] Offline: `cloud.azure.platform` and `cloud.azure.service.*` from platform env vars; verify each variable name against current Azure docs.
- [ ] `http_get()` transport: allowlist, 1 s timeout, no retries, no redirects.
- [ ] IMDS resolver: one `GET /metadata/instance?api-version=<pinned>`; map fields per §5.8; tags redacted; pinned API version recorded in `source`.
- [ ] Blocked IMDS (network policy, App Service, Container Apps) → `unavailable` with the reason. `print()` notes "node VM" when `k8s.detected`.

Fixtures (add): env-var sets per PaaS platform; recorded IMDS JSON with IDs and IPs replaced.

Tests: platform detection per env set; IMDS parsing; timeout and connection-refused give `unavailable` within ~1 s; HTTP mock never called without `cloud = TRUE`; requests outside the allowlist (e.g. `/metadata/identity/oauth2/token`) refused.

**Done when:** on a real Azure VM and an AKS pod, `facts(cloud = TRUE)` returns region, size, resource group and platform in under 1.5 s; off Azure, `cloud = TRUE` makes no request because the offline guess rules Azure out.

---

## Stage 7 — macOS and Windows

**Goal:** pass `R CMD check` on every CRAN platform with useful host-level facts.

macOS:
- [ ] `sw_vers`; one batched `sysctl` call (`machdep.cpu.brand_string`, `hw.logicalcpu`, `hw.physicalcpu`, `hw.memsize`, `kern.boottime`, `vm.loadavg`, `kern.hv_vmm_present`); `vm_stat` for available memory; `id` for uid.

Windows:
- [ ] `os.*` from `Sys.info()` / `osVersion`; `NUMBER_OF_PROCESSORS`, `PROCESSOR_IDENTIFIER`.
- [ ] `memory.host.*` from `ps::ps_system_memory()` when installed, else one lazy PowerShell `Get-CimInstance` call with timeout; `unavailable` on failure.
- [ ] Python discovery adds the `py` launcher and `%LOCALAPPDATA%\Programs\Python`; site-packages under `Lib\site-packages`.

Both:
- [ ] Linux-only facts report `not_applicable`, never `error`.
- [ ] `usage()`: process CPU from `proc.time()`; `mem_rss` from `ps::ps_memory_info()` when installed, else `NA`; container fields `NA`. No commands per call.

Tests: recorded command outputs in `tests/testthat/fixtures/cmd/`, run on all OSes; live tests assert invariants only.

**Done when:** the CI matrix (macOS, Windows, Ubuntu release/devel/oldrel) is green and every command parser has mocked tests.

---

## Stage 8 — Hardening

**Goal:** prove fixtures match reality; fast and safe.

- [ ] Docker job (cgroup v2): `--cpus=1.5 --memory=512m` → `effective_cores() == 2`, `effective_memory() == 512 MiB`; `--cpuset-cpus=0` variant; run in Debian, Alpine and Fedora images (dpkg, apk, rpm inventories).
- [ ] `kind` job: pod with limits, Downward API env and volume; assert `k8s.*` and effective values.
- [ ] Python job: venv and conda; `packages.python` vs `pip list --format=json`.
- [ ] Azure: IMDS check on the Azure-hosted GitHub runner if reachable; otherwise a manual script for a real VM / AKS pod, results noted in the release PR.
- [ ] Cross-check `cpu.effective` with `parallelly::availableCores(methods = c("system", "cgroups.cpuset", "cgroups2.cpu.max", "nproc"))` in container jobs.
- [ ] Benchmark: default Linux snapshot < 50 ms (`skip_on_cran()` test + bench script); packages timed separately.
- [ ] Benchmark `usage()`: median ≤ 200 µs on Linux (≤ 20 µs via `max_age`), tracked in CI so regressions show up; check memory allocation per call with `bench::mark()`. In the Docker job, verify `cpu_cgroup` and `cpu_throttled` respond to a busy loop under `--cpus=1`.
- [ ] Robustness: garbage/truncated files for every parser; permission denied; empty root (all `unavailable` / `not_applicable`, none `error`).
- [ ] Security review against §9.
- [ ] covr: every resolver exercised by at least one fixture.

**Done when:** live jobs are green and agree with the corresponding fixtures.

---

## Stage 9 — Documentation and site

**Goal:** a reader understands what fax reports and why it differs from `detectCores()`.

- [ ] roxygen docs and fast, network-free examples for every export (IMDS examples in `\dontrun{}`, noting they need Azure).
- [ ] Fact reference page generated from the registry: name, type, platforms, sources, default/opt-in, `Inf` / `NA` meaning.
- [ ] Vignette `fax`: motivation, host vs effective, containers/k8s walkthrough (output pre-rendered from fixtures), options reference.
- [ ] Vignette `azure`: offline detection per service, what IMDS adds, the AKS "node, not pod" caveat, what is never read.
- [ ] Article `logging`: `usage_line()` with logger, lgr and `message()`; what each field means; `cpu_throttled` as the signal that a container is CPU-starved; cost per call.
- [ ] Article `inventory`: system / R / Python packages, e.g. attaching an environment report to a bug report or job log.
- [ ] `README.Rmd`: pitch, install, `print(facts())`, `effective_cores()` with `future` / `data.table`.
- [ ] pkgdown reference grouped by topic; `NEWS.md` for 0.1.0; lifecycle note (fact names frozen per §3; changes need NEWS + deprecation).

**Done when:** pkgdown builds cleanly and every export has an example.

---

## Stage 10 — CRAN release

**Goal:** 0.1.0 accepted on CRAN.

- [ ] Run the `cran-extrachecks` skill and fix everything it flags.
- [ ] `urlchecker::url_check()`, `spelling::spell_check_package()`.
- [ ] `R CMD check --as-cran` clean locally; `devtools::check_win_devel()`, `check_win_release()`, `check_mac_release()`; `rhub::rhub_check()` on linux, macos-arm64, windows.
- [ ] Confirm CRAN-safety (§10): no network, no Python, fixture-only scenario assertions, inventory tests on fixtures only.
- [ ] `cran-comments.md`: new release; test environments; network access only on explicit `cloud = TRUE`, 1 s timeout, never in checks.
- [ ] `Version: 0.1.0`, final `NEWS.md`; `devtools::submit_cran()`; confirm maintainer email.
- [ ] After acceptance: tag `v0.1.0`, GitHub release, bump to `0.1.0.9000`, open the 0.2.0 milestone from the deferred column.

**Done when:** fax 0.1.0 is on CRAN.

---

## Stage dependencies

```
0 ─► 1 ─► 2 ─┬─► 3 ─► 4 ─┬─► 5 ─┬─► 8 ─► 9 ─► 10
             │           └─► 6 ─┤
             └─► 7 ─────────────┘
```

- Stage 7 (macOS/Windows) can start once the engine (1) and the CPU/memory fact shapes (2) exist.
- Stages 5 and 6 are independent of each other: 5 needs `runtime.python.*` from 4, 6 needs `k8s.*` from 3 and redaction from 4.
