test_that("fax_root() prefers the option, then FAX_ROOT, then /", {
  withr::local_options(fax.root = NULL)
  withr::local_envvar(FAX_ROOT = NA)
  expect_equal(fax_root(), "/")
  withr::local_envvar(FAX_ROOT = "/host")
  expect_equal(fax_root(), "/host")
  withr::local_options(fax.root = "/fixture")
  expect_equal(fax_root(), "/fixture")
})

test_that("root_path() joins root and absolute path", {
  expect_equal(root_path("/proc/self/status", "/"), "/proc/self/status")
  expect_equal(root_path("/proc/self/status", "/host/"), "/host/proc/self/status")
  expect_equal(root_path("proc/x", "/host"), "/host/proc/x")
})

test_that("readers read below the root and return NULL when missing", {
  local_root(list("proc/loadavg" = "0.5 0.4 0.3 1/100 42", "etc/a/b" = "x"))
  expect_equal(read_lines("/proc/loadavg"), "0.5 0.4 0.3 1/100 42")
  expect_null(read_lines("/proc/missing"))
  expect_null(read_lines("/etc"))
  expect_true(file_exists("/proc/loadavg"))
  expect_false(file_exists("/proc/missing"))
  expect_equal(list_dir("/etc"), "a")
  expect_null(list_dir("/nope"))
})
