test_that("parse_range_list() expands CPU lists", {
  expect_equal(parse_range_list("0-3,8"), c(0L, 1L, 2L, 3L, 8L))
  expect_equal(parse_range_list("5"), 5L)
  expect_equal(parse_range_list(" 2-3 , 0 "), c(0L, 2L, 3L))
  expect_equal(parse_range_list(""), integer())
  expect_null(parse_range_list("3-1"))
  expect_null(parse_range_list("a-b"))
  expect_null(parse_range_list("1-2-3"))
})

test_that("parse_limit() maps max to Inf", {
  expect_equal(parse_limit("max"), Inf)
  expect_equal(parse_limit("536870912\n"), 536870912)
  expect_equal(parse_limit(""), NA_real_)
  expect_equal(parse_limit(NA_character_), NA_real_)
  expect_equal(parse_limit("garbage"), NA_real_)
})

test_that("parse_kv() splits at the first separator", {
  lines <- c("MemTotal:  16 kB", "no separator", "url: http://x:1", NA)
  expect_equal(
    parse_kv(lines),
    c(MemTotal = "16 kB", url = "http://x:1")
  )
  expect_equal(parse_kv(c("A=1", "B="), sep = "="), c(A = "1", B = ""))
})

test_that("parse_size() converts /proc sizes to bytes", {
  expect_equal(parse_size("16 kB"), 16384)
  expect_equal(parse_size("100"), 100)
  expect_equal(parse_size("2 GB"), 2 * 1024^3)
  expect_equal(parse_size("1 parsec"), NA_real_)
  expect_equal(parse_size("kB"), NA_real_)
})
