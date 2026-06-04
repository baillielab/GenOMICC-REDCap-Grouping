# =============================================================================
# genomicc-redcap-grouping/codebase/scripts/generate-grouping-yaml.R
# Generates a gwas-grouped-phenotypes.yaml from a profiles csv file annotated 
# with a single phenotypes column (will error out if more than one phenotype col is present)
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

INPUT_FILE     <- get_arg("--input")
OUTPUT_DIR     <- get_arg("--output")
CODEBASE       <- get_arg("--codebase")
PHENOTYPE_NAME <- get_arg("--name")



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Pre-run Checks ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if (is.null(INPUT_FILE) || is.null(OUTPUT_DIR) || is.null(PHENOTYPE_NAME)) {
  stop("--input, --output, and --name are required arguments.")
}

message("Input  : ", INPUT_FILE)
message("Output : ", OUTPUT_DIR)
message("Name   : ", PHENOTYPE_NAME)




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

# Validate that all expected fixed columns are present
missing_fixed <- setdiff(FIXED_PROFILE_COLS, names(df))
if (length(missing_fixed) > 0) {
  stop("Input file is missing expected fixed columns: ",
       paste(missing_fixed, collapse = ", "))
}

# Identify phenotype columns: anything beyond the fixed cols,
# dropping any empty/NA column names from ragged CSVs
phenotype_cols <- setdiff(names(df), FIXED_PROFILE_COLS)
phenotype_cols <- phenotype_cols[!is.na(phenotype_cols) & nchar(trimws(phenotype_cols)) > 0]

message("Fixed columns    : ", paste(FIXED_PROFILE_COLS, collapse = ", "))
message("Phenotype columns: ", paste(phenotype_cols, collapse = ", "))

if (length(phenotype_cols) == 0) {
  stop("No phenotype columns found. Add at least one phenotype column to the profiles file.")
}

if (length(phenotype_cols) > 1) {
  stop("Multiple phenotype columns found: ", paste(phenotype_cols, collapse = ", "),
       "\nPlease run --generate separately for each phenotype column.")
}




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
      case_definitions = build_profiles(label_df)
    )

    all_groups <- c(all_groups, list(group_entry))
    message("Processed: ", phenotype_col, " = '", label_value, "'")
  }
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Write Output ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
out_file <- file.path(OUTPUT_DIR, paste0(PHENOTYPE_NAME, "-groups.yaml"))

yaml_str <- as.yaml(list(phenotype_group = all_groups))

collapse_delta_lists <- function(yaml_str) {
  pattern <- "assay_delta:\n(?:[ \t]+-\\s*-?[0-9]+\n)+"
  repeat {
    m <- regexpr(pattern, yaml_str, perl = TRUE)
    if (m == -1) break
    block <- regmatches(yaml_str, m)
    vals  <- regmatches(block, gregexpr("-?[0-9]+", block))[[1]]
    inline <- paste0("assay_delta: [", paste(vals, collapse = ", "), "]\n")
    regmatches(yaml_str, m) <- inline
  }
  yaml_str
}
yaml_str <- collapse_delta_lists(yaml_str)

writeLines(yaml_str, out_file)
message("Written: ", out_file)