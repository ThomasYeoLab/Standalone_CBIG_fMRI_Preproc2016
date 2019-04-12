#!/bin/csh
# Written by Jingwei Li and CBIG under MIT license: https://github.com/ThomasYeoLab/CBIG/blob/master/LICENSE.md

set outdir = $1   # Your output directory
set fmrinii_dir = "/mnt/eql/yeo1/CBIG_private_data/unit_tests/stable_projects/preprocessing"
set fmrinii_dir = "$fmrinii_dir/CBIG_fMRI_Preproc2016/single_subject/scripts/fmrinii"
set config_file = "$CBIG_CODE_DIR/stable_projects/preprocessing/CBIG_fMRI_Preproc2016"
set config_file = "$config_file/unit_tests/single_subject/prepro.config"
set anat_dir = "/share/users/imganalysis/yeolab/data/GSP_release"

set curr_sub = "Sub1116_Ses1"

set curr_dir = `pwd`
set username = `whoami`
set work_dir = /data/users/$username/cluster/ 

echo $curr_dir
echo $username
echo $work_dir

if (! -e $work_dir) then
        mkdir -p $work_dir
endif

cd $work_dir


set cmd = "CBIG_preproc_fMRI_preprocess.csh -s $curr_sub -output_d $outdir -anat_s ${curr_sub}_FS -anat_d"
set cmd = "$cmd ${anat_dir} -fmrinii ${fmrinii_dir}/$curr_sub.fmrinii -config ${config_file} -nocleanup"
echo $cmd | qsub -V -q circ-spool -l walltime=1:00:00,mem=6GB -m ae -N CBIG_preproc_unit_tests_call_fMRI_preproc
