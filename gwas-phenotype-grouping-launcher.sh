#!/bin/bash

# =============================================================================
# gwas-phenotype-grouping-launcher.sh
# Unified launcher for the GWAS phenotype grouping workflow.
#
# Supports two operations, which can be used independently or together:
#   --generate   Generate a grouping yaml FROM a profiles csv (path 2b)
#   --apply      Apply a grouping yaml TO a profiles csv    (path 3)
#   --finalise   Copy the yaml and output profiles csv to output/
#
# Each named phenotype (-n) gets its own persistent run directory, so the
# user can return to a previous session by re-using the same name.
#
# Usage:
#   ./gwas-phenotype-grouping-launcher.sh -n <name> --apply
#   ./gwas-phenotype-grouping-launcher.sh -n <name> --generate
#   ./gwas-phenotype-grouping-launcher.sh -n <name> --generate --apply
#   ./gwas-phenotype-grouping-launcher.sh -n <name> --apply --finalise
#   ./gwas-phenotype-grouping-launcher.sh -n <name> --finalise
#   ./gwas-phenotype-grouping-launcher.sh --help
# =============================================================================




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Console Text Colours ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Paths ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEBASE="$REPO_ROOT/codebase"
PARAMS_DIR="$CODEBASE/external-params"
RUNS_DIR="$REPO_ROOT/runs"
GENERATE_SCRIPT="$CODEBASE/scripts/generate-grouping-yaml.R"
APPLY_SCRIPT="$CODEBASE/scripts/apply-grouping-yaml.R"




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Usage ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
usage() {
  echo ""
  echo "Usage: ./gwas-phenotype-grouping-launcher.sh -n <name> [options]"
  echo ""
  echo "Required:"
  echo "  -n, --name <name>    Phenotype name — used to name the run directory."
  echo "                       Re-using the same name resumes a previous session."
  echo ""
  echo "Operations (at least one required):"
  echo "  --generate           Generate a grouping yaml from a profiles csv."
  echo "                       Output: runs/genomicc-redcap-grouping_<name>/work/"
  echo "  --apply              Apply a grouping yaml to a profiles csv."
  echo "                       Output: runs/genomicc-redcap-grouping_<name>/work/"
  echo "  --finalise           Copy the yaml and output profiles csv to output/."
  echo "                       Can be combined with --apply or run alone."
  echo ""
  echo "Options:"
  echo "  -i, --input <path>   Path to input profiles csv."
  echo "                       Default: newest diagnoses_and_tests_profiles_*.csv"
  echo "                       in codebase/external-params/"
  echo "  -y, --yaml <path>    Path to grouping yaml (used by --apply)."
  echo "                       Default: newest .yaml in the run's work/ directory"
  echo "  -h, --help           Show this help message"
  echo ""
  echo "Examples:"
  echo "  ./gwas-phenotype-grouping-launcher.sh -n covid19 --apply"
  echo "  ./gwas-phenotype-grouping-launcher.sh -n covid19 --generate --apply"
  echo "  ./gwas-phenotype-grouping-launcher.sh -n covid19 -y my-custom.yaml --apply --finalise"
  echo "  ./gwas-phenotype-grouping-launcher.sh -n covid19 --finalise"
  echo ""
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Parse Flags ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PHENOTYPE_NAME=""
INPUT_FILE_ARG=""
YAML_FILE_ARG=""
DO_GENERATE=false
DO_APPLY=false
DO_FINALISE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)
      PHENOTYPE_NAME="$2"
      shift 2
      ;;
    -i|--input)
      INPUT_FILE_ARG="$2"
      shift 2
      ;;
    -y|--yaml)
      YAML_FILE_ARG="$2"
      shift 2
      ;;
    --generate)
      DO_GENERATE=true
      shift
      ;;
    --apply)
      DO_APPLY=true
      shift
      ;;
    --finalise)
      DO_FINALISE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown flag: $1${NC}"
      usage
      exit 1
      ;;
  esac
done




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Validate Flags ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

### At least one operation required ====
if ! $DO_GENERATE && ! $DO_APPLY && ! $DO_FINALISE; then
  echo -e "${RED}Error: no operation specified. Use --generate, --apply, and/or --finalise.${NC}"
  usage
  exit 1
