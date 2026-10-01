# Facts with their status and source

Returns one row per fact, with the metadata recorded while resolving it.

## Usage

``` r
facts_df(x = facts(), namespaces = NULL)
```

## Arguments

- x:

  A `fax` object from
  [`facts()`](https://pedrobtz.github.io/fax/reference/facts.md).

- namespaces:

  Namespaces to include. With `NULL`, all default namespaces plus any
  opt-in namespace already resolved in `x`.

## Value

A data frame with columns:

- `fact`: the fact name.

- `value`: a list-column of values (`NA` when not available).

- `status`: `"ok"`, `"not_applicable"`, `"unavailable"` or `"error"`.

- `source`: the files, commands, environment variables or URLs used.

- `resolver`: the id of the resolver that produced the value.

- `elapsed`: resolution time in seconds.

- `message`: why the status is not `"ok"`.

## Examples

``` r
facts_df(facts())
#>                          fact
#> 1                   os.family
#> 2                     os.name
#> 3                       os.id
#> 4                  os.id_like
#> 5             os.release.full
#> 6            os.release.major
#> 7            os.release.minor
#> 8           os.kernel.release
#> 9           os.kernel.version
#> 10                os.hostname
#> 11                    os.arch
#> 12               os.boot_time
#> 13                  os.uptime
#> 14                os.timezone
#> 15                  os.locale
#> 16                  cpu.model
#> 17                 cpu.vendor
#> 18                  cpu.flags
#> 19              cpu.isa_level
#> 20           cpu.host.logical
#> 21          cpu.host.physical
#> 22           cpu.host.sockets
#> 23               cpu.affinity
#> 24                   cpu.load
#> 25           cpu.cgroup.quota
#> 26          cpu.cgroup.cpuset
#> 27          cpu.cgroup.weight
#> 28              cpu.effective
#> 29        cpu.effective_exact
#> 30          memory.host.total
#> 31      memory.host.available
#> 32          memory.swap.total
#> 33           memory.swap.free
#> 34        memory.cgroup.limit
#> 35         memory.cgroup.high
#> 36        memory.cgroup.usage
#> 37   memory.cgroup.swap_limit
#> 38  memory.cgroup.working_set
#> 39           memory.rlimit.as
#> 40         memory.rlimit.data
#> 41     memory.effective.limit
#> 42 memory.effective.available
#> 43               memory.lxcfs
#> 44             cgroup.version
#> 45                cgroup.path
#> 46          cgroup.mountpoint
#> 47          cgroup.namespaced
#> 48            cgroup.pids.max
#> 49  virtualization.hypervisor
#> 50        virtualization.type
#> 51         virtualization.wsl
#> 52             container.pid1
#> 53         container.detected
#> 54          container.runtime
#> 55               container.id
#> 56               k8s.detected
#> 57              k8s.namespace
#> 58               k8s.pod.name
#> 59              k8s.node.name
#> 60                 k8s.pod.ip
#> 61                k8s.pod.uid
#> 62             k8s.pod.labels
#> 63        k8s.pod.annotations
#> 64       k8s.resources.limits
#> 65     k8s.resources.requests
#> 66             cloud.provider
#>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               value
#> 1                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             linux
#> 2                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            Ubuntu
#> 3                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            ubuntu
#> 4                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            debian
#> 5                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             24.04
#> 6                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                24
#> 7                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                04
#> 8                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 6.17.0-1022-azure
#> 9                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       #22-Ubuntu SMP Mon Jul 27 17:24:03 UTC 2026
#> 10                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    runnervm8df0l
#> 11                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           x86_64
#> 12                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              2026-10-01 06:03:25
#> 13                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           118.48
#> 14                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              UTC
#> 15                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          C.UTF-8
#> 16                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  AMD EPYC 7763 64-Core Processor
#> 17                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              AMD
#> 18 fpu, vme, de, pse, tsc, msr, pae, mce, cx8, apic, sep, mtrr, pge, mca, cmov, pat, pse36, clflush, mmx, fxsr, sse, sse2, ht, syscall, nx, mmxext, fxsr_opt, pdpe1gb, rdtscp, lm, constant_tsc, rep_good, nopl, tsc_reliable, nonstop_tsc, cpuid, extd_apicid, aperfmperf, tsc_known_freq, pni, pclmulqdq, ssse3, fma, cx16, pcid, sse4_1, sse4_2, movbe, popcnt, aes, xsave, avx, f16c, rdrand, hypervisor, lahf_lm, cmp_legacy, svm, cr8_legacy, abm, sse4a, misalignsse, 3dnowprefetch, osvw, topoext, vmmcall, fsgsbase, bmi1, avx2, smep, bmi2, erms, invpcid, rdseed, adx, smap, clflushopt, clwb, sha_ni, xsaveopt, xsavec, xgetbv1, xsaves, user_shstk, clzero, xsaveerptr, rdpru, arat, npt, nrip_save, tsc_scale, vmcb_clean, flushbyasid, decodeassists, pausefilter, pfthreshold, v_vmsave_vmload, umip, vaes, vpclmulqdq, rdpid, fsrm
#> 19                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        x86-64-v3
#> 20                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                4
#> 21                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                2
#> 22                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                1
#> 23                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                4
#> 24                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 1.25, 0.64, 0.25
#> 25                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              Inf
#> 26                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                4
#> 27                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              100
#> 28                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                4
#> 29                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                4
#> 30                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      16766410752
#> 31                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      15373881344
#> 32                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       3221221376
#> 33                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       3221221376
#> 34                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              Inf
#> 35                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              Inf
#> 36                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       2729963520
#> 37                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              Inf
#> 38                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        541396992
#> 39                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              Inf
#> 40                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              Inf
#> 41                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      16766410752
#> 42                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      15373881344
#> 43                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            FALSE
#> 44                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                2
#> 45                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       /system.slice/hosted-compute-agent.service
#> 46                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   /sys/fs/cgroup
#> 47                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            FALSE
#> 48                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            19151
#> 49                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           hyperv
#> 50                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               vm
#> 51                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               NA
#> 52                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          systemd
#> 53                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            FALSE
#> 54                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               NA
#> 55                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               NA
#> 56                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            FALSE
#> 57                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               NA
#> 58                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               NA
#> 59                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               NA
#> 60                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               NA
#> 61                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               NA
#> 62                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               NA
#> 63                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               NA
#> 64                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               NA
#> 65                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               NA
#> 66                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            azure
#>            status
#> 1              ok
#> 2              ok
#> 3              ok
#> 4              ok
#> 5              ok
#> 6              ok
#> 7              ok
#> 8              ok
#> 9              ok
#> 10             ok
#> 11             ok
#> 12             ok
#> 13             ok
#> 14             ok
#> 15             ok
#> 16             ok
#> 17             ok
#> 18             ok
#> 19             ok
#> 20             ok
#> 21             ok
#> 22             ok
#> 23             ok
#> 24             ok
#> 25             ok
#> 26             ok
#> 27             ok
#> 28             ok
#> 29             ok
#> 30             ok
#> 31             ok
#> 32             ok
#> 33             ok
#> 34             ok
#> 35             ok
#> 36             ok
#> 37             ok
#> 38             ok
#> 39             ok
#> 40             ok
#> 41             ok
#> 42             ok
#> 43             ok
#> 44             ok
#> 45             ok
#> 46             ok
#> 47             ok
#> 48             ok
#> 49             ok
#> 50             ok
#> 51 not_applicable
#> 52             ok
#> 53             ok
#> 54 not_applicable
#> 55 not_applicable
#> 56             ok
#> 57 not_applicable
#> 58 not_applicable
#> 59 not_applicable
#> 60 not_applicable
#> 61 not_applicable
#> 62 not_applicable
#> 63 not_applicable
#> 64 not_applicable
#> 65 not_applicable
#> 66             ok
#>                                                                                                                                                              source
#> 1                                                                                                                                                              <NA>
#> 2                                                                                                                                                   /etc/os-release
#> 3                                                                                                                                                   /etc/os-release
#> 4                                                                                                                                                   /etc/os-release
#> 5                                                                                                                                                   /etc/os-release
#> 6                                                                                                                                                   /etc/os-release
#> 7                                                                                                                                                   /etc/os-release
#> 8                                                                                                                                        /proc/sys/kernel/osrelease
#> 9                                                                                                                                          /proc/sys/kernel/version
#> 10                                                                                                                                        /proc/sys/kernel/hostname
#> 11                                                                                                                                                       Sys.info()
#> 12                                                                                                                                                       /proc/stat
#> 13                                                                                                                                                     /proc/uptime
#> 14                                                                                                                                                   Sys.timezone()
#> 15                                                                                                                                                  Sys.getlocale()
#> 16                                                                                                                                                    /proc/cpuinfo
#> 17                                                                                                                                                    /proc/cpuinfo
#> 18                                                                                                                                                    /proc/cpuinfo
#> 19                                                                                                                                                    /proc/cpuinfo
#> 20                                                                                                                                   /sys/devices/system/cpu/online
#> 21                                                                                                                                                    /proc/cpuinfo
#> 22                                                                                                                                                    /proc/cpuinfo
#> 23                                                                                                                                                /proc/self/status
#> 24                                                                                                                                                    /proc/loadavg
#> 25                   /proc/self/cgroup; /proc/self/mountinfo; /sys/fs/cgroup/system.slice/hosted-compute-agent.service/cpu.max; /sys/fs/cgroup/system.slice/cpu.max
#> 26                                          /proc/self/cgroup; /proc/self/mountinfo; /sys/fs/cgroup/system.slice/hosted-compute-agent.service/cpuset.cpus.effective
#> 27                                                     /proc/self/cgroup; /proc/self/mountinfo; /sys/fs/cgroup/system.slice/hosted-compute-agent.service/cpu.weight
#> 28                                                                                                                                                             <NA>
#> 29                                                                                                                                                             <NA>
#> 30                                                                                                                                                    /proc/meminfo
#> 31                                                                                                                                                    /proc/meminfo
#> 32                                                                                                                                                    /proc/meminfo
#> 33                                                                                                                                                    /proc/meminfo
#> 34             /proc/self/cgroup; /proc/self/mountinfo; /sys/fs/cgroup/system.slice/hosted-compute-agent.service/memory.max; /sys/fs/cgroup/system.slice/memory.max
#> 35           /proc/self/cgroup; /proc/self/mountinfo; /sys/fs/cgroup/system.slice/hosted-compute-agent.service/memory.high; /sys/fs/cgroup/system.slice/memory.high
#> 36                                                 /proc/self/cgroup; /proc/self/mountinfo; /sys/fs/cgroup/system.slice/hosted-compute-agent.service/memory.current
#> 37   /proc/self/cgroup; /proc/self/mountinfo; /sys/fs/cgroup/system.slice/hosted-compute-agent.service/memory.swap.max; /sys/fs/cgroup/system.slice/memory.swap.max
#> 38                                                    /proc/self/cgroup; /proc/self/mountinfo; /sys/fs/cgroup/system.slice/hosted-compute-agent.service/memory.stat
#> 39                                                                                                                                                /proc/self/limits
#> 40                                                                                                                                                /proc/self/limits
#> 41                                                                                                                                                             <NA>
#> 42                                                                                                                                                             <NA>
#> 43                                                                                                                                             /proc/self/mountinfo
#> 44                                                                                                                          /proc/self/cgroup; /proc/self/mountinfo
#> 45                                                                                                                          /proc/self/cgroup; /proc/self/mountinfo
#> 46                                                                                                                          /proc/self/cgroup; /proc/self/mountinfo
#> 47                                                                                                                          /proc/self/cgroup; /proc/self/mountinfo
#> 48                 /proc/self/cgroup; /proc/self/mountinfo; /sys/fs/cgroup/system.slice/hosted-compute-agent.service/pids.max; /sys/fs/cgroup/system.slice/pids.max
#> 49 /sys/class/dmi/id/sys_vendor; /sys/class/dmi/id/product_name; /sys/class/dmi/id/board_vendor; /sys/class/dmi/id/bios_vendor; /sys/class/dmi/id/chassis_asset_tag
#> 50                                                                                                                                                             <NA>
#> 51                                                                                                                                                             <NA>
#> 52                                                                                            /proc/self/cgroup; /proc/1/cgroup; /proc/self/mountinfo; /proc/1/comm
#> 53                                                                                            /proc/self/cgroup; /proc/1/cgroup; /proc/self/mountinfo; /proc/1/comm
#> 54                                                                                                                                                             <NA>
#> 55                                                                                                                                                             <NA>
#> 56                                                                                                                                                             <NA>
#> 57                                                                                                                                                             <NA>
#> 58                                                                                                                                                             <NA>
#> 59                                                                                                                                                             <NA>
#> 60                                                                                                                                                             <NA>
#> 61                                                                                                                                                             <NA>
#> 62                                                                                                                                                             <NA>
#> 63                                                                                                                                                             <NA>
#> 64                                                                                                                                                             <NA>
#> 65                                                                                                                                                             <NA>
#> 66 /sys/class/dmi/id/sys_vendor; /sys/class/dmi/id/product_name; /sys/class/dmi/id/board_vendor; /sys/class/dmi/id/bios_vendor; /sys/class/dmi/id/chassis_asset_tag
#>                      resolver elapsed                             message
#> 1                   os.family   0.000                                <NA>
#> 2                     os.name   0.000                                <NA>
#> 3                       os.id   0.000                                <NA>
#> 4                  os.id_like   0.000                                <NA>
#> 5             os.release.full   0.000                                <NA>
#> 6            os.release.major   0.000                                <NA>
#> 7            os.release.minor   0.000                                <NA>
#> 8           os.kernel.release   0.000                                <NA>
#> 9           os.kernel.version   0.000                                <NA>
#> 10                os.hostname   0.000                                <NA>
#> 11                    os.arch   0.000                                <NA>
#> 12               os.boot_time   0.001                                <NA>
#> 13                  os.uptime   0.000                                <NA>
#> 14                os.timezone   0.001                                <NA>
#> 15                  os.locale   0.000                                <NA>
#> 16                  cpu.model   0.001                                <NA>
#> 17                 cpu.vendor   0.000                                <NA>
#> 18                  cpu.flags   0.000                                <NA>
#> 19              cpu.isa_level   0.000                                <NA>
#> 20           cpu.host.logical   0.000                                <NA>
#> 21          cpu.host.physical   0.001                                <NA>
#> 22           cpu.host.sockets   0.000                                <NA>
#> 23               cpu.affinity   0.001                                <NA>
#> 24                   cpu.load   0.001                                <NA>
#> 25           cpu.cgroup.quota   0.001                                <NA>
#> 26          cpu.cgroup.cpuset   0.002                                <NA>
#> 27          cpu.cgroup.weight   0.001                                <NA>
#> 28              cpu.effective   0.004                                <NA>
#> 29        cpu.effective_exact   0.000                                <NA>
#> 30          memory.host.total   0.001                                <NA>
#> 31      memory.host.available   0.000                                <NA>
#> 32          memory.swap.total   0.000                                <NA>
#> 33           memory.swap.free   0.000                                <NA>
#> 34        memory.cgroup.limit   0.002                                <NA>
#> 35         memory.cgroup.high   0.001                                <NA>
#> 36        memory.cgroup.usage   0.000                                <NA>
#> 37   memory.cgroup.swap_limit   0.001                                <NA>
#> 38  memory.cgroup.working_set   0.000                                <NA>
#> 39           memory.rlimit.as   0.000                                <NA>
#> 40         memory.rlimit.data   0.001                                <NA>
#> 41     memory.effective.limit   0.003                                <NA>
#> 42 memory.effective.available   0.000                                <NA>
#> 43               memory.lxcfs   0.000                                <NA>
#> 44             cgroup.version   0.000                                <NA>
#> 45                cgroup.path   0.000                                <NA>
#> 46          cgroup.mountpoint   0.000                                <NA>
#> 47          cgroup.namespaced   0.000                                <NA>
#> 48            cgroup.pids.max   0.001                                <NA>
#> 49  virtualization.hypervisor   0.000                                <NA>
#> 50        virtualization.type   0.000                                <NA>
#> 51         virtualization.wsl   0.000              Not running under WSL.
#> 52             container.pid1   0.000                                <NA>
#> 53         container.detected   0.000                                <NA>
#> 54                       <NA>      NA No resolver applies on this system.
#> 55                       <NA>      NA No resolver applies on this system.
#> 56               k8s.detected   0.000                                <NA>
#> 57                       <NA>      NA No resolver applies on this system.
#> 58                       <NA>      NA No resolver applies on this system.
#> 59                       <NA>      NA No resolver applies on this system.
#> 60                       <NA>      NA No resolver applies on this system.
#> 61                       <NA>      NA No resolver applies on this system.
#> 62                       <NA>      NA No resolver applies on this system.
#> 63                       <NA>      NA No resolver applies on this system.
#> 64                       <NA>      NA No resolver applies on this system.
#> 65                       <NA>      NA No resolver applies on this system.
#> 66             cloud.provider   0.000                                <NA>
```
