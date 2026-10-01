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
#>     "model": "AMD EPYC 7763 64-Core Processor",
#>     "vendor": "AMD",
#>     "flags": ["fpu", "vme", "de", "pse", "tsc", "msr", "pae", "mce", "cx8", "apic", "sep", "mtrr", "pge", "mca", "cmov", "pat", "pse36", "clflush", "mmx", "fxsr", "sse", "sse2", "ht", "syscall", "nx", "mmxext", "fxsr_opt", "pdpe1gb", "rdtscp", "lm", "constant_tsc", "rep_good", "nopl", "tsc_reliable", "nonstop_tsc", "cpuid", "extd_apicid", "aperfmperf", "tsc_known_freq", "pni", "pclmulqdq", "ssse3", "fma", "cx16", "pcid", "sse4_1", "sse4_2", "movbe", "popcnt", "aes", "xsave", "avx", "f16c", "rdrand", "hypervisor", "lahf_lm", "cmp_legacy", "svm", "cr8_legacy", "abm", "sse4a", "misalignsse", "3dnowprefetch", "osvw", "topoext", "vmmcall", "fsgsbase", "bmi1", "avx2", "smep", "bmi2", "erms", "invpcid", "rdseed", "adx", "smap", "clflushopt", "clwb", "sha_ni", "xsaveopt", "xsavec", "xgetbv1", "xsaves", "user_shstk", "clzero", "xsaveerptr", "rdpru", "arat", "npt", "nrip_save", "tsc_scale", "vmcb_clean", "flushbyasid", "decodeassists", "pausefilter", "pfthreshold", "v_vmsave_vmload", "umip", "vaes", "vpclmulqdq", "rdpid", "fsrm"],
#>     "isa_level": "x86-64-v3",
#>     "host": {
#>       "logical": 4,
#>       "physical": 2,
#>       "sockets": 1
#>     },
#>     "affinity": 4,
#>     "load": {
#>       "1min": 0.9,
#>       "5min": 0.29,
#>       "15min": 0.1
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
