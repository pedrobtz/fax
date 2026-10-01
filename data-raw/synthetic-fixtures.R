# Writes the fixture trees that cannot be captured on a cgroup v2 podman VM:
# cgroup v1, hybrid, a Kubernetes pod whose limits are set only on the pod
# cgroup, and an LXCFS container. Formats follow the captured fixtures and the
# kernel documentation (Documentation/admin-guide/cgroup-v{1,2}).
#
# Run from the package root: Rscript data-raw/synthetic-fixtures.R

fixtures <- "data-raw/fixtures"
base <- file.path(fixtures, "docker-v2-unlimited")

write_tree <- function(name, files) {
  root <- file.path(fixtures, name)
  for (path in names(files)) {
    full <- file.path(root, path)
    dir.create(dirname(full), recursive = TRUE, showWarnings = FALSE)
    writeLines(files[[path]], full)
  }
  message(name, ": ", length(files), " files")
}

from_base <- function(path) readLines(file.path(base, path))

# /proc/cpuinfo for `logical` CPUs, two hyperthreads per core, one socket.
cpuinfo <- function(logical) {
  block <- from_base("proc/cpuinfo")
  block <- block[seq_len(which(block == "")[1])]
  unlist(lapply(seq_len(logical) - 1, function(i) {
    out <- sub("^(processor\t+: ).*", paste0("\\1", i), block)
    out <- sub("^(core id\t+: ).*", paste0("\\1", i %/% 2), out)
    out <- sub("^(siblings\t+: ).*", paste0("\\1", logical), out)
    out <- sub("^(cpu cores\t+: ).*", paste0("\\1", logical / 2), out)
    sub("^((initial )?apicid\t+: ).*", paste0("\\1", i), out)
  }))
}

meminfo <- function(total_kb, available_kb) {
  out <- from_base("proc/meminfo")
  out <- sub("^MemTotal:.*", sprintf("MemTotal:       %d kB", total_kb), out)
  sub("^MemAvailable:.*", sprintf("MemAvailable:   %d kB", available_kb), out)
}

status <- function(cpus) {
  sub("^Cpus_allowed_list:.*", paste0("Cpus_allowed_list:\t", cpus), from_base("proc/self/status"))
}

common <- function(cpus = "0-3", logical = 4, total_kb = 6057236, available_kb = 5472796) {
  list(
    "etc/os-release" = c('NAME="Ubuntu"', 'VERSION_ID="22.04"', "ID=ubuntu", "ID_LIKE=debian"),
    "proc/sys/kernel/osrelease" = "5.15.0-122-generic",
    "proc/sys/kernel/version" = "#132-Ubuntu SMP Thu Aug 29 13:45:52 UTC 2024",
    "proc/sys/kernel/hostname" = "fixture",
    "proc/1/comm" = "sh",
    "proc/stat" = "btime 1790000000",
    "proc/uptime" = "3600.25 12000.50",
    "proc/cpuinfo" = cpuinfo(logical),
    "proc/meminfo" = meminfo(total_kb, available_kb),
    "proc/self/status" = status(cpus),
    "proc/self/limits" = from_base("proc/self/limits"),
    "proc/self/statm" = from_base("proc/self/statm"),
    "proc/loadavg" = "1.50 0.75 0.25 3/250 4242",
    "sys/devices/system/cpu/online" = cpus,
    "sys/devices/system/cpu/possible" = cpus
  )
}

unlimited_v1 <- "9223372036854771712"

