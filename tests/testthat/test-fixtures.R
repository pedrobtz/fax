expected <- data.frame(
  fixture = c(
    "linux-vm-host",
    "docker-v2-unlimited",
    "docker-v2-cpus2-mem1g",
    "docker-v2-cpus1.5-mem512m",
    "docker-v2-cgroupns-host",
    "cpuset-pinned",
    "docker-v1-cpus1.5-mem512m",
    "hybrid",
    "k8s-v2-limits",
    "lxcfs",
    "linux-baremetal",
    "azure-vm",
    "aws-ec2",
    "gcp-vm",
    "wsl2",
    "aks-pod-downward-api"
  ),
  cpu = c(4L, 4L, 2L, 2L, 1L, 1L, 2L, 4L, 2L, 4L, 4L, 4L, 4L, 4L, 4L, 2L),
  exact = c(4, 4, 2, 1.5, 1, 1, 1.5, 4, 2, 4, 4, 4, 4, 4, 4, 1.5),
  memory = c(
    6202609664,
    6202609664,
    1073741824,
    536870912,
    268435456,
    6202609664,
    536870912,
    6202609664,
    1073741824,
    536870912,
    6202609664,
    6202609664,
    6202609664,
    6202609664,
    6202609664,
    4294967296
  ),
  version = c("2", "2", "2", "2", "2", "2", "1", "hybrid", "2", "2", rep("2", 6)),
  namespaced = c(
    FALSE,
    TRUE,
    TRUE,
    TRUE,
    FALSE,
    TRUE,
    FALSE,
    FALSE,
    FALSE,
    TRUE,
    FALSE,
    FALSE,
    FALSE,
    FALSE,
    FALSE,
    TRUE
  )
)

test_that("every fixture has expectations", {
  expect_setequal(expected$fixture, fixture_names())
})

for (name in expected$fixture) {
  test_that(paste("effective values:", name), {
    local_fixture(name)
    want <- expected[expected$fixture == name, ]
    expect_identical(effective_cores(), want$cpu)
    expect_equal(fact("cpu.effective_exact"), want$exact)
    expect_equal(effective_memory(), want$memory)
    expect_equal(fact("cgroup.version"), want$version)
    expect_equal(fact("cgroup.namespaced"), want$namespaced)
  })

  test_that(paste("no fact errors:", name), {
    local_fixture(name)
    df <- facts_df(facts(refresh = TRUE))
    expect_equal(df$fact[df$status == "error"], character())
  })

  test_that(paste("report:", name), {
    expect_snapshot(cat(fixture_report(name), sep = "\n"))
  })
}

test_that("a pod limited on its parent cgroup reports the parent's limits", {
  local_fixture("k8s-v2-limits")
  expect_equal(fact("cpu.host.logical"), 8)
  expect_equal(fact("cpu.cgroup.quota"), 2)
  expect_equal(fact("memory.host.total"), 32 * 1024^3)
  expect_equal(fact("memory.cgroup.limit"), 1024^3)
  expect_equal(fact("memory.cgroup.working_set"), 200 * 1024^2)
  expect_equal(effective_memory("available"), 1024^3 - 200 * 1024^2)
  expect_equal(fact("cgroup.pids.max"), 1024)
})

test_that("cgroup v1 uses the hierarchical limit and memsw", {
  local_fixture("docker-v1-cpus1.5-mem512m")
  expect_equal(fact("memory.cgroup.working_set"), 160 * 1024^2)
  expect_equal(fact("memory.cgroup.swap_limit"), 512 * 1024^2)
  df <- facts_df(facts("memory"))
  expect_equal(df$status[df$fact == "memory.cgroup.high"], "not_applicable")
  expect_equal(fact("cpu.cgroup.weight"), 40)
})

test_that("LXCFS is detected", {
  local_fixture("lxcfs")
  expect_true(fact("memory.lxcfs"))
  local_fixture("docker-v2-unlimited")
  expect_false(fact("memory.lxcfs"))
})

test_that("Linux facts are not applicable on other systems", {
  local_fixture("docker-v2-unlimited", os = "windows")
  df <- facts_df(facts(refresh = TRUE))
  linux_only <- c("cgroup.version", "cpu.cgroup.quota", "memory.cgroup.limit", "memory.lxcfs")
  expect_equal(unique(df$status[df$fact %in% linux_only]), "not_applicable")
  expect_equal(df$status[df$fact == "cpu.host.logical"], "ok")
  expect_equal(df$resolver[df$fact == "cpu.host.logical"], "cpu.host.logical/detectCores")
  expect_gte(effective_cores(), 1L)
})

test_that("fixture tarballs match the trees in data-raw", {
  src <- test_path("..", "..", "data-raw", "fixtures")
  skip_if_not(dir.exists(src), "data-raw is not available")
  expect_setequal(list.files(src), fixture_names())
  for (name in list.files(src)) {
    tree <- file.path(src, name)
    files <- sort(list.files(tree, recursive = TRUE, all.files = TRUE))
    root <- fixture_root(name)
    expect_equal(sort(list.files(root, recursive = TRUE, all.files = TRUE)), files, info = name)
    read <- \(dir, f) readBin(file.path(dir, f), "raw", file.size(file.path(dir, f)))
    differ <- files[!vapply(files, \(f) identical(read(tree, f), read(root, f)), logical(1))]
    expect_equal(differ, character(), info = paste(name, "- run data-raw/pack-fixtures.R"))
  }
})
