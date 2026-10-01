test_that("print() summarises substrate and resources", {
  withr::local_options(fax.skip = "runtime")
  withr::local_envvar(KUBERNETES_SERVICE_HOST = NA, container = NA)
  for (name in c(
    "k8s-v2-limits",
    "aks-pod-downward-api",
    "linux-baremetal",
    "azure-vm",
    "wsl2",
    "docker-v1-cpus1.5-mem512m"
  )) {
    local_fixture(name)
    expect_snapshot(print(facts(refresh = TRUE)), variant = NULL)
  }
})

test_that("print() shows R and Python when available", {
  local_python_env()
  local_mocked_bindings(sys_which = function(name) "")
  out <- format(facts(refresh = TRUE))
  expect_match(
    out[startsWith(out, "runtime")],
    paste("R", paste(R.version$major, R.version$minor, sep = ".")),
    fixed = TRUE
  )
})
