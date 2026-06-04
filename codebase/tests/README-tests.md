# Test files

To practice using the repo code a synthetic profiles csv file has been placed in `genomicc-redcap-grouping/codebase/tests`. This is a non-exhaustive set of example profiles that can server as a starter for testing the yaml example code in the Grouping_yaml_logic.md file.

Different yaml profiles can be pasted into the example-groups.yaml file.

To practice, do:
1. Create the run directory with a dry run:
```
./gwas-phenotype-grouping-launcher.sh -n tests --dry-run
```
- This will create a new directory: `genomicc-redcap-grouping/runs/genomicc-redcap-grouping_tests`

2. Copy the example yaml and csv files into the run/work directory:
```
cp ./codebase/tests/example* ./runs/genomicc-redcap-grouping_tests/work/
```

3. Manually modify the example-groups.yaml
- Multiple example yaml setups are provided in Grouping_yaml_logic.md in the wiki.

4. Apply the yaml to the example profiles file
```
./gwas-phenotype-grouping-launcher.sh -n tests -i ./runs/genomicc-redcap-grouping_tests/work/example.csv -y ./runs/genomicc-redcap-grouping_tests/work/example-groups.yaml --apply
```
- Choose to replace the profiles file when prompted.

5. Examine results
- Open the `./runs/genomicc-redcap-grouping_tests/work/diagnoses_and_tests_profiles_with_phenotypes.csv` file to see which profiles have been grouped by the example-groups.yaml.
