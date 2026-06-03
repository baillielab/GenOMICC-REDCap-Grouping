# ODAP REDCap GWAS Phenotype Grouping

R-based workflow that facilitates GWAS phenotype grouping.

## yaml logic
- Arbirary example yaml:
```
phenotype_groups:
- phenotype_column: test_pheno
  phenotype_label: test
  profiles:
  - prim_diagnosis_odap: COVID-19
    assays:
    - assay_type: throatnose_swab
      organism: COVID-19
      assay_delta: -1
    - assay_type: blood_culture
      organism: COVID-19
      assay_delta: ~
  - prim_diagnosis_odap: Acute pneumonia complicating confirmed infection with influenza
      virus
    assays:
    - assay_type: blood_culture
      organism: COVID-19
      assay_delta: ~
  - prim_diagnosis_odap: Preterm birth < 32 weeks postmenstrual age
    assays: ~

```
- One GWAS phenotype group per yaml for the development phase (individual yamls will be combined programatically in ODAP for application to the individual-level data)
- Profiles that fit any of the first-level conditions (e.g. prim_diagnosis_odap + assays) will be assigned to the group
  - In the arbitrary example above, profiles that fit any of the three conditions will be assigned to the test_pheno group

| yaml value | Meaning | Behaviour |
| ------ | ------ | ------ |
|   ~     |   field is absent/unknown    |    only matches rows where that column is `NA`    |
|    `ANY`    |        |    matches any row regardless of value    |
|    assay_delta: 4    |   specific value     |    exact match only    |


- When an assay delta is not specified (~), any value for delta will result in inclusion into the group
  - In the arbitrary example yaml above that would mean any profile with `prim_diagnosis_odap == Acute pneumonia complicating confirmed infection with influenza virus` and a `blood_culture` assay detecting `COVID-19` for any `assay_delta`
- When an assay delta is specified, only profiles with an exact match to all the elements of the condition will be included

## Iterative Workflow
The purpose of this workflow is to generate a yaml file that specifies the patient profiles that belong to a GWAS phenotype grouping. The individual phenotype yaml files are combined into a single phenotype specification yaml within ODAP and applied to individual level data as part of the covariates generation pipeline. Participants can belong to multiple GWAS phenotype groupings.

The workflow allows two methods of generating the GWAS phenotype defining yaml file. These methods can be used separately or in combination; see below for details.
**NOTE**
For help and information on flags, run:
```
./gwas-phenotype-grouping-launcher.sh --help
```

The intention of this workflow is that iterative work is done in a genomicc-redcap-grouping/runs/genomicc-redcap-grouping_{phenotype_name}/work directory. The launcher will copy the profiles csv file from external-params into the work directory, and expects to find a phenotypes yaml in the work directory


### 1. Specifying the yaml directly
A user can directly specify the parameters in a yaml file by manual editing. 
Steps:
1. Create the run directory with a dry run:
```
./gwas-phenotype-grouping-launcher.sh -n <name> --dry-run
```
This will:
- Create the run directory in the format: `genomicc-redcap-grouping/runs/genomicc-redcap-grouping_<name>`
- Copy the most recent profiles file from `genomicc-redcap-grouping/codebase/external-params` to `genomicc-redcap-grouping/runs/genomicc-redcap-grouping_<name>/params`
- Check for R and R packages
- Create a log entry

2. Create a yaml manually
- Copy one of the current working library of yamls from `genomicc-redcap-grouping/codebase/yaml-library` to `genomicc-redcap-grouping/runs/genomicc-redcap-grouping_<name>/work`
- Rename this yaml <name>-groups.yaml
- Make your edits and save

3. To see what effect applying the GWAS phenotype grouping yaml has, it can be applied to the profiles file with:
```
./gwas-phenotype-grouping-launcher.sh -n <name> --apply
```
- Where <name> is the name of the GWAS phenotype grouping
- Use quotation marks around the name if the name contains spaces or non-standard characters
- Optional: Specify the yaml file with option -y (call --help for details). If not specified, the most recent yaml in `genomicc-redcap-grouping/runs/genomicc-redcap-grouping_<name>/work/` will be used.
- This command applies the grouping logic to the profiles file in work and creates a new file `work/diagnoses_and_tests_profiles_with_phenotypes.csv`.
  - A new column is added to the end of the file, named with the text entered for phenotype_column in the yaml
  - The contents of the phenotype column, where a profile meets the yaml classification conditions set in the yaml, is set by phenotype_label
  - A column is created to the right of the phenotype column, called {phenotype_column}_total_px
    - This column reports the total number of patients in the profiles file that meet the requirements for inclusion into the GWAS phenotype group
    - The number is repeated next to every qualifying profile for ease of reading


### 2. Programmatically generating the yaml
A user can programatically generate a grouping yaml file by manually adding a column to the profiles csv file.
Steps:
1. Create the run directory with a dry run:
```
./gwas-phenotype-grouping-launcher.sh -n <name> --dry-run
```
This will:
- Create the run directory in the format: `genomicc-redcap-grouping/runs/genomicc-redcap-grouping_<name>`
- Copy the most recent profiles file from `genomicc-redcap-grouping/codebase/external-params` to `genomicc-redcap-grouping/runs/genomicc-redcap-grouping_<name>/params`
- Check for R and R packages
- Create a log entry

