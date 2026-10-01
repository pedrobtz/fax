# Parsers shared by resolvers and the usage probe. They never error: invalid
# input gives NULL (for structured values) or NA (for scalars).

# Expands a CPU range list: "0-3,8" gives 0, 1, 2, 3 and 8.
parse_range_list <- function(x) {
  x <- trimws(paste(x, collapse = ","))
  if (is.na(x) || !nzchar(x)) {
    return(integer())
  }
  parts <- trimws(strsplit(x, ",", fixed = TRUE)[[1]])
  parts <- parts[nzchar(parts)]
  out <- lapply(parts, function(part) {
    bounds <- suppressWarnings(as.integer(strsplit(part, "-", fixed = TRUE)[[1]]))
    if (length(bounds) < 1 || length(bounds) > 2 || anyNA(bounds)) {
      return(NULL)
    }
    if (length(bounds) == 2) {
      if (bounds[2] < bounds[1]) {
        return(NULL)
      }
      return(seq.int(bounds[1], bounds[2]))
    }
    bounds
  })
  if (any(vapply(out, is.null, logical(1)))) {
    return(NULL)
  }
  sort(unique(unlist(out)))
}

# cgroup limit values: "max" -> Inf, numbers -> double, anything else -> NA
parse_limit <- function(x) {
  x <- trimws(x[1])
  if (is.na(x) || !nzchar(x)) {
    return(NA_real_)
  }
  if (identical(x, "max")) {
    return(Inf)
  }
  suppressWarnings(as.numeric(x))
}

# "key: value" lines -> named character vector, split at the first separator
parse_kv <- function(lines, sep = ":") {
  lines <- lines[!is.na(lines)]
  pos <- regexpr(sep, lines, fixed = TRUE)
  keep <- pos > 0
  lines <- lines[keep]
  pos <- pos[keep]
  values <- trimws(substr(lines, pos + nchar(sep), nchar(lines)))
  names(values) <- trimws(substr(lines, 1, pos - 1))
  values
}

# "16384 kB" -> bytes. /proc uses kB to mean KiB.
parse_size <- function(x) {
  parts <- strsplit(trimws(x[1]), "[[:space:]]+")[[1]]
  n <- suppressWarnings(as.numeric(parts[1]))
  if (length(n) == 0 || is.na(n)) {
    return(NA_real_)
  }
  unit <- if (length(parts) > 1) tolower(parts[2]) else "b"
  multiplier <- switch(
    unit,
    b = 1,
    kb = 1024,
    mb = 1024^2,
    gb = 1024^3,
    NA_real_
  )
  n * multiplier
}
