# Discover cognitive components of self-generated thought

---- 

## Data Release

[MNI152_ActivationCoordinates]('./MNI152_ActivationCoordinates') directory contains activation coordinates of 7 tasks of self-generated thought, which were provided by the following studies:

- Spreng, R.N., Mar, R.A. and Kim, A.S., 2009. The common neural basis of autobiographical memory, prospection, navigation, theory of mind, and the default mode: a quantitative meta-analysis. Journal of Cognitive Neuroscience.
- Mar, R.A., 2011. The neural bases of social cognition and story comprehension. Annual Review of Psychology.
- Sevinc, G. and Spreng, R.N., 2014. Contextual and perceptual brain processes underlying moral cognition: a quantitative meta-analysis of moral reasoning and moral emotions. PloS One.

Please cite the 3 papers above when using the activation coordinates.

---- 

## Reference
Gia H. Ngo, Simon B. Eickhoff, Minh Nguyen, Peter T. Fox,  R. Nathan Spreng, B. T. Thomas Yeo. [Beyond Consensus: Embracing Heterogeneity in Curated Neuroimaging Meta-Analysis](https://www.biorxiv.org/content/early/2017/06/19/149567). BioRxiv preprint

Gia H. Ngo, Simon B. Eickhoff, Peter T. Fox, B. T. Thomas Yeo. [Collapsed variational Bayesian inference of the author-topic model: application to large-scale coordinate-based meta-analysis](https://ieeexplore.ieee.org/document/7552332). PRNI2016.

---

## Setup
Create a new workspace in Bash (please change this to your preferred directory):
```
mkdir /Work/self-generated_thought;
cd /Work/self-generated_thought;
matlab
```

---

## Add paths to functions

```
% add paths to functions specific to author-topic model
CBIG_CODE_DIR = getenv('CBIG_CODE_DIR');
addpath(fullfile(getenv('CBIG_CODE_DIR'), 'stable_projects', 'meta-analysis', 'Ngo2019_AuthorTopic', 'utilities', 'preprocessing'));
addpath(fullfile(getenv('CBIG_CODE_DIR'), 'stable_projects', 'meta-analysis', 'Ngo2019_AuthorTopic', 'utilities', 'inference'));
addpath(fullfile(getenv('CBIG_CODE_DIR'), 'stable_projects', 'meta-analysis', 'Ngo2019_AuthorTopic', 'utilities', 'BIC'));
addpath(fullfile(getenv('CBIG_CODE_DIR'), 'stable_projects', 'meta-analysis', 'Ngo2019_AuthorTopic', 'utilities', 'visualization'));
```

---

## Pre-process MNI152 coordinates of activation foci in raw text input data

The self-generated thought data is saved at `./MNI152_ActivationCoordinates/SelfGeneratedThought_AllCoordinates.txt` in text format. Please see `./MNI152_ActivationCoordinates/README.md` for explanation of the data format.

From Matlab, run the following commands to convert data in the text file to suitable Matlab format for the Collapsed Variational Bayes (CVB) algorithm:
```
textFilePath = fullfile(getenv('CBIG_CODE_DIR'), 'stable_projects', 'meta-analysis', 'Ngo2019_AuthorTopic', 'SelfGeneratedThought', 'MNI152_ActivationCoordinates', 'SelfGeneratedThought_AllCoordinates.txt');
dataDirPath = fullfile(pwd, 'data');
dataFileName = 'SelfGeneratedThought_CVBData.mat';
system(['mkdir -p ' dataDirPath]);

CBIG_AuthorTopic_GenerateCVBDataFromText(textFilePath, dataDirPath, dataFileName);
```

The command above would do the following:
- Save data of the experiments (MNI152 coordinates and task label) at `<dataDirPath>/ExperimentsData.mat`.
- Write the activation foci into brain images under the folder `<dataDirPath>/ActivationVolumes`.
- Perform binary smoothing of the brain images of activation and save the resulting images under `<dataDirPath>/BinarySmoothedVolumes`.
- Combine all smoothed brain images into a brain mask of activation across all experiments and save at `<dataDirPath>/mask/expMask.nii.gz`. This brain mask is necessary for computing Bayesian Information Criterion (BIC) measure of the model estimates.
- Save input data for the CVB algorithm at `<dataDirPath>/dataFileName`, i.e. `<dataDirPath>/SelfGeneratedThought_CVBData.mat`.

---

## Inference
To estimate the model parameters with K = 1 to 4 cognitive components using 1000 random re-initialization for each K, run the following commands:
```
alpha = 100;
eta = 0.01;
doSmoothing = 1;
workDir = pwd;
cvbData = fullfile(dataDirPath, dataFileName);
seeds = 1:1000;

for K = 1:4
  for seed = seeds
    CBIG_AuthorTopic_RunInference(seed, K, alpha, eta, doSmoothing, workDir, cvbData);
  end
end
```
The 1000 estimates from the 1000 re-initializations for each value of K would be stored under `<workDir>/outputs/K<K>`

---


## Get the best model estimates
To get the estimate with the highest variational bound from the 1000 estimates at each K = 1 to 4,  run the following commands in Matlab:
```
outputsDir = fullfile(workDir, 'outputs');

for K = 1:4
  CBIG_AuthorTopic_ComputeBestSolution(outputsDir, K, seeds, alpha, eta);
end

```
The best solutions would be stored under `<workDir>/outputs/bestSolution/BestSolution_K001.mat` to `<workDir>/outputs/bestSolution/BestSolution_K004.mat`

---


## Visualize the cognitive components
To visualize the probability of each component activating the brain voxels (Pr(voxel | component)) on the brain surface for K = 2 components, run the following commands:
```
figuresDir = fullfile(workDir, 'figures');
inputFile = fullfile(workDir, 'outputs', 'bestSolution', 'BestSolution_K002.mat');

CBIG_AuthorTopic_VisualizeComponentsOnBrainSurface(inputFile, figuresDir);
```
This would produce the surface visualization of the K=2 cognitve components from the best estimate produced from the previous steps. The images are saved under `figuresDir`.

---


## Task loading of each cognitive component
The probability of each task recruiting a component (Pr(component | task)) is available in the `theta` matrix of the CVB output.

For example, loading of the 7 self-generated thought tasks for the 2 cognitive components produced by the best estimate of the CVB algorithm is stored in `<workDir>/outputs/bestSolution/K2/alpha100_eta0.01/BestSolution_K002.mat`.

The 7 rows of the `theta` matrix correspond to 7 tasks. The labels of these tasks, in the same order as the rows of `theta`, are saved in `<dataPath>/ExperimentsData.mat`.

---

## Compute Bayesian Information Criterion (BIC)

To compute the BIC measures of the best model parameter estimates for K = 1 to 4, run the following commands:

```
maskPath = fullfile(dataDirPath, 'mask', 'expMask.nii.gz');
bestSolutionDir = fullfile(workDir, 'outputs', 'bestSolution');
bicDir = fullfile(workDir, 'BIC');

CBIG_AuthorTopic_ComputeBIC(1:4, maskPath, bestSolutionDir, bicDir);
```
