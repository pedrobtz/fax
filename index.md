# fax

fax reports facts about where R is running and what it can actually use.

Inside a container,
[`parallel::detectCores()`](https://rdrr.io/r/parallel/detectCores.html)
returns the node’s 64 cores while the pod is limited to 4, and
`/proc/meminfo` shows the node’s RAM while the cgroup memory limit is 8
GiB. That leads to oversubscribed thread pools, OOM kills and misleading
diagnostics. fax answers three questions on bare metal, VMs, containers,
Kubernetes pods and Azure:

1.  **Where am I running?** OS, hardware, virtualization, container,
    Kubernetes, cloud, R and Python runtimes.
2.  **What can I actually use?** Effective CPU and memory, side by side
    with host values.
3.  **What is installed?** System, R and Python packages.

fax is under development and not yet usable.

## Installation

You can install the development version of fax from
[GitHub](https://github.com/pedrobtz/fax) with:

``` r

# install.packages("pak")
pak::pak("pedrobtz/fax")
```
