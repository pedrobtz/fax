# Packs each fixture tree in data-raw/fixtures/<name>/ into
# tests/testthat/fixtures/<name>.tar.gz. The trees are the source of truth and
# are easy to read and diff; the tarballs are what the tests use, because
# R CMD build rejects paths over 100 bytes and flags hidden files such as
# run/.containerenv. tests/testthat/test-fixtures.R checks they are in sync.
#
# Run from the package root: Rscript data-raw/pack-fixtures.R

src <- "data-raw/fixtures"
dest <- "tests/testthat/fixtures"
dir.create(dest, showWarnings = FALSE, recursive = TRUE)

# TRUE when the tarball already holds exactly the files of the tree, so it is
# left alone (tar records timestamps, so re-packing always changes the bytes).
same_content <- function(tarball, tree) {
  if (!file.exists(tarball)) {
    return(FALSE)
  }
  out <- tempfile()
  on.exit(unlink(out, recursive = TRUE))
  utils::untar(tarball, exdir = out, tar = "internal")
  files <- sort(list.files(tree, recursive = TRUE, all.files = TRUE))
  if (!identical(sort(list.files(out, recursive = TRUE, all.files = TRUE)), files)) {
    return(FALSE)
  }
  read <- \(dir, f) readBin(file.path(dir, f), "raw", file.size(file.path(dir, f)))
  all(vapply(files, \(f) identical(read(tree, f), read(out, f)), logical(1)))
}

for (name in list.files(src)) {
  tarball <- file.path(normalizePath(dest), paste0(name, ".tar.gz"))
  if (same_content(tarball, file.path(src, name))) {
    next
  }
  old <- setwd(file.path(src, name))
  files <- list.files(".", recursive = TRUE, all.files = TRUE, no.. = TRUE)
  withCallingHandlers(
    utils::tar(tarball, files = sort(files), compression = "gzip", tar = "internal"),
    warning = function(w) {
      if (grepl("more than 100 bytes", conditionMessage(w))) invokeRestart("muffleWarning")
    }
  )
  setwd(old)
  message(name, ": ", length(files), " files")
}