fi

### Phenotype name required ====
if [ -z "$PHENOTYPE_NAME" ]; then
  echo -e "${RED}Error: -n / --name is required.${NC}"
  usage
  exit 1
fi




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Checks ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

### R ====
if ! command -v Rscript &> /dev/null; then
  echo -e "${RED}Error: Rscript not found. Please install R from https://cran.r-project.org${NC}"
  exit 1
fi
echo -e "${GREEN}Using R: $(Rscript --version 2>&1)${NC}"

### R Packages ====
echo -e "${YELLOW}Checking R packages...${NC}"
Rscript --vanilla -e "
  pkgs <- c('dplyr', 'yaml', 'readr', 'tidyverse', 'rlang')
  missing <- pkgs[!pkgs %in% installed.packages()[,'Package']]
  if (length(missing) > 0) {
    message('Installing missing packages: ', paste(missing, collapse = ', '))
    install.packages(missing, repos = 'https://cloud.r-project.org', quiet = TRUE)
  } else {
    message('All packages present.')
  }
"




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Run Dir Setup ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
RUN_DIR="$RUNS_DIR/genomicc-redcap-grouping_${PHENOTYPE_NAME}"
WORK_DIR="$RUN_DIR/work"
PARAMS_RUN_DIR="$RUN_DIR/params"
LOGS_DIR="$RUN_DIR/logs"
OUTPUT_DIR="$RUN_DIR/output"
LOG_FILE="$LOGS_DIR/gwas-phenotype-grouping.log"

if [ -d "$RUN_DIR" ]; then
  echo -e "${BLUE}Resuming session: $RUN_DIR${NC}"
else
  echo -e "${BLUE}Creating new session: $RUN_DIR${NC}"
  mkdir -p "$WORK_DIR" "$PARAMS_RUN_DIR" "$LOGS_DIR" "$OUTPUT_DIR"
fi

### Append a run header to the log ====
RUN_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
{
  echo ""
  echo "============================================================"
  echo "Run: $RUN_TIMESTAMP"
  echo "Operations:$(  $DO_GENERATE && echo ' --generate')$(  $DO_APPLY && echo ' --apply')$(  $DO_FINALISE && echo ' --finalise')"
  echo "============================================================"
} >> "$LOG_FILE"

### Record git commit (only on first run) ====
if [ ! -f "$RUN_DIR/git_commit.txt" ]; then
  if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
    git -C "$REPO_ROOT" describe --tags --always --dirty > "$RUN_DIR/git_commit.txt" 2>/dev/null \
      || git -C "$REPO_ROOT" rev-parse HEAD > "$RUN_DIR/git_commit.txt"
    echo -e "${BLUE}Git commit: $(cat "$RUN_DIR/git_commit.txt")${NC}"
  else
    echo "git not available" > "$RUN_DIR/git_commit.txt"
    echo -e "${YELLOW}Warning: not a git repository — commit not recorded${NC}"
  fi
fi




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Resolve Input Profiles CSV ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
EXISTING_PARAMS_FILE=$(ls "$PARAMS_RUN_DIR"/diagnoses_and_tests_profiles_*.csv 2>/dev/null | head -1)
IS_FIRST_RUN=false
[ -z "$EXISTING_PARAMS_FILE" ] && IS_FIRST_RUN=true

