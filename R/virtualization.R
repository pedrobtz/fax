dmi <- function(ctx) {
  if (ctx$os == "windows") {
    return(windows_dmi(ctx))
  }
  ctx$shared("dmi", function(ctx) {
    fields <- c(
      "sys_vendor",
      "product_name",
      "board_vendor",
      "bios_vendor",
      "bios_version",
      "chassis_asset_tag"
    )
    values <- vapply(
      fields,
      function(field) {
        line <- ctx$read(paste0("/sys/class/dmi/id/", field), n = 1L)
        if (length(line)) trimws(line[1]) else NA_character_
      },
      character(1)
    )
    if (all(is.na(values))) NULL else values
  })
}

# DMI substrings that identify a hypervisor, checked in order against the
# vendor and product fields (as systemd-detect-virt does).
dmi_hypervisors <- c(
  "Apple Virtualization" = "apple",
  "Amazon EC2" = "aws-nitro",
  "Google Compute Engine" = "kvm",
  "KVM" = "kvm",
  "QEMU" = "qemu",
  "VMware" = "vmware",
  "VMW" = "vmware",
  "innotek GmbH" = "virtualbox",
  "VirtualBox" = "virtualbox",
  "Oracle Corporation" = "virtualbox",
  "Xen" = "xen",
  "Bochs" = "bochs",
  "Parallels" = "parallels",
  "BHYVE" = "bhyve",
  "OpenStack" = "kvm"
)

detect_hypervisor <- function(ctx) {
  values <- dmi(ctx)
  if (!is.null(values)) {
    text <- values[c("sys_vendor", "product_name", "board_vendor", "bios_vendor")]
    text <- text[!is.na(text)]
    if (any(text == "Microsoft Corporation") && any(text == "Virtual Machine")) {
      return("hyperv")
    }
    for (pattern in names(dmi_hypervisors)) {
      if (any(grepl(pattern, text, fixed = TRUE))) {
        return(dmi_hypervisors[[pattern]])
      }
    }
  }
  xen <- ctx$read("/sys/hypervisor/type", n = 1L)
  if (length(xen) && trimws(xen) == "xen") {
    return("xen")
  }
  NULL
}

register_virtualization_facts <- function() {
  linux <- list(os = "linux")
  # Windows reads the same vendor fields from the BIOS registry key.
  dmi_os <- list(os = c("linux", "windows"))

  register(resolver("virtualization.hypervisor", confine = dmi_os, function(ctx) {
    hypervisor <- detect_hypervisor(ctx)
    if (!is.null(hypervisor)) {
      return(hypervisor)
    }
    if ("hypervisor" %in% ctx$fact("cpu.flags")) {
      "unknown"
    } else {
      not_applicable("No hypervisor detected.")
    }
  }))

  register(resolver("virtualization.type", confine = dmi_os, function(ctx) {
    hypervisor <- ctx$fact_record("virtualization.hypervisor")
    if (hypervisor$status == "ok") {
      return("vm")
    }
    # Physical only if we could actually look: DMI readable or CPU flags known.
    if (!is.null(dmi(ctx)) || !anyNA(ctx$fact("cpu.flags"))) "physical" else "unknown"
  }))

  register(resolver("virtualization.wsl", confine = linux, function(ctx) {
    release <- tolower(ctx$fact("os.kernel.release"))
    if (is.na(release) || !grepl("microsoft", release, fixed = TRUE)) {
      not_applicable("Not running under WSL.")
    }
    if (grepl("wsl2|microsoft-standard", release)) 2L else 1L
  }))
}
