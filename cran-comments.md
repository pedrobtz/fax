## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Test environments

* GitHub Actions: ubuntu-latest (R devel, release, oldrel-1), macos-latest
  (release), windows-latest (release)
* R-hub v2: linux (R-devel), macos-arm64 (R-devel), windows (R-devel)
* Live checks in Debian, Alpine and Fedora containers with CPU and memory
  limits, and in a 'Kubernetes' (kind) pod

## Notes for reviewers

* fax reads system files such as `/proc` and `/sys` on Linux and runs a few
  read-only system commands where no file exists (`sysctl`, `sw_vers` and
  `vm_stat` on macOS, `df`, `id`). It never writes outside `tempdir()` and
  never changes system state.
* It makes no network requests unless the user explicitly asks for cloud
  instance metadata with `facts(cloud = TRUE)` or `options(fax.cloud = TRUE)`.
  Requests then go only to the link-local instance metadata address
  (169.254.169.254) with a 1 second timeout. No example, test or vignette
  makes a network request.
* Tests use recorded fixture files (shipped as tarballs in
  `tests/testthat/fixtures/`), so they do not depend on the machine running
  them; a few checks of the live system assert only what holds everywhere.

## Method references

There are no published references describing the methods in this package. It
reads documented kernel and operating system interfaces (Linux control groups
v1 and v2, `/proc`, DMI, the 'Kubernetes' Downward API and the 'Azure' Instance
Metadata Service).
