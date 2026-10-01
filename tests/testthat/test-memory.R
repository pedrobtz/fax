test_that("rlimits are read from /proc/self/limits", {
  local_root(list(
    "proc/self/limits" = c(
      "Limit                     Soft Limit           Hard Limit           Units     ",
      "Max data size             1073741824           unlimited            bytes     ",
      "Max address space         unlimited            unlimited            bytes     "
    )
  ))
  withr::local_options(fax.os = "linux")
  expect_equal(fact("memory.rlimit.data"), 1024^3)
  expect_equal(fact("memory.rlimit.as"), Inf)
})

test_that("memory.host.available is approximated on old kernels", {
  local_root(list(
    "proc/meminfo" = c(
      "MemTotal:       1000 kB",
      "MemFree:         100 kB",
      "Buffers:          10 kB",
      "Cached:          200 kB"
    )
  ))
  withr::local_options(fax.os = "linux")
  expect_equal(fact("memory.host.available"), 310 * 1024)
})

test_that("dynamic memory facts are not cached", {
  root <- local_fixture_copy("docker-v2-cpus1.5-mem512m")
  expect_equal(fact("memory.cgroup.usage"), 1449984)
  expect_equal(fact("memory.cgroup.limit"), 536870912)
  writeLines("2000000", file.path(root, "sys/fs/cgroup/memory.current"))
  expect_equal(fact("memory.cgroup.usage"), 2e6)
  writeLines("1", file.path(root, "sys/fs/cgroup/memory.max"))
  expect_equal(fact("memory.cgroup.limit"), 536870912)
})

test_that("effective_memory() falls back to host total when unlimited", {
  local_fixture("docker-v2-unlimited")
  expect_equal(fact("memory.cgroup.limit"), Inf)
  expect_equal(effective_memory(), fact("memory.host.total"))
  expect_snapshot(effective_memory("nope"), error = TRUE)
})
