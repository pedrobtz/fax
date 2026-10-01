test_that("facts_json() writes nested values with Inf as a string", {
  skip_if_not_installed("jsonlite")
  local_fixture("docker-v2-unlimited")
  json <- facts_json(namespaces = c("cpu", "memory", "os"))
  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  expect_equal(parsed$memory$cgroup$limit, "Inf")
  expect_equal(parsed$memory$host$total, 6202609664)
  expect_equal(parsed$cpu$effective, 4)
  expect_equal(names(parsed$cpu$load), c("1min", "5min", "15min"))
  expect_equal(parsed$os$boot_time, "2026-09-28T05:11:09Z")
  expect_null(parsed$memory$cgroup$high_missing)
})

test_that("facts_json() can include metadata", {
  skip_if_not_installed("jsonlite")
  local_fixture("k8s-v2-limits")
  parsed <- jsonlite::fromJSON(
    facts_json(namespaces = "memory", metadata = TRUE),
    simplifyVector = FALSE
  )
  limit <- parsed[["memory.cgroup.limit"]]
  expect_equal(limit$value, 1073741824)
  expect_equal(limit$status, "ok")
  expect_match(limit$source, "kubepods")
  expect_null(parsed[["memory.lxcfs"]]$message)
})

test_that("json_value() converts R values", {
  expect_equal(json_value(c(a = 1, b = Inf)), list(a = 1, b = "Inf"))
  expect_equal(json_value(-Inf), "-Inf")
  expect_equal(json_value(c(x = "1")), list(x = "1"))
  expect_equal(json_value(as.POSIXct(0, tz = "UTC")), "1970-01-01T00:00:00Z")
  expect_equal(json_value(1:3), 1:3)
})

test_that("facts_json() explains a missing jsonlite", {
  local_mocked_bindings(requireNamespace = function(...) FALSE, .package = "base")
  expect_snapshot(facts_json(), error = TRUE)
})
