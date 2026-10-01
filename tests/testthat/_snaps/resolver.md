# resolver() validates its inputs

    Code
      resolver("CPU", function(ctx) 1)
    Condition
      Error:
      ! `name` must be a dotted lower-case fact name, not CPU.

---

    Code
      resolver("cpu", function(ctx) 1)
    Condition
      Error:
      ! `name` must be a dotted lower-case fact name, not cpu.

---

    Code
      resolver("cpu.x", 1)
    Condition
      Error:
      ! `resolve` must be a function.

---

    Code
      resolver("cpu.x", function(ctx) 1, confine = list("linux"))
    Condition
      Error:
      ! `confine` must be a named list.

---

    Code
      resolver("cpu.x", function(ctx) 1, weight = "high")
    Condition
      Error:
      ! `weight` must be a single number.

# register() rejects a fact that is also a group

    Code
      register(resolver("toy.a", function(ctx) 1))
    Condition
      Error:
      ! Fact `toy.a` clashes with `toy.a.b`: a fact cannot also be a group of facts.

---

    Code
      register(resolver("toy.a.b.c", function(ctx) 1))
    Condition
      Error:
      ! Fact `toy.a.b.c` clashes with `toy.a.b`: a fact cannot also be a group of facts.