# Docker on cgroup v1 without a cgroup namespace: each controller hierarchy has
# the container's cgroup bind-mounted at /sys/fs/cgroup/<controller>.
local({
  id <- "/docker/3f1b2c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b"
  mount <- function(n, ctrl, opts) {
    sprintf(
      "%d 25 0:%d %s /sys/fs/cgroup/%s ro,nosuid,nodev,noexec,relatime master:%d - cgroup cgroup rw,%s",
      n, n, id, ctrl, n, opts
    )
  }
  write_tree("docker-v1-cpus1.5-mem512m", modifyList(common(), list(
    "proc/self/cgroup" = c(
      paste0("12:pids:", id),
      paste0("11:memory:", id),
      paste0("10:cpu,cpuacct:", id),
      paste0("9:cpuset:", id),
      paste0("1:name=systemd:", id)
    ),
    "proc/self/mountinfo" = c(
      "20 1 0:50 / / rw,relatime - overlay overlay rw,lowerdir=/var/lib/docker/overlay2/l/A,upperdir=/var/lib/docker/overlay2/x/diff,workdir=/var/lib/docker/overlay2/x/work",
      "25 20 0:52 / /sys/fs/cgroup ro,nosuid,nodev,noexec,relatime - tmpfs tmpfs rw,mode=755",
      mount(30, "memory", "memory"),
      mount(31, "cpu,cpuacct", "cpu,cpuacct"),
      mount(32, "cpuset", "cpuset"),
      mount(33, "pids", "pids"),
      sprintf("34 25 0:34 %s /sys/fs/cgroup/systemd ro,nosuid,nodev,noexec,relatime master:5 - cgroup cgroup rw,xattr,name=systemd", id)
    ),
    "sys/fs/cgroup/memory/memory.limit_in_bytes" = "536870912",
    "sys/fs/cgroup/memory/memory.soft_limit_in_bytes" = unlimited_v1,
    "sys/fs/cgroup/memory/memory.memsw.limit_in_bytes" = "1073741824",
    "sys/fs/cgroup/memory/memory.usage_in_bytes" = "209715200",
    "sys/fs/cgroup/memory/memory.stat" = c(
      "cache 52428800",
      "rss 150994944",
      "inactive_file 41943040",
      "hierarchical_memory_limit 536870912",
      "hierarchical_memsw_limit 1073741824",
      "total_cache 52428800",
      "total_rss 150994944",
      "total_inactive_file 41943040"
    ),
    "sys/fs/cgroup/cpu,cpuacct/cpu.cfs_quota_us" = "150000",
    "sys/fs/cgroup/cpu,cpuacct/cpu.cfs_period_us" = "100000",
    "sys/fs/cgroup/cpu,cpuacct/cpu.shares" = "1024",
    "sys/fs/cgroup/cpu,cpuacct/cpu.stat" = c(
      "nr_periods 500",
      "nr_throttled 20",
      "throttled_time 123456789"
    ),
    "sys/fs/cgroup/cpu,cpuacct/cpuacct.usage" = "5000000000",
    "sys/fs/cgroup/cpuset/cpuset.cpus" = "0-3",
    "sys/fs/cgroup/cpuset/cpuset.effective_cpus" = "0-3",
    "sys/fs/cgroup/pids/pids.max" = "max"
  )))
})

# A systemd host in hybrid mode: v1 controllers plus an empty v2 hierarchy at
# /sys/fs/cgroup/unified. No limits.
local({
  path <- "/user.slice/user-1000.slice/session-2.scope"
  mount <- function(n, ctrl, opts) {
    sprintf(
      "%d 25 0:%d / /sys/fs/cgroup/%s rw,nosuid,nodev,noexec,relatime shared:%d - cgroup cgroup rw,%s",
      n, n, ctrl, n, opts
    )
  }
  dir <- function(ctrl, file) paste0("sys/fs/cgroup/", ctrl, path, "/", file)
  files <- modifyList(common(), list(
    "proc/1/comm" = "systemd",
    "proc/self/cgroup" = c(
      paste0("11:memory:", path),
      paste0("10:cpu,cpuacct:", path),
      paste0("9:cpuset:/"),
      paste0("8:pids:", path),
      paste0("1:name=systemd:", path),
      paste0("0::", path)
    ),
    "proc/self/mountinfo" = c(
      "21 1 8:1 / / rw,relatime shared:1 - ext4 /dev/sda1 rw",
      "25 18 0:22 / /sys/fs/cgroup ro,nosuid,nodev,noexec shared:9 - tmpfs tmpfs ro,mode=755",
      "26 25 0:23 / /sys/fs/cgroup/unified rw,nosuid,nodev,noexec,relatime shared:10 - cgroup2 cgroup2 rw,nsdelegate",
      mount(30, "memory", "memory"),
      mount(31, "cpu,cpuacct", "cpu,cpuacct"),
      mount(32, "cpuset", "cpuset"),
      mount(33, "pids", "pids")
    )
  ))
  files[[dir("memory", "memory.limit_in_bytes")]] <- unlimited_v1
  files[[dir("memory", "memory.usage_in_bytes")]] <- "1073741824"
  files[[dir("memory", "memory.stat")]] <- c(
    "hierarchical_memory_limit 9223372036854771712",
    "total_inactive_file 268435456"
  )
  files[[dir("cpu,cpuacct", "cpu.cfs_quota_us")]] <- "-1"
  files[[dir("cpu,cpuacct", "cpu.cfs_period_us")]] <- "100000"
  files[[dir("cpu,cpuacct", "cpu.shares")]] <- "1024"
  files[[dir("pids", "pids.max")]] <- "max"
  files[["sys/fs/cgroup/cpuset/cpuset.cpus"]] <- "0-3"
  files[[paste0("sys/fs/cgroup/unified", path, "/cgroup.controllers")]] <- ""
  write_tree("hybrid", files)
})

