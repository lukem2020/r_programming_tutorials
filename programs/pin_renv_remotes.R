# Pin pharmaverse lockfile entries to exact git commits (not R-Universe HEAD).
pin_renv_lockfile_remotes <- function(lockfile_path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite is required.", call. = FALSE)
  }
  lock <- jsonlite::fromJSON(lockfile_path, simplifyVector = FALSE)
  pinned <- character(0)
  for (pkg in names(lock$Packages)) {
    entry <- lock$Packages[[pkg]]
    repo <- entry$Repository %||% "CRAN"
    sha <- entry$RemoteSha
    ref <- entry$RemoteRef
    if (identical(repo, "CRAN") || is.null(sha) || !nzchar(sha) || !identical(ref, "HEAD")) {
      next
    }
    lock$Packages[[pkg]]$RemoteRef <- sha
    url <- entry$RemoteUrl
    if (!is.null(url) && grepl("github.com", url, fixed = TRUE)) {
      lock$Packages[[pkg]]$RemoteType <- "github"
    }
    pinned <- c(pinned, pkg)
  }
  if (length(pinned) == 0L) {
    return(invisible(pinned))
  }
  jsonlite::write_json(
    lock,
    lockfile_path,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )
  cat(
    "Pinned renv.lock RemoteRef for", length(pinned), "packages:",
    paste(pinned, collapse = ", "), "\n"
  )
  invisible(pinned)
}
