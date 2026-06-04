# genomicc-redcap-grouping/codebase/scripts/functions.R
# Functions used in genomicc-redcap-grouping




# Robustly test for the ANY sentinel regardless of yaml parser behaviour
is_any <- function(x) !is.null(x) && length(x) == 1 && !is.na(x) && identical(as.character(x), "ANY")




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## build_assays ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Build a collapsed assay list for a group of rows sharing the same profile
# fingerprint (diagnosis + ordered assay_type/organism pairs).
# Rows are grouped by (assay_type, organism); assay_delta values are pooled
# into a sorted, deduplicated list per slot so the clinician can see all
# observed values compactly.
# NULL assay_type rows (no assay recorded) collapse to a single NULL-entry slot.
build_assays <- function(diag_df) {
  # If every row has no assay_type, the whole assays block is null
  if (all(is.na(diag_df$assay_type))) return(NULL)

  # Group by (assay_type, organism) — use string keys for easy splitting
  diag_df$assay_type <- as.character(diag_df$assay_type)
  diag_df$organism   <- as.character(diag_df$organism)

  # Build a key per row; NA becomes the string "__NA__" for grouping only
  make_key <- function(at, org) {
    paste0(if (is.na(at)) "__NA__" else at, "|||", if (is.na(org)) "__NA__" else org)
  }
  keys <- mapply(make_key, diag_df$assay_type, diag_df$organism)

  unique_keys <- unique(keys)

  assays <- lapply(unique_keys, function(k) {
    rows   <- diag_df[keys == k, ]
    at_val <- rows$assay_type[1]
    org_val <- rows$organism[1]

    # Pool deltas: drop NAs, dedup, sort
    raw_deltas <- rows$assay_delta
    non_na     <- sort(unique(as.integer(raw_deltas[!is.na(raw_deltas)])))

    list(
      assay_type  = if (is.na(at_val))  NULL else at_val,
      organism    = if (is.na(org_val)) NULL else org_val,
      assay_delta = if (length(non_na) == 0) NULL else as.list(non_na)
    )
  })

  assays
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## build_profiles ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Build a collapsed profiles list for all rows in a label group.
#
# Step 1 — per profile_number: compute a structural fingerprint = diagnosis +
#   ordered (assay_type, organism) pairs (ignoring delta). Profiles that share
#   the same fingerprint are structurally identical and will be collapsed.
#
# Step 2 — per fingerprint group: pool all delta values across profiles into
#   a sorted deduplicated list per assay slot via build_assays(), producing one
#   compact yaml entry per unique profile structure.
#
# This means:
#   - Single-row profiles that differ only in delta collapse to one entry with
#     a delta list.
#   - Multi-row profiles with the same (assay_type, organism) structure but
#     different deltas also collapse, with deltas pooled per assay slot.
#   - Profiles with genuinely different assay structures stay as separate entries.
build_profiles <- function(label_df) {

  # Compute per-profile fingerprints
  profile_nums <- unique(label_df$profile_number)

  fingerprints <- lapply(profile_nums, function(pnum) {
    pnum_df <- label_df[label_df$profile_number == pnum, ]
    diag    <- pnum_df$prim_diagnosis_odap[1]

    # Ordered (assay_type, organism) pairs — sort for canonical form
    pairs <- pnum_df[order(pnum_df$assay_type, pnum_df$organism),
                     c("assay_type", "organism")]
    pairs$assay_type <- as.character(pairs$assay_type)
    pairs$organism   <- as.character(pairs$organism)

    fp <- paste0(diag, "||",
                 paste(pairs$assay_type, pairs$organism, sep = "|", collapse = ";;;"))

    list(profile_number = pnum, diagnosis = diag, fingerprint = fp)
  })

  # Group profile_numbers by fingerprint
  fp_keys  <- sapply(fingerprints, `[[`, "fingerprint")
  diag_map <- setNames(sapply(fingerprints, `[[`, "diagnosis"), fp_keys)

  unique_fps <- unique(fp_keys)

  lapply(unique_fps, function(fp) {
    pnums_in_group <- sapply(fingerprints[fp_keys == fp], `[[`, "profile_number")
    group_df       <- label_df[label_df$profile_number %in% pnums_in_group, ]

    list(
      prim_diagnosis_odap = diag_map[[fp]],
      assays              = build_assays(group_df)
    )
  })
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## match_assay_row ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Match a single assay spec from YAML against a data row.
# Returns TRUE if the row satisfies all non-null fields in the spec.
match_assay_row <- function(row, assay_spec) {
  # Matching semantics for assay_type and organism:
  #   NULL / NA        -> require the data value to be NA  (field is absent/unknown)
  #   "ANY"            -> wildcard, skip this check entirely
  #   [v1, v2, ...]    -> value-set: match if data value is any of the listed values
  #   <scalar>         -> exact match required

  # assay_type
  if (identical(assay_spec$assay_type, "ANY")) {
    # wildcard - always passes
  } else if (is.null(assay_spec$assay_type) || (length(assay_spec$assay_type) == 1 && is.na(assay_spec$assay_type))) {
    if (!is.na(row$assay_type)) return(FALSE)
  } else if (length(assay_spec$assay_type) > 1 || is.list(assay_spec$assay_type)) {
    # Value-set: match if row value is any of the listed values
    allowed <- as.character(unlist(assay_spec$assay_type))
    if (is.na(row$assay_type) || !row$assay_type %in% allowed) return(FALSE)
  } else {
    if (is.na(row$assay_type) || row$assay_type != assay_spec$assay_type) return(FALSE)
  }

  # organism
  if (identical(assay_spec$organism, "ANY")) {
    # wildcard - always passes
  } else if (is.null(assay_spec$organism) || (length(assay_spec$organism) == 1 && is.na(assay_spec$organism))) {
    if (!is.na(row$organism)) return(FALSE)
  } else if (length(assay_spec$organism) > 1 || is.list(assay_spec$organism)) {
    # Value-set: match if row value is any of the listed values
    allowed <- as.character(unlist(assay_spec$organism))
    if (is.na(row$organism) || !row$organism %in% allowed) return(FALSE)
  } else {
    if (is.na(row$organism) || row$organism != assay_spec$organism) return(FALSE)
  }

  # assay_delta: "ANY"             = wildcard
  #              NULL / NA          = require NA in data
  #              list(min, max)     = inclusive range (named list)
  #              list(v1, v2, ...)  = value set — match if delta is IN the set
  #              atomic vector >1   = value set from inline yaml list e.g. [0, 1, 2]
  #              scalar             = exact match
  delta_spec <- assay_spec$assay_delta
  if (is_any(delta_spec)) {
    # wildcard - always passes
  } else if (is.null(delta_spec) || (length(delta_spec) == 1 && is.na(delta_spec))) {
    if (!is.na(row$assay_delta)) return(FALSE)
  } else if (is.list(delta_spec)) {
    if (is.na(row$assay_delta)) return(FALSE)
    if (!is.null(delta_spec$min) && !is.null(delta_spec$max)) {
      # Named list with min/max: inclusive range
      if (row$assay_delta < delta_spec$min) return(FALSE)
      if (row$assay_delta > delta_spec$max) return(FALSE)
    } else {
      # Unnamed list: value set — match if row delta is any of the values
      allowed <- as.integer(unlist(delta_spec))
      if (!as.integer(row$assay_delta) %in% allowed) return(FALSE)
    }
  } else if (length(delta_spec) > 1) {
    # Atomic vector (e.g. from inline yaml list): value set match
    if (is.na(row$assay_delta)) return(FALSE)
    if (!as.integer(row$assay_delta) %in% as.integer(delta_spec)) return(FALSE)
  } else {
    if (is.na(row$assay_delta) || row$assay_delta != delta_spec) return(FALSE)
  }

  TRUE
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## match_profile_entry ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Checks whether a profile (subset of rows sharing a profile_number) matches a
# single YAML case definition (one element of phenotype_group$case_definitions).
# Returns TRUE if:
#   - prim_diagnosis_odap matches, AND
#   - ALL assay specs in entry$assays are satisfied by at least one profile row, AND
#   - NO row in the profile satisfies any spec in entry$exclude (if present).
match_profile_entry <- function(profile_rows, entry) {

  # Check prim_diagnosis_odap (required)
  diag <- entry$prim_diagnosis_odap
  if (!is.null(diag) && !is.na(diag)) {
    if (!any(profile_rows$prim_diagnosis_odap == diag, na.rm = TRUE)) return(FALSE)
  }

  # If no assays specified (NULL or single ~ entry), require the profile to
  # have no assay data recorded (all assay_type values are NA).
  # This means assays: ~ matches only profiles with no test rows, not all profiles.
  assays <- entry$assays
  if (is.null(assays) || (length(assays) == 1 && is.null(assays[[1]]))) {
    return(all(is.na(profile_rows$assay_type)))
  }

  # AND logic: every assay spec must be matched by at least one row
  for (assay_spec in assays) {
    if (is.null(assay_spec)) next  # skip bare ~ entries

    # Use seq_len row indexing rather than apply() to avoid coercing the data
    # frame to a character matrix, which turns real NAs into the string "NA"
    matched <- any(vapply(seq_len(nrow(profile_rows)), function(i) {
      match_assay_row(as.list(profile_rows[i, ]), assay_spec)
    }, logical(1)))

    if (!matched) return(FALSE)
  }

  # Exclude logic: if any exclude spec is matched by at least one row, reject
  # the profile. Uses the same field matching semantics as assay specs.
  excludes <- entry$exclude
  if (!is.null(excludes)) {
    for (excl_spec in excludes) {
      if (is.null(excl_spec)) next  # skip bare ~ entries

      excluded <- any(vapply(seq_len(nrow(profile_rows)), function(i) {
        match_assay_row(as.list(profile_rows[i, ]), excl_spec)
      }, logical(1)))

      if (excluded) return(FALSE)
    }
  }

  TRUE
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## get_phenotype_label ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# For a given phenotype group, return the label if the profile matches any entry
# (OR logic across entries), otherwise NA.
get_phenotype_label <- function(profile_rows, phenotype_group) {
  for (entry in phenotype_group$case_definitions) {
    if (match_profile_entry(profile_rows, entry)) {
      return(phenotype_group$phenotype_label)
    }
  }
  NA_character_
}