# Kubernetes pod on cgroup v2 without a cgroup namespace. The limits are set on
# the pod cgroup only; the container cgroup itself is unlimited. 8 CPUs and
# 32 GiB on the node.
local({
  pod <- "/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-pod7c1f.slice"
  ctr <- paste0(pod, "/cri-containerd-9a8b7c.scope")
  cg <- function(path, file) paste0("sys/fs/cgroup", path, "/", file)
  files <- modifyList(common("0-7", 8, 32 * 1024^2, 20 * 1024^2), list(
    "proc/self/cgroup" = paste0("0::", ctr),
    "proc/self/mountinfo" = c(
      "700 650 0:200 / / rw,relatime - overlay overlay rw,lowerdir=/var/lib/containerd/a,upperdir=/var/lib/containerd/b,workdir=/var/lib/containerd/c",
      "705 700 0:26 / /sys/fs/cgroup ro,nosuid,nodev,noexec,relatime - cgroup2 cgroup2 rw,nsdelegate,memory_recursiveprot"
    )
  ))
  files[[cg("", "cgroup.controllers")]] <- "cpuset cpu io memory pids"
  files[[cg("/kubepods.slice", "memory.max")]] <- "33285996544"
  files[[cg("/kubepods.slice", "cpu.max")]] <- "max 100000"
  files[[cg("/kubepods.slice/kubepods-burstable.slice", "memory.max")]] <- "max"
  files[[cg("/kubepods.slice/kubepods-burstable.slice", "cpu.max")]] <- "max 100000"
  files[[cg(pod, "memory.max")]] <- "1073741824"
  files[[cg(pod, "memory.high")]] <- "max"
  files[[cg(pod, "cpu.max")]] <- "200000 100000"
  files[[cg(pod, "pids.max")]] <- "1024"
  files[[cg(ctr, "cgroup.controllers")]] <- "cpuset cpu io memory pids"
  files[[cg(ctr, "memory.max")]] <- "max"
  files[[cg(ctr, "memory.high")]] <- "max"
  files[[cg(ctr, "memory.swap.max")]] <- "0"
  files[[cg(ctr, "memory.current")]] <- "314572800"
  files[[cg(ctr, "memory.stat")]] <- c(
    "anon 199229440",
    "file 115343360",
    "active_file 10485760",
    "inactive_file 104857600"
  )
  files[[cg(ctr, "cpu.max")]] <- "max 100000"
  files[[cg(ctr, "cpu.weight")]] <- "79"
  files[[cg(ctr, "cpu.stat")]] <- c(
    "usage_usec 4000000",
    "user_usec 3000000",
    "system_usec 1000000",
    "nr_periods 1000",
    "nr_throttled 100",
    "throttled_usec 500000"
  )
  files[[cg(ctr, "cpuset.cpus.effective")]] <- "0-7"
  files[[cg(ctr, "pids.max")]] <- "max"
  files[["proc/sys/kernel/hostname"]] <- "web-6b8f9-2xkqz"
  files[["var/run/secrets/kubernetes.io/serviceaccount/namespace"]] <- "default"
  write_tree("k8s-v2-limits", files)
})