2. Add your <name> value to the first row of the first available column in the  `genomicc-redcap-grouping/runs/genomicc-redcap-grouping_<name>/diagnoses_and_tests_profiles_2{timestamp}.csv` file.

3. Add consistent values in the newly created <name> column in the `genomicc-redcap-grouping/runs/genomicc-redcap-grouping_<name>/diagnoses_and_tests_profiles_2{timestamp}.csv` file for every profile that meets the conditions for inclusion into the GWAS phenotype group you are creating.

4. Save the file.

5. Generate the yaml:
```
./gwas-phenotype-grouping-launcher.sh -n <name> --generate
```
- Where <name> is the name of the GWAS phenotype grouping
- Use quotation marks around the name if the name contains spaces or non-standard characters
- Optional: Specify the input file with option -i (call --help for details). If not specified, the most recent profiles csv file in `genomicc-redcap-grouping/runs/genomicc-redcap-grouping_<name>/work/` will be used.

6. To see what effect applying the GWAS phenotype grouping yaml has, it can be applied to the profiles file with:
```
./gwas-phenotype-grouping-launcher.sh -n <name> --apply
```
- Where <name> is the name of the GWAS phenotype grouping
- Use quotation marks around the name if the name contains spaces or non-standard characters
- Optional: Specify the yaml file with option -y (call --help for details). If not specified, the most recent yaml in `genomicc-redcap-grouping/runs/genomicc-redcap-grouping_<name>/work/` will be used.
- This command applies the grouping logic to the profiles file in work and creates a new file `work/diagnoses_and_tests_profiles_with_phenotypes.csv`.
  - A new column is added to the end of the file, named with the text entered for phenotype_column in the yaml
  - The contents of the phenotype column, where a profile meets the yaml classification conditions set in the yaml, is set by phenotype_label
  - A column is created to the right of the phenotype column, called {phenotype_column}_total_px
    - This column reports the total number of patients in the profiles file that meet the requirements for inclusion into the GWAS phenotype group
    - The number is repeated next to every qualifying profile for ease of reading

### 3. Options 1 and 2 in combination
Options 1 and 2 can also be used in combination to generate a grouping yaml. For a description, run:
```
./gwas-phenotype-grouping-launcher.sh --help
```

## Final output
Once you are happy with your yaml you can finalise the output with:
```
./gwas-phenotype-grouping-launcher.sh -n <name> --finalise
```
- Where <name> is the name of the GWAS phenotype grouping
- This will copy the profiles and yaml files in `work` into `output` as `diagnoses_and_tests_profiles_with_phenotypes_<name>-{timestamp}.csv` and `<name>_gwas_grouped_phenotypes-{timestamp}.yaml`


## Repo Architecture
```
genomicc-redcap-grouping/                          # Git repository root
│
├── gwas-phenotype-grouping-launcher.sh            # Main running script; see help for details
├── genomicc-redcap-grouping.Rproj
├── .git
├── .gitignore
├── README.md
│
├── codebase/                             # Versioned codebase
│   │  
│   ├── external_params/                  
│   │   └── diagnoses_and_tests_profiles_{run_timestamp}.csv      # Input file(s) for grouping; output of cleaning pipeline. Only shared via email
│   │   
│   ├── scripts/                      
│   │   ├── functions.R
│   │   ├── apply-grouping-yaml.R         # Apply a yaml to a profiles file; one phenotype at a time                   
│   │   └── generate-grouping-yaml.R      # Generate a yaml from an edited profiles file; one phenotype at a time
│   │    
│   ├── shared_utilities/
│   │   └── shared-params.R
│   │    
│   └── yaml-library/                   # The existing finalised yaml library; one file per GWAS phenotype grouping
│       ├── ...
│
└── runs/                                 # Not versioned
    │
    ├── genommic-redcap-grouping_{phenotype_name}/            # Run dir per phenotype
    │   │
    │   ├── params/                       
    │   │   └── diagnoses_and_tests_profiles_{run_timestamp}.csv  # Copied in from external_params once when run is started
    │   │
    │   ├── work/
    │   │   ├── gwas-grouped-phenotypes.yaml                      # editable, overwritten each iteration                     
    │   │   └── diagnoses_and_tests_profiles_with_phenotypes.csv  # editable, overwritten each iteration
    │   │ 
    │   ├── logs/
    │   │   └── gwas-phenotype-grouping.log          # All activity across iterations appended with timestamps
    │   │
    │   ├── output/           # populated only on running with --finalise
    │   │   ├── <name>_gwas_grouped_phenotypes-{timestamp}.yaml                    
    │   │   └── diagnoses_and_tests_profiles_with_phenotypes_<name>-{timestamp}.csv
    │   │
    │   └── git_commit.txt                  # Version of pipeline used in run; will show e.g. v1.0.0-dirty if ran with uncommitted 
    │

```