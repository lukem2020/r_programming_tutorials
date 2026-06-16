parse_github_remote <- function(url) {
  if (is.null(url) || !nzchar(url) || !grepl("github.com", url, fixed = TRUE)) {
    return(NULL)
  }
  path <- sub(".*github\\.com/", "", url)
  path <- sub("/+$", "", path)
  parts <- strsplit(path, "/", fixed = TRUE)[[1]]
  if (length(parts) < 2L) {
    return(NULL)
  }
  list(username = parts[[1]], repo = parts[[2]])
}

patch_manifest_from_lockfile <- function(manifest_path, lockfile_path) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite is required.", call. = FALSE)
  }
  lock <- jsonlite::fromJSON(lockfile_path, simplifyVector = FALSE)
  manifest <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)
  repos_cfg <- lock$R$Repositories
  repo_urls <- stats::setNames(
    vapply(repos_cfg, function(x) x[["URL"]], character(1)),
    vapply(repos_cfg, function(x) x[["Name"]], character(1))
  )
  repo_patched <- character(0)
  sha_pinned <- character(0)
  for (pkg in names(lock$Packages)) {
    if (!pkg %in% names(manifest$packages)) {
      next
    }
    entry <- lock$Packages[[pkg]]
    repo_name <- entry$Repository %||% "CRAN"
    if (identical(repo_name, "CRAN")) {
      next
    }
    repo_url <- repo_urls[[repo_name]]
    if (is.null(repo_url) || !nzchar(repo_url)) {
      repo_url <- "https://pharmaverse.r-universe.dev"
    }

    remote_sha <- entry$RemoteSha
    remote_url <- entry$RemoteUrl
    gh <- parse_github_remote(remote_url)
    if (!is.null(gh) && !is.null(remote_sha) && nzchar(remote_sha)) {
      desc <- manifest$packages[[pkg]]$description
      desc$Version <- entry$Version
      desc$RemoteType <- "github"
      desc$RemoteHost <- "api.github.com"
      desc$RemoteUsername <- gh$username
      desc$RemoteRepo <- gh$repo
      desc$RemoteRef <- remote_sha
      desc$RemoteSha <- remote_sha
      desc$GithubHost <- "api.github.com"
      desc$GithubUsername <- gh$username
      desc$GithubRepo <- gh$repo
      desc$GithubRef <- remote_sha
      desc$GithubSHA1 <- remote_sha
      manifest$packages[[pkg]]$Source <- "github"
      manifest$packages[[pkg]]$Repository <- "https://github.com"
      manifest$packages[[pkg]]$description <- desc
      sha_pinned <- c(sha_pinned, pkg)
      next
    }

    current <- manifest$packages[[pkg]]
    if (!identical(current$Source, repo_name) ||
        !identical(current$Repository, repo_url)) {
      manifest$packages[[pkg]]$Source <- repo_name
      manifest$packages[[pkg]]$Repository <- repo_url
      repo_patched <- c(repo_patched, pkg)
    }
  }

  if (length(repo_patched) > 0L || length(sha_pinned) > 0L) {
    jsonlite::write_json(
      manifest,
      manifest_path,
      auto_unbox = TRUE,
      pretty = TRUE,
      null = "null"
    )
  }
  if (length(sha_pinned) > 0L) {
    cat(
      "Pinned", length(sha_pinned), "manifest packages to GitHub commits:",
      paste(sha_pinned, collapse = ", "), "\n"
    )
  }
  if (length(repo_patched) > 0L) {
    cat(
      "Patched manifest repos for", length(repo_patched), "packages:",
      paste(repo_patched, collapse = ", "), "\n"
    )
  }
  if (length(repo_patched) == 0L && length(sha_pinned) == 0L) {
    cat("Manifest already matches renv.lock.\n")
  }
  invisible(list(repo_patched = repo_patched, sha_pinned = sha_pinned))
}
