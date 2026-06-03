# genomicc-redcap-grouping/codebase/scripts/functions.R
# Functions used in genomicc-redcap-grouping





#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## build_assays ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Build assay list for a group of rows sharing the same diagnosis
build_assays <- function(diag_df) {
  assays <- lapply(seq_len(nrow(diag_df)), function(i) {
    row <- diag_df[i, ]
    list(
      assay_type  = if (is.na(row$assay_type))   NULL else row$assay_type,
      organism    = if (is.na(row$organism))      NULL else row$organism,
      assay_delta = if (is.na(row$assay_delta))   NULL else as.integer(row$assay_delta)
    )
  })
  # If every row has no assay_type, the whole assays block is null
  if (all(sapply(assays, function(a) is.null(a$assay_type)))) NULL else assays
}



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## build_profiles ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Build profiles list for all rows in a label group
build_profiles <- function(label_df) {
  diagnoses <- unique(label_df$prim_diagnosis_odap)
  lapply(diagnoses, function(diag) {
    diag_df <- label_df[label_df$prim_diagnosis_odap == diag, ]
    list(
      prim_diagnosis_odap = diag,
      assays              = build_assays(diag_df)
    )
  })
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## build_profiles ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Match a single assay spec from YAML against a data row.
# Returns TRUE if the row satisfies all non-null fields in the spec.
match_assay_row <- function(row, assay_spec) {
  # assay_type
  if (!is.null(assay_spec$assay_type) && !is.na(assay_spec$assay_type)) {
    if (is.na(row$assay_type) || row$assay_type != assay_spec$assay_type) return(FALSE)
  }

  # organism
  if (!is.null(assay_spec$organism) && !is.na(assay_spec$organism)) {
    if (is.na(row$organism) || row$organism != assay_spec$organism) return(FALSE)
  }

  # assay_delta: NULL/NA = wildcard; numeric = exact; list(min, max) = inclusive range
  delta_spec <- assay_spec$assay_delta
  if (!is.null(delta_spec) && !is.na(delta_spec)) {
    if (is.list(delta_spec)) {
      # Range match (inclusive)
      if (is.na(row$assay_delta))                  return(FALSE)
      if (row$assay_delta < delta_spec$min)         return(FALSE)
      if (row$assay_delta > delta_spec$max)         return(FALSE)
    } else {
      # Exact match
      if (is.na(row$assay_delta) || row$assay_delta != delta_spec) return(FALSE)
    }
  }
  # NULL/NA delta_spec = wildcard, always passes

  TRUE
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## match_profile_entry ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Checks whether a profile (subset of rows sharing a profile_number) matches a
# single YAML profile entry (one element of phenotype_group$profiles)
# Returns TRUE if ALL assay specs in the entry are satisfied by at least one row
# in the profile, AND prim_diagnosis_odap matches.
match_profile_entry <- function(profile_rows, entry) {

  # Check prim_diagnosis_odap (required)
  diag <- entry$prim_diagnosis_odap
  if (!is.null(diag) && !is.na(diag)) {
    if (!any(profile_rows$prim_diagnosis_odap == diag, na.rm = TRUE)) return(FALSE)
  }

  # If no assays specified (NULL or single NA entry), diagnosis match is enough
  assays <- entry$assays
  if (is.null(assays)) return(TRUE)

  # A YAML list with a single `~` comes through as list(NULL)
  if (length(assays) == 1 && is.null(assays[[1]])) return(TRUE)

  # AND logic: every assay spec must be matched by at least one row
  for (assay_spec in assays) {
    if (is.null(assay_spec)) next  # skip bare ~ entries

    matched <- any(apply(profile_rows, 1, function(r) {
      match_assay_row(as.list(r), assay_spec)
    }))

    if (!matched) return(FALSE)
  }

  TRUE
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## get_phenotype_label ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# For a given phenotype group, return the label if the profile matches any entry
# (OR logic across entries), otherwise NA.
get_phenotype_label <- function(profile_rows, phenotype_group) {
  for (entry in phenotype_group$profiles) {
    if (match_profile_entry(profile_rows, entry)) {
      return(phenotype_group$phenotype_label)
    }
  }
  NA_character_
}
