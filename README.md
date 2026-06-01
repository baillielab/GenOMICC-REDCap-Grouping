# ODAP REDCap GWAS Phenotype Grouping

R-based workflow that facilitates GWAS phenotype grouping.

## Input file
The genomicc-redcap-cleaning pipeline in ODAP cleans free text entries in multiple diagnosis and tests fields. This process is ongoing, so output files contain a mixture of cleaned and yet-to-be-cleaned diagnoses/tests.

At each pipeline run a `diagnoses_and_tests_profiles_{timestamp}.csv` file is produced. Individual level data are grouped down to numbered profiles that have identical:
- prim_diagnosis_odap
- assay_type(s)
- organism(s)
- assay_delta(s)
A profile with one prim_diagnosis_odap and multiple tests / deltas will be spread over multiple rows. Each profile node is numbered (profile_number). The numbers are arbitrary and serve only to indicate profiles spread over multiple rows.

The assay_delta is the difference between admission date and date of the test. This number can be positive or negative, and is filtered to remove obvious errors (e.g. only values -10 to +10 are retained).

**NOTE:** For this first run, the input will be profiles file without further phenotypes definitions columns. I'll add some code to build in adding the previously defined phenotypes once we've gone through this process once.

## Defining a new GWAS phenotype group
To define a new GWAS phenotype group:
1. Open `genomicc-redcap-grouping/codebase/external-params/diagnoses_and_tests_profiles_{timestamp}.csv` (from now on referred to as **the profiles file**)
  - You can either work on this file directly or save a copy to your chosen location
  - In the future I will lock this file to read only but for now whilst we do a first run-through I will leave it as rwx for all
2. Find the first available empty column to the right of the profiles file you are working on
3. Add your phenotype name as a column heading. Please use lowercase and `_` instead of spaces
  - Please ensure your phenotype name is not already being used by other phenotypes columns
4. In this new phenotype column add text into each row that you want to include in this phenotype grouping
  - It doesn't matter what type of text you enter into the selected cells, as long as you are consistent across the entire column
  - Please leave unselected cells blank
5. Continue to define as many phenotypes as you want, each in its own new column
6. Once done, save the file and move on to generating the yaml (see below)


## Generating phenotype grouping yaml

### First time setup: adding R to your PATH

First check if R is already on your PATH — open Terminal and run:
```bash
which Rscript
```
If a path is returned and you are happy with this version of R, you're done.

If nothing is returned, find your R installation:
```bash
find /Library /usr/local /opt/homebrew -name "Rscript" 2>/dev/null
```

Copy the directory part of the path returned (everything except `/Rscript` at the end),
then add it to your shell profile:
```bash
echo 'export PATH="/your/path/here:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

For example, for a standard CRAN installation this would be:
```bash
echo 'export PATH="/Library/Frameworks/R.framework/Resources/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

You only need to do this once.

If you are not sure which shell you have, run `echo $SHELL`:
- If this returns `zsh` then use `~/.zshrc`
- If this returns `bash` then use `~/.bash_profile`


### Run the launcher script
The yaml file of all defined GWAS grouping phenotypes is generated with a set of R scripts in `genomicc-redcap-grouping/codebase/scripts`. To generate the yaml you only need to:
1. Open terminal / gitbash
2. Navigate to the `genomicc-redcap-grouping` directory
3. Run the launcher:
```bash
# To use the newest profiles file in /external-params:
./grouping-yaml-launcher.sh

# To specify your own input file:
./grouping-yaml-launcher.sh -i path/to/file.csv

# To show (the currently very limited) usage:
./grouping-yaml-launcher.sh --help
```
4. Each run creates a timestamped directory in the `genomicc-redcap-grouping/runs` directory, with:
  - `logs`
  - `output` ==> `gwas-grouped-phenotypes-{timestamp}.yaml`
  - `params` ==> a copy of the **profiles file** that was used to create the yaml (either the file you specified with -i or the most recent profiles file in external-params)
  - git_commit.txt ==> git version of the repo in use at the time of run
5. You can run this as many times as you like; each run will produce a new set of output files

Please note that this work is still under development; reports of errors etc. would be gratefully received.

## Repo Architecture
```
genomicc-redcap-grouping/                          # Git repository root
│
├── grouping-yaml-launcher.sh                      # Run from terminal to generate grouping yaml from profiles csv file
├── genomicc-redcap-grouping.Rproj
├── .git
├── .gitignore
│
├── codebase/                             # Versioned codebase
│   │  
│   ├── external_params/                  # Input file(s) for grouping; output of cleaning pipeline       
│   │   └── diagnoses_and_tests_profiles_{run_timestamp}.csv
│   │   
│   ├── scripts/                      
│   │   ├── functions.R                
│   │   └── generate-grouping-yaml.R
│   │    
│   ├── shared_utilities/
│   │   ├── dev_bootstrap.R                # Boostrap script for interactive dev
│   │   ├── shared.env                     # Base dir paths
│   │   ├── shared-odap.env               # Base dir paths: ODAP
│   │   └── shared-params.R               # Libraries
│   │   
│   └── work/                      
│       └── ...                           # Output files generated
│
└── runs/                                 # Not versioned
    │
    ├── genommic-redcap-grouping_20260430_114647/            # Run dir [YYYYMMDD_HHMMSS]
    │   ├── params/                       # Params input file copied in by run script to keep record specific to each run
    │   │   └── diagnoses_and_tests_profiles_{run_timestamp}.csv
    │   │
    │   ├── logs/
    │   │   └── generate-grouping-yaml-{run_timestamp}.log
    │   │
    │   ├── output/
    │   │   └── gwas-grouped-phenotypes-{run_timestamp}.csv
    │   │
    │   └── git_commit.txt                  # Version of pipeline used in run; will show e.g. v1.0.0-dirty if ran with uncommitted 
    │

```