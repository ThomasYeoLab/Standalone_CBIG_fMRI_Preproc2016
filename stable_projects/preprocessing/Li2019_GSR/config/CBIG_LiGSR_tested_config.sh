#! /bin/sh
# Last successfully run on Dec. 7, 2018
# Written by CBIG under MIT license: https://github.com/ThomasYeoLab/CBIG/blob/master/LICENSE.md

# DO NOT CHANGE: This clears old freesurfer variables if they previously exists
if [ -n "$FREESURFER_HOME" ]; then
	$FREESURFER_HOME/bin/clear_fs_env.csh 
fi

# PLEASE CHANGE: Please specify location of CBIG repository
export CBIG_CODE_DIR=/data/users/jingweil/storage/CBIG_private

# PLEASE CHANGE: define locations for these libraries
export FREESURFER_HOME=/apps/arch/Linux_x86_64/freesurfer/5.3.0
export CBIG_MATLAB_DIR=/apps/arch/Linux_x86_64/matlab/R2014a
export CBIG_SPM_DIR=/apps/arch/Linux_x86_64/spm/spm12
export CBIG_AFNI_DIR=/apps/arch/Linux_x86_64/afni/20150126/linux_openmp_64
export CBIG_ANTS_DIR=/apps/arch/Linux_x86_64/ants/ants_v2.2.0/BUILD/bin/
export CBIG_WB_DIR=/apps/arch/Linux_x86_64/HCP/workbench/
export CBIG_CARET_DIR=/apps/arch/Linux_x86_64/caret/
export CBIG_FSLDIR=/apps/arch/Linux_x86_64/fsl/5.0.8

# DO NOT CHANGE: set up your environment with the configurations above
SETUP_PATH=$CBIG_CODE_DIR/setup/CBIG_generic_setup.sh
source $SETUP_PATH

# DO NOT CHANGE: set up temporary directory for MRIread from FS6.0
export TMPDIR=/tmpstore

# Do NOT CHANGE: set up MATLABPATH so that MATLAB can find startup.m in our repo 
export MATLABPATH=$CBIG_CODE_DIR/setup

# specified the default Python environment.
# Please UNCOMMENT if you follow CBIG's set up for Python environments.
# We use Python version 3.5 as default.
# Please see $CBIG_CODE_DIR/setup/python_env_setup/README.md for more details.
# source activate CBIG_py3
