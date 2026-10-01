# Root-aware file access. Every filesystem read goes through these so tests
# can point `fax.root` at a fixture tree. Missing or unreadable files give NULL.

fax_root <- function() {
  root <- getOption("fax.root")
  if (is.null(root)) {
    root <- Sys.getenv("FAX_ROOT")
  }
  if (!nzchar(root)) {
    root <- "/"
  }
  root
}

root_path <- function(path, root = fax_root()) {
  if (identical(root, "/")) {
    return(path)
  }
  paste0(sub("/+$", "", root), "/", sub("^/+", "", path))
}

read_lines <- function(path, root = fax_root(), n = -1L) {
  tryCatch(
    suppressWarnings(readLines(root_path(path, root), n = n, warn = FALSE)),
    error = function(e) NULL
  )
}

file_exists <- function(path, root = fax_root()) {
  file.exists(root_path(path, root))
}

list_dir <- function(path, root = fax_root()) {
  path <- root_path(path, root)
  if (!dir.exists(path)) {
    return(NULL)
  }
  list.files(path, all.files = TRUE, no.. = TRUE)
}
