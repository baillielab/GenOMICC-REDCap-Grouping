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