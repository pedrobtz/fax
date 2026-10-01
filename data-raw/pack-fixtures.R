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

for (name in list.files(src)) {
  tarball <- file.path(normalizePath(dest), paste0(name, ".tar.gz"))
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
