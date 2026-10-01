#' CPU cores and memory this process can actually use
#'
#' `effective_cores()` is a safe default for the size of a thread pool or
#' worker pool. It takes the smallest of the host's logical CPUs, the process's
#' CPU affinity, the cgroup cpuset and the cgroup CPU quota (rounded up, since
#' a 1.5-core quota can keep 2 threads busy). Inside a container this is often
#' much smaller than [parallel::detectCores()].
#'
#' `effective_memory()` returns the memory limit that applies to the process
#' (`"limit"`): the smaller of the host's total memory and the cgroup memory
#' limit. With `what = "available"` it returns how much more can be allocated
#' now, counting reclaimable page cache as free, as the Kubernetes kubelet
#' does.
#'
#' Both are resource-based: they ignore settings such as `mc.cores` or
#' `MC_CORES`. Use `parallelly::availableCores()` if you want those honored.
#'
#' @param what `"limit"` for the memory limit, `"available"` for the memory
#'   that can still be allocated.
#' @returns `effective_cores()`: an integer, at least 1.
#'   `effective_memory()`: a number of bytes, `NA` if unknown.
#' @seealso [facts()] for the individual limits behind these values, e.g.
#'   `facts()$cpu` and `facts()$memory`.
#' @export
#' @examples
#' effective_cores()
#' effective_memory()
effective_cores <- function() {
  n <- fact("cpu.effective")
  if (is.na(n)) {
    n <- parallel::detectCores()
  }
  if (is.na(n) || n < 1) 1L else as.integer(n)
}

#' @rdname effective_cores
#' @export
effective_memory <- function(what = c("limit", "available")) {
  what <- match.arg(what)
  if (what == "available") {
    return(as.numeric(fact("memory.effective.available")))
  }
  limit <- fact("memory.effective.limit")
  if (isTRUE(is.infinite(limit))) {
    limit <- fact("memory.host.total")
  }
  as.numeric(limit)
}