if [ -n "$INPUT_FILE_ARG" ]; then
  ### -i specified ====
  INPUT_FILE="$(cd "$(dirname "$INPUT_FILE_ARG")" && pwd)/$(basename "$INPUT_FILE_ARG")"
  if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error: specified input file not found: $INPUT_FILE${NC}" | tee -a "$LOG_FILE"
    exit 1
  fi
  echo -e "${BLUE}Input file (specified): $INPUT_FILE${NC}"

  if $IS_FIRST_RUN; then
    # First run — copy straight into params/
    cp "$INPUT_FILE" "$PARAMS_RUN_DIR/"
    echo -e "${BLUE}Params saved to: $PARAMS_RUN_DIR/$(basename "$INPUT_FILE")${NC}"
  else
    # Resuming — check if the specified file differs from what is already in params/
    EXISTING_BASENAME=$(basename "$EXISTING_PARAMS_FILE")
    SPECIFIED_BASENAME=$(basename "$INPUT_FILE")
    if [ "$EXISTING_BASENAME" != "$SPECIFIED_BASENAME" ]; then
      echo -e "${YELLOW}Warning: params/ already contains a different profiles file.${NC}"
      echo -e "${YELLOW}  Current  : $EXISTING_BASENAME${NC}"
      echo -e "${YELLOW}  Specified: $SPECIFIED_BASENAME${NC}"
      read -r -p "Replace it? [y/N]: " CONFIRM
      if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        cp "$INPUT_FILE" "$PARAMS_RUN_DIR/"
        echo -e "${BLUE}Params updated to: $SPECIFIED_BASENAME${NC}"
        echo "Input file replaced: $INPUT_FILE" >> "$LOG_FILE"
      else
        echo -e "${BLUE}Keeping existing params file: $EXISTING_BASENAME${NC}"
        INPUT_FILE="$EXISTING_PARAMS_FILE"
        echo "Input file (kept existing): $INPUT_FILE" >> "$LOG_FILE"
      fi
    else
      # Same filename — copy silently to refresh
      cp "$INPUT_FILE" "$PARAMS_RUN_DIR/"
      echo -e "${BLUE}Input file (specified, same as existing): $SPECIFIED_BASENAME${NC}"
    fi
  fi

else
  ### No -i specified ====
  if $IS_FIRST_RUN; then
    # First run — use the newest file in external-params/
    INPUT_FILE=$(ls -t "$PARAMS_DIR"/diagnoses_and_tests_profiles_*.csv 2>/dev/null | head -1)
    if [ -z "$INPUT_FILE" ]; then
      echo -e "${RED}Error: no input file found in $PARAMS_DIR${NC}" | tee -a "$LOG_FILE"
      echo -e "${RED}Expected: diagnoses_and_tests_profiles_{timestamp}.csv${NC}"
      echo -e "${YELLOW}Tip: use -i to specify a file path directly${NC}"
      exit 1
    fi
    echo -e "${BLUE}Input file (newest in external-params/): $INPUT_FILE${NC}"
    cp "$INPUT_FILE" "$PARAMS_RUN_DIR/"
    echo -e "${BLUE}Params saved to: $PARAMS_RUN_DIR/$(basename "$INPUT_FILE")${NC}"
  else
    # Resuming — use whatever is already in params/
    INPUT_FILE="$EXISTING_PARAMS_FILE"
    echo -e "${BLUE}Input file (resuming from params/): $(basename "$INPUT_FILE")${NC}"
  fi
fi

echo "Input file: $INPUT_FILE" >> "$LOG_FILE"




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## --generate ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if $DO_GENERATE; then
  echo -e "${YELLOW}Running yaml generation...${NC}"

  Rscript --vanilla "$GENERATE_SCRIPT" \
    --input    "$INPUT_FILE" \
    --output   "$WORK_DIR" \
    --name     "$PHENOTYPE_NAME" \
    --codebase "$CODEBASE" \
    2>&1 | tee -a "$LOG_FILE"

  EXIT_CODE=${PIPESTATUS[0]}
  if [ $EXIT_CODE -ne 0 ]; then
    echo -e "${RED}--generate failed — see log: $LOG_FILE${NC}"
    exit 1
  fi

  echo -e "${GREEN}--generate complete. Yaml written to: $WORK_DIR${NC}"
