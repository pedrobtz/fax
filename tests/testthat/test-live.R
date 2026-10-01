# Checks against the machine running the tests. They assert only what holds
# everywhere, except on GitHub-hosted Linux runners, which are Azure VMs.

test_that("no fact errors on this machine", {
  skip_on_cran()
  withr::local_options(fax.root = NULL, fax.os = NULL)
  df <- facts_df(facts(refresh = TRUE))
  expect_equal(df[df$status == "error", c("fact", "message")], df[0, c("fact", "message")])
})

test_that("effective values are sane on this machine", {
  withr::local_options(fax.root = NULL, fax.os = NULL)
  n <- effective_cores()
  expect_gte(n, 1L)
  expect_lte(n, max(1L, parallel::detectCores(), na.rm = TRUE))
  m <- effective_memory()
  if (!is.na(m)) {
    expect_gt(m, 0)
  }
})

test_that("GitHub-hosted Linux runners are Azure VMs", {
  skip_on_cran()
  skip_if_not(identical(Sys.getenv("GITHUB_ACTIONS"), "true"), "not on GitHub Actions")
  skip_if_not(identical(Sys.getenv("RUNNER_ENVIRONMENT"), "github-hosted"), "not a hosted runner")
  skip_if_not(identical(Sys.info()[["sysname"]], "Linux"), "not Linux")
  withr::local_options(fax.root = NULL, fax.os = NULL)
  expect_equal(fact("virtualization.type"), "vm")
  expect_equal(fact("virtualization.hypervisor"), "hyperv")
  expect_equal(fact("cloud.provider"), "azure")
  expect_false(fact("container.detected"))
})
