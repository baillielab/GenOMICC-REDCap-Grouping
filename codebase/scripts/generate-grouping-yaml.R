# =============================================================================
# genomicc-redcap-grouping/codebase/scripts/generate-grouping-yaml.R
# Generates a single phenotype_groupings_YYYYMMDD.yaml from a profiles csv file
# Called by grouping-yaml-launcher.sh; can also be run interactively via
# codebase/shared_utilities/dev_bootstrap.R (NOT YET FUNCTIONAL)
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
OUTPUT_DIR  <- get_arg("--output")
CODEBASE    <- get_arg("--codebase")
FIXED_COLS  <- 6



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Pre-run Checks ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if (is.null(INPUT_FILE) || is.null(OUTPUT_DIR)) {
  stop("--input and --output are required arguments.")
}

message("Input  : ", INPUT_FILE)
message("Output : ", OUTPUT_DIR)




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Source ####
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
## Load input file ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
df <- read_csv(INPUT_FILE, na = c("", "NA"), show_col_types = FALSE)

fixed_cols     <- names(df)[1:FIXED_COLS]
phenotype_cols <- names(df)[(FIXED_COLS + 1):ncol(df)]

message("Fixed columns    : ", paste(fixed_cols, collapse = ", "))
message("Phenotype columns: ", paste(phenotype_cols, collapse = ", "))




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Collect Phenotype Groups ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
all_groups <- list()

for (phenotype_col in phenotype_cols) {
  phenotype_df <- df[!is.na(df[[phenotype_col]]), ]

  if (nrow(phenotype_df) == 0) {
    message("Skipping '", phenotype_col, "' — no labelled rows found.")
    next
  }

  for (label_value in unique(phenotype_df[[phenotype_col]])) {
    label_df <- phenotype_df[phenotype_df[[phenotype_col]] == label_value, ]

    group_entry <- list(
      phenotype_column = phenotype_col,
      phenotype_label = label_value,
      profiles = build_profiles(label_df)
    )

    all_groups <- c(all_groups, list(group_entry))
    message("Processed: ", phenotype_col, " = '", label_value, "'")
  }
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Write Output ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
out_file    <- file.path(OUTPUT_DIR, paste0("gwas-grouped-phenotypes-", timestamp, ".yaml"))

write_yaml(list(phenotype_groups = all_groups), out_file)
message("Written: ", out_file)