fi




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## --apply ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if $DO_APPLY; then

  ### Resolve yaml ====
  if [ -n "$YAML_FILE_ARG" ]; then
    YAML_FILE="$(cd "$(dirname "$YAML_FILE_ARG")" && pwd)/$(basename "$YAML_FILE_ARG")"
    if [ ! -f "$YAML_FILE" ]; then
      echo -e "${RED}Error: specified yaml not found: $YAML_FILE${NC}" | tee -a "$LOG_FILE"
      exit 1
    fi
    echo -e "${BLUE}Yaml (specified): $YAML_FILE${NC}"
  else
    YAML_FILE=$(ls -t "$WORK_DIR"/*.yaml 2>/dev/null | head -1)
    if [ -z "$YAML_FILE" ]; then
      echo -e "${RED}Error: no yaml found in $WORK_DIR${NC}" | tee -a "$LOG_FILE"
      echo -e "${YELLOW}Tip: run --generate first, or use -y to specify a yaml file${NC}"
      exit 1
    fi
    echo -e "${BLUE}Yaml (newest in work/): $YAML_FILE${NC}"
  fi

  echo "Yaml file: $YAML_FILE" >> "$LOG_FILE"

  ### Copy params csv into work/ as the clean starting point ====
  WORK_INPUT="$WORK_DIR/$(basename "$INPUT_FILE")"
  cp "$PARAMS_RUN_DIR/$(basename "$INPUT_FILE")" "$WORK_INPUT"

  echo -e "${YELLOW}Applying phenotype groupings...${NC}"

  Rscript --vanilla "$APPLY_SCRIPT" \
    --input    "$WORK_INPUT" \
    --yaml     "$YAML_FILE" \
    --output   "$WORK_DIR" \
    --codebase "$CODEBASE" \
    2>&1 | tee -a "$LOG_FILE"

  EXIT_CODE=${PIPESTATUS[0]}
  if [ $EXIT_CODE -ne 0 ]; then
    echo -e "${RED}--apply failed — see log: $LOG_FILE${NC}"
    exit 1
  fi

  echo -e "${GREEN}--apply complete. Output written to: $WORK_DIR${NC}"
fi




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## --finalise ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if $DO_FINALISE; then

  ### Resolve yaml (same logic as --apply) ====
  if [ -n "$YAML_FILE_ARG" ]; then
    YAML_FILE="$(cd "$(dirname "$YAML_FILE_ARG")" && pwd)/$(basename "$YAML_FILE_ARG")"
    if [ ! -f "$YAML_FILE" ]; then
      echo -e "${RED}Error: specified yaml not found: $YAML_FILE${NC}" | tee -a "$LOG_FILE"
      exit 1
    fi
  else
    YAML_FILE=$(ls -t "$WORK_DIR"/*.yaml 2>/dev/null | head -1)
    if [ -z "$YAML_FILE" ]; then
      echo -e "${RED}Error: no yaml found in $WORK_DIR — cannot finalise${NC}" | tee -a "$LOG_FILE"
      echo -e "${YELLOW}Tip: run --generate or --apply first${NC}"
      exit 1
    fi
  fi

  ### Apply one final time from the clean params csv ====
  echo -e "${YELLOW}Finalising: applying yaml to original profiles csv...${NC}"
  WORK_INPUT="$WORK_DIR/$(basename "$INPUT_FILE")"
  cp "$PARAMS_RUN_DIR/$(basename "$INPUT_FILE")" "$WORK_INPUT"

  Rscript --vanilla "$APPLY_SCRIPT" \
    --input    "$WORK_INPUT" \
    --yaml     "$YAML_FILE" \
    --output   "$WORK_DIR" \
    --codebase "$CODEBASE" \
    2>&1 | tee -a "$LOG_FILE"

  EXIT_CODE=${PIPESTATUS[0]}
  if [ $EXIT_CODE -ne 0 ]; then
    echo -e "${RED}--finalise failed during apply — see log: $LOG_FILE${NC}"
    exit 1
  fi

  ### Copy yaml and output profiles csv to output/ ====
  FINALISE_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  FINAL_YAML="$OUTPUT_DIR/gwas-grouped-phenotypes-${FINALISE_TIMESTAMP}.yaml"
  FINAL_PROFILES="$OUTPUT_DIR/diagnoses_and_tests_profiles_with_phenotypes-${FINALISE_TIMESTAMP}.csv"

  cp "$YAML_FILE" "$FINAL_YAML"
  cp "$WORK_DIR/diagnoses_and_tests_profiles_with_phenotypes.csv" "$FINAL_PROFILES"

  echo "Finalised yaml   : $FINAL_YAML"    >> "$LOG_FILE"
  echo "Finalised profiles: $FINAL_PROFILES" >> "$LOG_FILE"

  echo -e "${GREEN}--finalise complete.${NC}"
  echo -e "${GREEN}  Yaml    : $FINAL_YAML${NC}"
  echo -e "${GREEN}  Profiles: $FINAL_PROFILES${NC}"
fi




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Done ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "${GREEN}Done. Log: $LOG_FILE${NC}"