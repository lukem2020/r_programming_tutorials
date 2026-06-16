# Load TLG catalog registry (config/tlg_registry.yml).

suppressPackageStartupMessages(library(yaml))

load_tlg_registry <- function(root = find_project_root()) {
  yaml::read_yaml(file.path(root, "config", "tlg_registry.yml"))
}

load_dataset_inventory <- function(root = find_project_root()) {
  path <- file.path(root, "config", "dataset_inventory.yml")
  if (!file.exists(path)) return(NULL)
  yaml::read_yaml(path)
}

tlg_module_label <- function(entry) {
  sprintf("%s — %s", entry$code, entry$title)
}

tlg_entries_by_category <- function(registry) {
  entries <- registry$entries
  cats <- unique(vapply(entries, function(e) e$category, character(1)))
  setNames(
    lapply(cats, function(c) Filter(function(e) identical(e$category, c), entries)),
    cats
  )
}

tlg_domain_groups <- function(entries) {
  domains <- unique(vapply(entries, function(e) e$domain, character(1)))
  setNames(
    lapply(domains, function(d) Filter(function(e) identical(e$domain, d), entries)),
    domains
  )
}

domain_display_name <- function(domain) {
  gsub("-", " ", tools::toTitleCase(domain))
}

datasets_available <- function(inventory, required) {
  if (is.null(inventory)) return(FALSE)
  req <- unlist(required, use.names = FALSE)
  names_avail <- vapply(inventory$datasets, function(d) d$name, character(1))
  status <- vapply(inventory$datasets, dataset_is_available, logical(1))
  available_set <- names_avail[status]
  all(req %in% available_set)
}

dataset_is_available <- function(d) {
  avail <- d$available
  isTRUE(avail) || identical(avail, "yes") || identical(avail, "Y")
}

inventory_dataset_available <- function(name, inventory, root = NULL) {
  if (is.null(inventory)) return(FALSE)
  idx <- match(name, vapply(inventory$datasets, function(d) d$name, character(1)))
  if (is.na(idx)) return(FALSE)
  ds <- inventory$datasets[[idx]]
  if (!dataset_is_available(ds)) return(FALSE)
  if (!is.null(root) && !is.null(ds$path) && nzchar(ds$path)) {
    return(file.exists(file.path(root, ds$path)))
  }
  TRUE
}

entry_has_data <- function(entry, inventory, root = NULL) {
  req <- unlist(entry$required_datasets, use.names = FALSE)
  if (length(req) == 0L) return(FALSE)
  if (is.null(inventory)) {
    core <- c("ADSL", "ADAE", "ADLB", "ADEX", "ADVS", "ADCM", "ADMH", "ADTTE")
    return(all(req %in% core))
  }
  all(vapply(req, inventory_dataset_available, logical(1), inventory = inventory, root = root))
}

is_phase1_entry <- function(entry, registry) {
  entry$code %in% unlist(registry$phase1_codes, use.names = FALSE)
}

TLG_TERN_IMPLEMENTED <- c("DMT01")

entry_is_runnable <- function(entry, registry) {
  if (identical(entry$implementation, "tern_layout")) {
    return(entry$code %in% TLG_TERN_IMPLEMENTED)
  }
  identical(entry$implementation, "teal_module") && is_phase1_entry(entry, registry)
}

required_datasets_for_entries <- function(entries) {
  sort(unique(unlist(
    lapply(entries, function(e) unlist(e$required_datasets, use.names = FALSE)),
    use.names = FALSE
  )))
}

filter_registry_for_app <- function(registry, inventory = NULL, root = NULL) {
  # Assign directly: modifyList() recursively merges list-valued fields and would
  # keep the full catalog entries alongside the filtered subset.
  registry$entries <- Filter(function(e) {
    entry_has_data(e, inventory, root) && entry_is_runnable(e, registry)
  }, registry$entries)
  registry
}
