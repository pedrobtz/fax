# Facts as JSON

Writes facts as JSON, either as nested values
(`{"cpu": {"effective": 2}}`) or, with `metadata = TRUE`, as one object
per fact with its status and source. Requires the jsonlite package.

## Usage

``` r
facts_json(x = facts(), namespaces = NULL, pretty = FALSE, metadata = FALSE)
```

## Arguments

- x:

  A `fax` object from
  [`facts()`](https://pedrobtz.github.io/fax/reference/facts.md).

- namespaces:

  Namespaces to include. With `NULL`, all default namespaces plus any
  opt-in namespace already resolved in `x`.

- pretty:

  Indent the output.

- metadata:

  Include `status`, `source`, `resolver`, `elapsed` and `message` for
  every fact.

## Value

A JSON string of class `json`.

## Details

Unlimited values (`Inf`) are written as the string `"Inf"` and unknown
values (`NA`) as `null`. Times are ISO 8601 in UTC, named vectors become
objects and data frames become arrays of objects. Vectors of length one
are written as scalars.

## See also

[`facts_df()`](https://pedrobtz.github.io/fax/reference/facts_df.md) for
the same information as a data frame.

## Examples

``` r
facts_json(namespaces = "cpu", pretty = TRUE)
#> {
#>   "cpu": {
#>     "model": "INTEL(R) XEON(R) PLATINUM 8573C",
#>     "vendor": "Intel",
#>     "flags": ["fpu", "vme", "de", "pse", "tsc", "msr", "pae", "mce", "cx8", "apic", "sep", "mtrr", "pge", "mca", "cmov", "pat", "pse36", "clflush", "mmx", "fxsr", "sse", "sse2", "ss", "ht", "syscall", "nx", "pdpe1gb", "rdtscp", "lm", "constant_tsc", "rep_good", "nopl", "xtopology", "tsc_reliable", "nonstop_tsc", "cpuid", "aperfmperf", "tsc_known_freq", "pni", "pclmulqdq", "vmx", "ssse3", "fma", "cx16", "pcid", "sse4_1", "sse4_2", "x2apic", "movbe", "popcnt", "tsc_deadline_timer", "aes", "xsave", "avx", "f16c", "rdrand", "hypervisor", "lahf_lm", "abm", "3dnowprefetch", "tpr_shadow", "ept", "vpid", "fsgsbase", "tsc_adjust", "bmi1", "hle", "avx2", "smep", "bmi2", "erms", "invpcid", "rtm", "avx512f", "avx512dq", "rdseed", "adx", "smap", "avx512ifma", "clflushopt", "clwb", "avx512cd", "sha_ni", "avx512bw", "avx512vl", "xsaveopt", "xsavec", "xgetbv1", "xsaves", "vnmi", "avx512vbmi", "umip", "avx512_vbmi2", "gfni", "vaes", "vpclmulqdq", "avx512_vnni", "avx512_bitalg", "avx512_vpopcntdq", "la57", "rdpid", "fsrm", "arch_capabilities"],
#>     "isa_level": "x86-64-v4",
#>     "host": {
#>       "logical": 4,
#>       "physical": 2,
#>       "sockets": 1
#>     },
#>     "affinity": 4,
#>     "load": {
#>       "1min": 0.78,
#>       "5min": 0.36,
#>       "15min": 0.14
#>     },
#>     "cgroup": {
#>       "quota": "Inf",
#>       "cpuset": 4,
#>       "weight": 100
#>     },
#>     "effective": 4,
#>     "effective_exact": 4
#>   }
#> } 
```
