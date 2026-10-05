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
  lines <- tryCatch(
    suppressWarnings(readLines(root_path(path, root), n = n, warn = FALSE)),
    error = function(e) NULL
  )
  as_utf8(lines)
}

# Text from files, environment variables, options and commands can hold bytes
# that are not valid UTF-8, which make regular expressions fail in a UTF-8
# locale. Invalid bytes become "<xx>" so every parser sees valid strings.
as_utf8 <- function(x) {
  if (!is.character(x)) {
    return(x)
  }
  bad <- !validUTF8(x)
  if (any(bad)) {
    x[bad] <- iconv(x[bad], "UTF-8", "UTF-8", sub = "byte")
  }
  nms <- names(x)
  if (!is.null(nms) && !all(validUTF8(nms))) {
    names(x) <- as_utf8(nms)
  }
  x
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