# An LXCFS container: /proc/meminfo and /proc/cpuinfo are FUSE files showing
# the container's 512 MiB limit instead of the host's memory.
local({
  files <- modifyList(common(total_kb = 524288, available_kb = 400000), list(
    "proc/self/cgroup" = "0::/",
    "proc/self/mountinfo" = c(
      "500 450 0:60 / / rw,relatime - overlay overlay rw,lowerdir=/var/lib/lxc/a,upperdir=/var/lib/lxc/b,workdir=/var/lib/lxc/c",
      "510 500 0:26 / /sys/fs/cgroup rw,nosuid,nodev,noexec,relatime - cgroup2 cgroup2 rw,nsdelegate",
      "520 505 0:70 /proc/meminfo /proc/meminfo rw,nosuid,nodev,relatime - fuse.lxcfs lxcfs rw,user_id=0,group_id=0,allow_other",
      "521 505 0:70 /proc/cpuinfo /proc/cpuinfo rw,nosuid,nodev,relatime - fuse.lxcfs lxcfs rw,user_id=0,group_id=0,allow_other"
    ),
    "sys/fs/cgroup/cgroup.controllers" = "cpu memory pids",
    "sys/fs/cgroup/memory.max" = "536870912",
    "sys/fs/cgroup/memory.high" = "max",
    "sys/fs/cgroup/memory.current" = "134217728",
    "sys/fs/cgroup/memory.stat" = c("anon 100663296", "inactive_file 16777216"),
    "sys/fs/cgroup/cpu.max" = "max 100000",
    "sys/fs/cgroup/cpu.stat" = c("usage_usec 1000", "nr_periods 0", "nr_throttled 0"),
    "sys/fs/cgroup/pids.max" = "max"
  ))
  write_tree("lxcfs", files)
})

# Substrate scenarios (Stage 3) -----------------------------------------

no_hypervisor_flag <- function(lines) sub(" hypervisor", "", lines, fixed = TRUE)

# A host (not a container): systemd as PID 1, ext4 root, cgroup v2 session.
host_files <- function(os_release, kernel, hostname, dmi = list(), cpu_hypervisor = TRUE) {
  files <- modifyList(common(), list(
    "etc/os-release" = os_release,
    "proc/sys/kernel/osrelease" = kernel,
    "proc/sys/kernel/hostname" = hostname,
    "proc/sys/kernel/version" = "#1 SMP PREEMPT_DYNAMIC Mon Sep 30 12:00:00 UTC 2026",
    "proc/1/comm" = "systemd",
    "proc/stat" = "btime 1790000000",
    "proc/uptime" = "86400.50 300000.25",
    "proc/self/cgroup" = "0::/user.slice/user-1000.slice/session-3.scope",
    "proc/self/mountinfo" = c(
      "22 1 259:2 / / rw,relatime shared:1 - ext4 /dev/nvme0n1p2 rw",
      "30 23 0:26 / /sys/fs/cgroup rw,nosuid,nodev,noexec,relatime shared:4 - cgroup2 cgroup2 rw,nsdelegate,memory_recursiveprot"
    ),
    "sys/fs/cgroup/cgroup.controllers" = "cpuset cpu io memory pids",
    "sys/fs/cgroup/user.slice/user-1000.slice/session-3.scope/memory.max" = "max",
    "sys/fs/cgroup/user.slice/user-1000.slice/session-3.scope/cpu.max" = "max 100000",
    "sys/fs/cgroup/user.slice/user-1000.slice/session-3.scope/memory.current" = "52428800"
  ))
  if (!cpu_hypervisor) {
    files[["proc/cpuinfo"]] <- no_hypervisor_flag(files[["proc/cpuinfo"]])
  }
  for (field in names(dmi)) {
    files[[paste0("sys/class/dmi/id/", field)]] <- dmi[[field]]
  }
  files
}

ubuntu <- c(
  'PRETTY_NAME="Ubuntu 24.04.1 LTS"',
  'NAME="Ubuntu"',
  'VERSION_ID="24.04"',
  'VERSION="24.04.1 LTS (Noble Numbat)"',
  "ID=ubuntu",
  "ID_LIKE=debian"
)

write_tree("linux-baremetal", host_files(
  ubuntu, "6.8.0-45-generic", "build-07",
  dmi = list(
    sys_vendor = "Dell Inc.",
    product_name = "PowerEdge R650",
    board_vendor = "Dell Inc.",
    bios_vendor = "Dell Inc.",
    chassis_asset_tag = ""
  ),
  cpu_hypervisor = FALSE
))

local({
  files <- host_files(
    ubuntu, "6.8.0-1015-azure", "vm-analytics-01",
    dmi = list(
      sys_vendor = "Microsoft Corporation",
      product_name = "Virtual Machine",
      board_vendor = "Microsoft Corporation",
      bios_vendor = "Microsoft Corporation",
      chassis_asset_tag = azure_tag <- "7783-7084-3265-9085-8269-3286-77"
    )
  )
  files[["var/lib/waagent/provisioned"]] <- ""
  write_tree("azure-vm", files)
})

