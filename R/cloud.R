# Azure sets this DMI chassis asset tag on every VM.
azure_asset_tag <- "7783-7084-3265-9085-8269-3286-77"

register_cloud_facts <- function() {
  # Read on every call: Azure services that hide DMI are recognized from their
  # environment variables.
  register(resolver("cloud.provider", cache = FALSE, function(ctx) {
    if (!is.null(azure_platform_from_env(ctx))) {
      return("azure")
    }
    if (!ctx$os %in% c("linux", "windows")) {
      not_applicable("Cloud detection needs DMI (Linux) or the BIOS registry (Windows).")
    }
    values <- dmi(ctx)
    if (!is.null(values)) {
      text <- values[!is.na(values)]
      if (identical(unname(values[["chassis_asset_tag"]]), azure_asset_tag)) {
        return("azure")
      }
      hyperv <- any(text == "Microsoft Corporation") && any(text == "Virtual Machine")
      # The Azure guest agent: /var/lib/waagent on Linux, C:/WindowsAzure on Windows.
      agent <- if (ctx$os == "windows") "C:/WindowsAzure" else "/var/lib/waagent"
      if (hyperv && ctx$exists(agent)) {
        ctx$note(agent)
        return("azure")
      }
      if (any(grepl("Amazon EC2", text, fixed = TRUE))) {
        return("aws")
      }
      if (any(text == "Google") || any(grepl("Google Compute Engine", text, fixed = TRUE))) {
        return("gcp")
      }
    }
    not_applicable("No cloud provider detected.")
  }))
}
