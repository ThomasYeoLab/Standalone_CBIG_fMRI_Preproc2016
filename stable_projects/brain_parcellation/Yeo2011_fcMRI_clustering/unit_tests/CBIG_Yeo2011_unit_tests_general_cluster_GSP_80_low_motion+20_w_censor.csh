#!/bin/csh -f
# Written by Jingwei Li and CBIG under MIT license: https://github.com/ThomasYeoLab/CBIG/blob/master/LICENSE.md

set your_out_dir = $1
set data_dir = "/mnt/eql/yeo1/CBIG_private_unit_tests_data/stable_projects/preprocessing/CBIG_fMRI_Preproc2016/100subjects_clustering"
set subject_dir = "${data_dir}/preproc_out"
set subject_list = "$CBIG_CODE_DIR/stable_projects/preprocessing/CBIG_fMRI_Preproc2016/unit_tests/100subjects_clustering/GSP_80_low_motion+20_w_censor.txt"

# create fake dir for each subject in your data dir, and make symbolic links to original data dir
set your_subject_dir = "${your_out_dir}/preproc_out"
foreach s (`cat $subject_list`)
	mkdir -p ${your_subject_dir}/$s
	ln -s ${subject_dir}/$s/surf ${your_subject_dir}/$s/
	ln -s ${subject_dir}/$s/logs ${your_subject_dir}/$s/
	ln -s ${subject_dir}/$s/qc ${your_subject_dir}/$s/
	ln -s ${subject_dir}/$s/bold ${your_subject_dir}/$s/
end

set out_dir = "${your_out_dir}/clustering"
set code_dir = "${CBIG_CODE_DIR}/stable_projects/brain_parcellation/Yeo2011_fcMRI_clustering"
set num_clusters = 17
set formated_cluster = `echo $num_clusters | awk '{printf ("%03d", $1)}'`
set scrub_flag = 1   # 1 for scrub, 0 for not scrub

set surf_stem = "_rest_skip4_stc_mc_residc_interp_FDRMS0.2_DVARS50_bp_0.009_0.08_fs6_sm6_fs5"
set outlier_stem = "_FDRMS0.2_DVARS50_motion_outliers"

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


if( $scrub_flag == 1 ) then
	echo "cd ${curr_dir}; ${code_dir}/CBIG_Yeo2011_general_cluster_fcMRI_surf2surf_profiles.csh -sd ${your_subject_dir} -sub_ls ${subject_list} -surf_stem ${surf_stem} -n ${num_clusters} -out_dir ${out_dir} -cluster_out ${out_dir}/GSP_80_low_mt_20_w_censor_clusters${formated_cluster}_scrub -tries 1000 -outlier_stem ${outlier_stem}" | qsub -V -q circ-spool -l walltime=20:00:00,mem=2GB

else
	echo "cd ${curr_dir}; ${code_dir}/CBIG_Yeo2011_general_cluster_fcMRI_surf2surf_profiles.csh -sd ${your_subject_dir} -sub_ls ${subject_list} -surf_stem ${surf_stem} -n ${num_clusters} -out_dir ${out_dir} -cluster_out ${out_dir}/GSP_80_low_mt_20_w_censor_clusters${formated_cluster}_noscrub -tries 1000 " | qsub -V -q circ-spool -l walltime=20:00:00,mem=2GB
endif



