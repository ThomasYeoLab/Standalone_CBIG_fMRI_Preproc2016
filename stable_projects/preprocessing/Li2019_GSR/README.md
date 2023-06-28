References
==========
+ Li J, Kong R, Liegeois R, Orban C, Tan Y, Sun N, Holmes AJ, Sabuncu MR, Ge T, Yeo BTT, [**Global signal regression strengthens association between resting-state functional connectivity and behavior**](https://doi.org/10.1016/j.neuroimage.2019.04.016), Neuroimage, 2019, 196:126-141

----

Background
==========
Global signal regression is a controversial preprocessing step for resting-state functional MRI. GSR effectively removes global motion and respiratory artifacts. However, GSR might distort resting-state functional connectivity (RSFC) by introducing negative correlations and removing neural information. The vast majority of studies have focused on the effectiveness of GSR in removing imaging artifacts, and its potential biases. Given growing interest in functional connectivity fingerprinting, here we explored the utilitarian question of whether GSR strengthens or weakens the association between RSFC and various behavioral measures. Two large-scale datasets were involved: the Brain Genomics Superstruct Project (GSP; N=862; 23 behavioral measures) and the Human Connectome Project (HCP; N=953; 58 behavioral measures). Using variance component model and kernel ridge regression, we showed that GSR enhanced the associations between whole-brain RSFC and behaviors as well as the prediction accuracies of many behavioral measures, at least in the case for young healthy subjects. Since GSR was more effective at removing motion-related and respiratory-related artifacts, these improvements were unlikely to be the result of motion-related or respiratory-related artifacts.

----

Code Release
===========
- `VarianceComponentModel/scripts` folder contains the scripts to run variance component model on each dataset separately. Specifically, `CBIG_LiGSR_LME_workflowGSP.sh` and `CBIG_LiGSR_LME_workflowHCP.sh` are the top-level wrappers calling other scripts.

- `KernelRidgeRegression` folder contains the scripts to run kernel ridge regression to predict behavioral measures for each dataset. `KernelRidgeRegression/GSP/scripts/CBIG_LiGSR_KRR_workflowGSP.sh` and `KernelRidgeRegression/HCP/scripts/CBIG_LiGSR_KRR_workflowHCP.sh` are the top-level wrappers.
  - This folder only contains the wrapper scripts. These wrapper scripts call a set of general kernel ridge regression scripts, which can be found [here](https://github.com/ThomasYeoLab/CBIG/blob/master/utilities/matlab/predictive_models/KernelRidgeRegression).

- `LinearRidgeRegression` folder contains the scripts to run linear ridge regression to predict a behavioral measure for each dataset. `LinearRidgeRegression/GSP/scripts/CBIG_LiGSR_LRR_workflowGSP.sh` and `LinearRidgeRegression/HCP/scripts/CBIG_LiGSR_LRR_workflowHCP.sh` are the top-level wrappers.
  - This folder only contains the wrapper scripts. These wrapper scripts call a set of general linear ridge regression scripts, which can be found [here](https://github.com/ThomasYeoLab/CBIG/blob/master/utilities/matlab/predictive_models/LinearRidgeRegression).

- `unit_tests` folder contains the scripts for two types of unit tests: (1) replication of results shown in Li et al. (under review); (2) results of 1 or 2 behavioral measures related to intelligence for each dataset. For the procedures to run the replication tests, refer to `unit_tests/replication/README.md`. For the procedures to run the tests on only the 1 or 2 intelligence measures, refer to `unit_tests/intelligence_score/README.md`.

- `examples` folder contains the scripts and the input/output files of a toy example for each method. Check [this readme file](https://github.com/ThomasYeoLab/CBIG/blob/master/stable_projects/preprocessing/Li2019_GSR/examples/README.md) for more details.

- `config` folder contains the latest configuration files and matlab startup.m that were successfully tested.

### Download stand-alone repository

Since the whole Github repository is too big, we created a stand-alone repository of this Li2019_GSR project containing all of its dependencies. To download this stand-alone repository, visit this link: 

https://github.com/ThomasYeoLab/Standalone_Li2019_GSR


### Download whole repository

If you want to use the code from our lab's other stable projects (other than Li2019_GSR), you would need to download the whole CBIG repository.

To download the latest tested version of the whole repository, you can either

- visit this link: [https://github.com/ThomasYeoLab/CBIG/releases/tag/v0.18.1-Update_stable_project_unit_test](https://github.com/ThomasYeoLab/CBIG/releases/tag/v0.18.1-Update_stable_project_unit_test)

or

- run the following command, if you have Git installed
```
git checkout -b Li2019_GSR v0.18.1-Update_stable_project_unit_test
```

----

Updates
===========

- Release v0.18.1 (20/01/2021):
  1. Update unit test to accommodate to the new HPC.
  
- Release v0.17.0 (19/02/2020): Avoid using absolute paths. Add new environment variables to avoid possible problems caused by hard-coded absolute paths.

- Release v0.15.3 (16/10/2019): Pass `lambda_set` into general KRR code instead of using the default.

- Release v0.13.1 (19/07/2019):
  1. Updated example script and setup file.
  2. Moved locations of some dependencies (general code to estimate variance components).
  3. Included a no-bias flag in the scripts because the general kernel regression code was modified to handle the bias term by default.
  4. Update reference in the readme

- Release v0.9.4 (01/04/2019): 
  1. Added a script to generate the stand-alone repository for this project
  2. Improved some descriptions in the README files
  3. Moved `unit_tests/replication` folder to `replication`
  4. Added an input argument to let users specify the output directory of to save all the outputs from running the scripts in `examples`.
  5. Shortened the runtime of the `intelligence_scores` unit test.
  6. Rename matlab variable `feature` to `feature_mat` to avoid clashing with matlab built-in function.
    
- Release v0.9.0 (13/02/2019): Initial release of Li2019_GSR project.

Bugs and Questions
==========
Please contact Jingwei Li at jingweili.sjtu.nus@gmail.com, Ru Kong at roo.cone@gmail.com and Thomas Yeo at yeoyeo02@gmail.com.
