# genomicc-redcap-grouping/codebase/shared-utilities/shared-params.R
# Shared params for the genomicc-redcap-grouping workflow






#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## LIBRARIES ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
libs_required <- c("rlang",
                   "tidyverse",
                   "yaml")




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## PROFILES FILE FIXED COLS ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Fixed cols present in profiles input file. Any col(s) in addition to these is treated as a phenotype defining col
FIXED_PROFILE_COLS <- c(
                "profile_number",
                "number_px_with_profile", 
                "prim_diagnosis_odap",
                "assay_type",
                "organism",
                "assay_delta")