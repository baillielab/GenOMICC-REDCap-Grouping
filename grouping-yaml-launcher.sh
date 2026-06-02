#!/bin/bash

# =============================================================================
# grouping-yaml-launcher.sh
# Launcher for the phenotype grouping YAML generation workflow
# Running this script will create a yaml file with GWAS phenotype groups based on the 
# phenotype columns (column 7 onwards) present in the input .csv file
# The yaml file will be created in genomicc-redcap-grouping/runs/{timestamp_of_run}/output/
#
# Usage:
#   ./grouping-yaml-launcher.sh                        # uses newest input file
#   ./grouping-yaml-launcher.sh -i path/to/file.csv   # specify input file
#   ./grouping-yaml-launcher.sh --help                 # show usage
# =============================================================================




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Console Text Colours ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Paths ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEBASE="$REPO_ROOT/codebase"
R_SCRIPT="$CODEBASE/scripts/generate-grouping-yaml.R"
PARAMS_DIR="$CODEBASE/external-params"
RUNS_DIR="$REPO_ROOT/runs"




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Usage ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
usage() {
  echo ""
  echo "Usage: ./grouping-yaml-launcher.sh [-i <input_file>] [--help]"
  echo ""
  echo "Options:"
  echo "  -i, --input <path>   Path to input CSV file"
  echo "                       Default: newest diagnoses_and_tests_profiles_*.csv"
  echo "                       in codebase/external-params/"
  echo "  -h, --help           Show this help message"
  echo ""
  echo "Examples:"
  echo "  ./grouping-yaml-launcher.sh"
  echo "  ./grouping-yaml-launcher.sh -i codebase/external-params/diagnoses_and_tests_profiles_20260601.csv"
  echo ""
}




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Parse flags ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
INPUT_FILE_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--input)
      INPUT_FILE_ARG="$2"
      shift 2
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
## Checks ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

### R ====
if ! command -v Rscript &> /dev/null; then
  echo -e "${RED}Error: Rscript not found. Please install R from https://cran.r-project.org${NC}"
  exit 1
fi
echo -e "${GREEN}Using R: $(Rscript --version 2>&1)${NC}"

### R Packages ====
# Install if not
echo -e "${YELLOW}Checking R packages...${NC}"
Rscript --vanilla -e "
  pkgs <- c('dplyr', 'yaml', 'readr')
  missing <- pkgs[!pkgs %in% installed.packages()[,'Package']]
  if (length(missing) > 0) {
    message('Installing missing packages: ', paste(missing, collapse = ', '))
    install.packages(missing, repos = 'https://cloud.r-project.org', quiet = TRUE)
  } else {
    message('All packages present.')
  }
"

### Input file ====
if [ -n "$INPUT_FILE_ARG" ]; then
  # Resolve relative to wherever the user called from
  INPUT_FILE="$(cd "$(dirname "$INPUT_FILE_ARG")" && pwd)/$(basename "$INPUT_FILE_ARG")"
  if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error: Specified input file not found: $INPUT_FILE${NC}"
    exit 1
  fi
  echo -e "${BLUE}Input file (specified): $INPUT_FILE${NC}"
else
  INPUT_FILE=$(ls -t "$PARAMS_DIR"/diagnoses_and_tests_profiles_*.csv 2>/dev/null | head -1)
  if [ -z "$INPUT_FILE" ]; then
    echo -e "${RED}Error: No input file found in $PARAMS_DIR${NC}"
    echo -e "${RED}Expected: diagnoses_and_tests_profiles_{run_timestamp}.csv${NC}"
    echo -e "${YELLOW}Tip: use -i to specify a file path directly${NC}"
    exit 1
  fi
  echo -e "${BLUE}Input file (newest): $INPUT_FILE${NC}"
fi




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Pre-run Actions ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

### Run dir creation ====
RUN_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RUN_DIR="$RUNS_DIR/genomicc-redcap-grouping_${RUN_TIMESTAMP}"
mkdir -p "$RUN_DIR/params" "$RUN_DIR/logs" "$RUN_DIR/output"

### Copy Input File into Run params ====
cp "$INPUT_FILE" "$RUN_DIR/params/"
echo -e "${BLUE}Params copied to: $RUN_DIR/params/${NC}"

### Record git commit ====
if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
  git -C "$REPO_ROOT" describe --tags --always --dirty > "$RUN_DIR/git_commit.txt" 2>/dev/null \
    || git -C "$REPO_ROOT" rev-parse HEAD > "$RUN_DIR/git_commit.txt"
  echo -e "${BLUE}Git commit: $(cat "$RUN_DIR/git_commit.txt")${NC}"
else
  echo "git not available" > "$RUN_DIR/git_commit.txt"
  echo -e "${YELLOW}Warning: not a git repository — commit not recorded${NC}"
fi




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Run R Script ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
LOG_FILE="$RUN_DIR/logs/generate-grouping-yaml-${RUN_TIMESTAMP}.log"
echo -e "${YELLOW}Running YAML generation...${NC}"

Rscript --vanilla "$R_SCRIPT" \
  --input    "$INPUT_FILE" \
  --output   "$RUN_DIR/output" \
  --codebase "$CODEBASE" \
  2>&1 | tee "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}Done!${NC}"
  echo -e "${GREEN}Output : $RUN_DIR/output${NC}"
  echo -e "${GREEN}Log    : $LOG_FILE${NC}"
else
  echo -e "${RED}Something went wrong — see log: $LOG_FILE${NC}"
  exit 1
fi