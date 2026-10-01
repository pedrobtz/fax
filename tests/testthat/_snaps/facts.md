# errors become status = 'error' unless strict

    Code
      facts_df(facts(strict = TRUE))
    Condition
      Error:
      ! Failed to resolve fact `toy.a`: boom

# errors in nested facts are reported once in strict mode

    Code
      fact("toy.outer", strict = TRUE)
    Condition
      Error:
      ! Failed to resolve fact `toy.inner`: boom

# a fax object gives namespaces, groups and facts

    Code
      f$nope
    Condition
      Error:
      ! Unknown namespace or fact `nope`.

# facts() with namespaces resolves eagerly

    Code
      f
    Output
      <fax facts>
      root: / | os: linux | cloud: FALSE
      namespaces: cpu
      resolved: cpu

# user errors are informative

    Code
      fact("nope")
    Condition
      Error:
      ! Unknown fact `nope`.

---

    Code
      fact("cpu.host")
    Condition
      Error:
      ! `cpu.host` is a group of facts; use `facts()[["cpu.host"]]`.

---

    Code
      facts("nope")
    Condition
      Error:
      ! Unknown namespace `nope`. Available: cpu.

---

    Code
      facts_df(list())
    Condition
      Error:
      ! `x` must be a fax object created by `facts()`.

