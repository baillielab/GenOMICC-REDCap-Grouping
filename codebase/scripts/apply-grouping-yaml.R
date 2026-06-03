# =============================================================================
# genomicc-redcap-grouping/codebase/scripts/apply-grouping-yaml.R
# Applies the grouping yaml, which defines GWAS grouping phenotypes, to a profiles csv file,
# adding a phenotype label column and its total_px counterpart.
# Called by gwas-phenotype-grouping-launcher.sh
# =============================================================================




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Args ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) > 0) args[idx + 1] else default
}

INPUT_FILE  <- get_arg("--input")
YAML_FILE   <- get_arg("--yaml")
OUTPUT_DIR  <- get_arg("--output")
CODEBASE    <- get_arg("--codebase")




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Pre-run Checks ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if (is.null(INPUT_FILE) || is.null(YAML_FILE) || is.null(OUTPUT_DIR)) {
  stop("--input, --yaml, and --output are required arguments.")
}

message("Input  : ", INPUT_FILE)
message("YAML   : ", YAML_FILE)
message("Output : ", OUTPUT_DIR)




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Source ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if (!is.null(CODEBASE)) {
  functions_path <- file.path(CODEBASE, "scripts", "functions.R")
  if (file.exists(functions_path)) source(functions_path)
}

if (!is.null(CODEBASE)) {
  shared_params_path <- file.path(CODEBASE, "shared-utilities", "shared-params.R")
  if (file.exists(shared_params_path)) source(shared_params_path)
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Libraries ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
for (lib in libs_required) {
  library(lib, character.only = TRUE)
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Load Inputs ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
profiles <- read_csv(INPUT_FILE, na = c("", "NA"), show_col_types = FALSE)
config   <- read_yaml(YAML_FILE)

# Validate that all expected fixed columns are present
missing_fixed <- setdiff(FIXED_PROFILE_COLS, names(profiles))
if (length(missing_fixed) > 0) {
  stop("Input file is missing expected fixed columns: ",
       paste(missing_fixed, collapse = ", "))
}

message("Profiles loaded : ", nrow(profiles), " rows, ",
        length(unique(profiles$profile_number)), " profiles")
message("Phenotype groups: ", length(config$phenotype_groups))




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Drop Pre-existing Phenotype Columns ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Remove any columns already defined in the yaml so they are rebuilt from scratch
yaml_cols  <- sapply(config$phenotype_groups, `[[`, "phenotype_column")
total_cols <- paste0(yaml_cols, "_total_px")
drop_cols  <- intersect(names(profiles), c(yaml_cols, total_cols))

if (length(drop_cols) > 0) {
  message("Dropping pre-existing columns: ", paste(drop_cols, collapse = ", "))
  profiles <- profiles[, !names(profiles) %in% drop_cols]
}




##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Apply Phenotype Groups ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
for (pg in config$phenotype_groups) {
  pheno_col <- pg$phenotype_column
  total_col <- paste0(pheno_col, "_total_px")

  profiles[[pheno_col]] <- NA_character_
  profiles[[total_col]] <- NA_real_

  for (pnum in unique(profiles$profile_number)) {
    idx          <- which(profiles$profile_number == pnum)
    profile_rows <- profiles[idx, ]

    # Skip profiles with any null prim_diagnosis_odap — should not occur in
    # clean data but guards against unexpected input
    if (any(is.na(profile_rows$prim_diagnosis_odap))) {
      warning("Profile ", pnum, " has NA prim_diagnosis_odap — skipping")
      next
    }

    label <- get_phenotype_label(profile_rows, pg)

    if (!is.na(label)) {
      profiles[[pheno_col]][idx] <- label
    }
  }

  # Calculate total_px as sum of number_px_with_profile across unique matched
  # profile_numbers, to avoid double-counting profiles spread over multiple rows
  matched_profiles <- unique(
    profiles$profile_number[!is.na(profiles[[pheno_col]])]
  )
  total_px <- sum(
    vapply(matched_profiles, function(pnum) {             
      px_rows <- profiles$number_px_with_profile[profiles$profile_number == pnum]
      val <- px_rows[!is.na(px_rows)][1]
      if (length(val) == 0 || is.na(val)) NA_integer_
      else as.integer(val)
    }, integer(1)),
    na.rm = TRUE
  )
  profiles[[total_col]][!is.na(profiles[[pheno_col]])] <- total_px

  n_matched_profiles <- length(matched_profiles)
  message("Phenotype '", pheno_col, "': ", n_matched_profiles,
          " profiles matched, ", total_px, " total patients")
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Write Output ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
out_file <- file.path(OUTPUT_DIR, "diagnoses_and_tests_profiles_with_phenotypes.csv")
write_csv(profiles, out_file)
message("Written: ", out_file)