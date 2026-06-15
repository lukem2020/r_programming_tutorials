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
  avail <- vapply(inventory$datasets, function(d) {
    if (!isTRUE(d$available)) return(FALSE)
    identical(d$name, req[1]) # placeholder
  }, logical(1))
  names_avail <- vapply(inventory$datasets, function(d) d$name, character(1))
  status <- vapply(inventory$datasets, function(d) isTRUE(d$available), logical(1))
  available_set <- names_avail[status]
  all(req %in% available_set)
}

entry_has_data <- function(entry, inventory) {
  req <- unlist(entry$required_datasets, use.names = FALSE)
  if (is.null(inventory)) {
    core <- c("ADSL", "ADAE", "ADLB", "ADEX", "ADVS", "ADCM", "ADMH", "ADTTE")
    return(all(req %in% core))
  }
  names_avail <- vapply(inventory$datasets, function(d) d$name, character(1))
  status <- vapply(inventory$datasets, function(d) isTRUE(d$available), logical(1))
  available_set <- names_avail[status]
  all(req %in% available_set)
}

is_phase1_entry <- function(entry, registry) {
  entry$code %in% unlist(registry$phase1_codes, use.names = FALSE)
}