write_tree("aws-ec2", host_files(
  c(
    'NAME="Amazon Linux"',
    'VERSION_ID="2023"',
    'ID="amzn"',
    'ID_LIKE="fedora"',
    'PRETTY_NAME="Amazon Linux 2023.5.20240916"'
  ),
  "6.1.109-118.189.amzn2023.x86_64", "ip-10-0-1-23.ec2.internal",
  dmi = list(
    sys_vendor = "Amazon EC2",
    product_name = "m6i.large",
    board_vendor = "Amazon EC2",
    bios_vendor = "Amazon EC2",
    chassis_asset_tag = "Amazon EC2"
  )
))

write_tree("gcp-vm", host_files(
  c(
    'PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"',
    'NAME="Debian GNU/Linux"',
    'VERSION_ID="12"',
    "ID=debian"
  ),
  "6.1.0-25-cloud-amd64", "instance-1",
  dmi = list(
    sys_vendor = "Google",
    product_name = "Google Compute Engine",
    board_vendor = "Google",
    bios_vendor = "Google",
    chassis_asset_tag = ""
  )
))

# WSL2 has no DMI in sysfs and runs its own init as PID 1.
local({
  files <- host_files(ubuntu, "5.15.153.1-microsoft-standard-WSL2", "DESKTOP-7Q2K")
  files[["proc/1/comm"]] <- "init"
  write_tree("wsl2", files)
})

# An AKS pod on cgroup v2 with a private cgroup namespace, running under
# containerd on an Azure node, with a Downward API volume at /etc/podinfo.
local({
  uid <- "5d2c7a8e-1f3b-4c6d-9e0a-7b8c9d0e1f2a"
  files <- modifyList(common("0-3", 4, 16 * 1024^2, 12 * 1024^2), list(
    "etc/os-release" = c('NAME="Ubuntu"', 'VERSION_ID="24.04"', "ID=ubuntu", "ID_LIKE=debian"),
    "proc/sys/kernel/osrelease" = "5.15.0-1073-azure",
    "proc/sys/kernel/hostname" = "spark-driver-7d9f-xk2lp",
    "proc/1/comm" = "tini",
    "proc/self/cgroup" = "0::/",
    "proc/1/cgroup" = "0::/",
    "proc/self/mountinfo" = c(
      "800 750 0:300 / / rw,relatime - overlay overlay rw,lowerdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/41/fs,upperdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/42/fs,workdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/42/work",
      "805 800 0:26 / /sys/fs/cgroup ro,nosuid,nodev,noexec,relatime - cgroup2 cgroup2 rw,nsdelegate,memory_recursiveprot",
      sprintf("810 800 8:1 /var/lib/kubelet/pods/%s/volumes/kubernetes.io~downward-api/podinfo /etc/podinfo ro,relatime - ext4 /dev/sda1 rw", uid),
      sprintf("811 800 8:1 /var/lib/kubelet/pods/%s/etc-hosts /etc/hosts rw,relatime - ext4 /dev/sda1 rw", uid),
      sprintf("812 800 0:310 / /var/run/secrets/kubernetes.io/serviceaccount ro,relatime - tmpfs tmpfs rw,size=1024k")
    ),
    "var/run/secrets/kubernetes.io/serviceaccount/namespace" = "analytics",
    "etc/podinfo/labels" = c('app="spark-driver"', 'pod-template-hash="7d9f"'),
    "etc/podinfo/annotations" = c('kubernetes.io/config.source="api"', 'team="data"'),
    "sys/class/dmi/id/sys_vendor" = "Microsoft Corporation",
    "sys/class/dmi/id/product_name" = "Virtual Machine",
    "sys/class/dmi/id/chassis_asset_tag" = "7783-7084-3265-9085-8269-3286-77",
    "sys/fs/cgroup/cgroup.controllers" = "cpuset cpu io memory pids",
    "sys/fs/cgroup/memory.max" = "4294967296",
    "sys/fs/cgroup/memory.high" = "max",
    "sys/fs/cgroup/memory.current" = "1073741824",
    "sys/fs/cgroup/memory.stat" = c("anon 805306368", "inactive_file 134217728"),
    "sys/fs/cgroup/cpu.max" = "150000 100000",
    "sys/fs/cgroup/cpu.stat" = c("usage_usec 9000000", "nr_periods 3000", "nr_throttled 30"),
    "sys/fs/cgroup/cpuset.cpus.effective" = "0-3",
    "sys/fs/cgroup/pids.max" = "max"
  ))
  write_tree("aks-pod-downward-api", files)
})
