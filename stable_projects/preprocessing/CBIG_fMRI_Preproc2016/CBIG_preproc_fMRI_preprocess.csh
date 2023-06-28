#! /bin/csh -f
##########################################
# CBIG fMRI Preprocess
##########################################
# AUTHOR #################################
# RU(BY) KONG 
# 2016/06/09  
##########################################
##########################################
# In this script, we
# 1) Read in the configuration file to set the preprocess order
# 2) Obtain BOLD information from the fMRI nifti file list
# 3) Loop through the preprocess step
# 4) Preprocessed results will be saved in output directory
##########################################
# Written by CBIG under MIT license: https://github.com/ThomasYeoLab/CBIG/blob/master/LICENSE.md

set VERSION = '$Id: CBIG_preproc_fMRI_preprocess.csh, v 1.0 2016/06/09 $'


set n = `echo $argv | grep -e -help | wc -l`

# if there is -help option 
if( $n != 0 ) then
    echo $VERSION
    # print help
    cat $0 | awk 'BEGIN{prt=0}{if(prt) print $0; if($1 == "BEGINHELP") prt = 1 }'
    exit 0;
endif

# if there is no arguments
if( $#argv == 0 ) then
    echo $VERSION
    # print help
    cat $0 | awk 'BEGIN{prt=0}{if(prt) print $0; if($1 == "BEGINHELP") prt = 1 }'
    echo "WARNING: No input arguments. See above for a list of available input arguments."
    exit 0;
endif

set n = `echo $argv | grep -e -version | wc -l`
if ($n != 0) then
    echo $VERSION
    exit 0;
endif

set subject = ""    # subject ID
set anat = ""       # recon-all folder
set anat_dir = ""   # path to recon-all folder
set output_dir = "" # output directory
set config = ""     # config file
set curr_stem = ""  # current stem
set zpdbold = ""    # bold runs (002 003)
set BOLD_stem = "_rest" # Initialize the BOLD_stem with _rest, 
#the BOLD_stem is the input of each step and will be updated after each step
set REG_stem = ""   # stem of registration file produced by bbregister
set MASK_stem = ""  # stem of file used to create masks
set OUTLIER_stem="" # stem of file including censor frames
set nocleanup = 0   # default clean up intermediate files
set is_motion_corrected = 0 # flag indicates whether motion correction is performed
set is_distortion_corrected = 0 # flag indicates whether spatial distortion correction is performed 
set echo_number = 1 # echo number default to be 1
set nii_file_input = 0 # flag indicated whether input for -fmrinii is nifti file

set root_dir = `python -c "import os; print(os.path.realpath('$0'))"`
set root_dir = `dirname $root_dir`

goto parse_args;
parse_args_return:

goto check_params;
check_params_return:
##########################################
# Set preprocess log file and cleanup file
##########################################

mkdir -p $output_dir/$subject/logs
set LF = $output_dir/$subject/logs/CBIG_preproc_fMRI_preprocess.log
if ( -e $LF ) then
    rm $LF
endif
touch $LF
set cleanup_file = $output_dir/$subject/logs/cleanup.txt
if ( -e $cleanup_file ) then
    rm $cleanup_file
endif
touch $cleanup_file
echo "**************************************************************************" >> $LF
echo "***************************CBIG fMRI Preprocess***************************" >> $LF
echo "**************************************************************************" >> $LF
echo "[LOG]: logfile = $LF" >> $LF
echo "[CMD]: CBIG_preproc_fMRI_preprocess.csh $cmdline"   >> $LF

##########################################
# Set env and git log file
##########################################

set TS = `date +"%Y-%m-%d_%H-%M-%S"`

# output env variables to env log
set env_log = $output_dir/$subject/logs/env.log
echo "$TS" >> $env_log
echo "***************************Env variable***************************" >> $env_log
env >> $env_log

# check if git exists
which git
if ($status) then
    echo "WARNING: could not find git, skip generating git log." >> $LF
else
    set git_log = $output_dir/$subject/logs/git.log
    echo "$TS" >> $git_log
    echo "***************************Git: Last Commit of Current Repo***************************" >> $git_log
    pushd ${CBIG_CODE_DIR}
    git log -1 >> $git_log
    popd
endif

##########################################
# Read in Configuration file
##########################################

#filtering the comment line start with # and skip the blank lines
set config_clean = $output_dir/$subject/logs/CBIG_preproc_fMRI_preprocess.config
egrep -v '^#' $config | tr -s '\n' > $config_clean
set config = $config_clean

#print out the preprocessing order
echo "Verify your preprocess order:" >> $LF
foreach step ( "`cat $config`" )
    echo -n $step '=>' >> $LF
end
echo "DONE!" >> $LF

##########################################
# Read in echo number from config file if multiecho step is included in pipeline
# Otherwise, set echo_number to be 1 for single echo case
##########################################
set ME_step = `grep CBIG_preproc_multiecho_denoise $config`
# We compute the number of echoes by counting the comma delimiter of echo times
set echo_number = `echo "$ME_step" | awk -F "," '{print NF}'`
# If echo number is 0, multiecho step is not included. Hence echo number is set to be 1
if ( $echo_number == 0 ) then 
    set echo_number = 1
    echo "Input data is single echo." >> $LF
else
    echo "Input data is multi-echo data, perform multi-echo denoising. Number of echoes is $echo_number." >> $LF
endif

##########################################
# Read from config file whether multiecho is included,
# If so, print out user-specific python environment packages + version
##########################################
set package_list = $output_dir/$subject/logs/python_env_list.txt
if ( $echo_number > 1 ) then
    if ( -e $package_list ) then
        rm $package_list
    endif
    touch $package_list
    conda list >> $package_list
    set package_check = `grep tedana $package_list`
    if ( $#package_check == 0 ) then 
        echo "[ERROR]: Package 'Tedana' is missing and it is required for multiecho denoising!" >> $LF
        exit 1
    endif
endif

##########################################
# Read in fMRI nifti file list
##########################################
if ( $nii_file_input == 1) then
    set zpdbold = "001"
else
    #check if there are repeating run numbers
    set numof_runs_uniq = (`awk -F " " '{printf ("%03d\n", $1)}' $fmrinii_file | sort | uniq | wc -l`)
    set zpdbold = (`awk -F " " '{printf ("%03d ", $1)}' $fmrinii_file`)
    if ( $numof_runs_uniq != $#zpdbold ) then
        echo "[ERROR]: There are repeating bold run numbers!" >> $LF
        exit 1
    endif
endif

##########################################
# BOLD Information(read bold runs,output it into SUBJECT.bold file)
##########################################

echo "[BOLD INFO]: Number of runs: $#zpdbold" >> $LF 
echo "[BOLD INFO]: bold run $zpdbold" >> $LF
if ( $nii_file_input == 1) then
    set boldname = $fmrinii_file
else
    set boldname = (`awk '{for (i=2; i<NF; i++) printf $i " "; print $NF}' $fmrinii_file`)
endif
set a = $#boldname
set b = $#zpdbold
set echo_number_check = `echo " $a / $b" | bc`

# check fmrinii file colunm consistent with echo number
if ( $echo_number != $echo_number_check ) then
    echo "ERROR: input echo number $echo_number is not equal to the number of images $echo_number_check " >> $LF
    exit 1;
endif
set column_number = `echo "$echo_number +1"|bc`

#check fmri nifti file list columns, should be equal to echo number plus one
if ( $nii_file_input == 0 ) then
    set lowest_numof_column = (`awk '{print NF}' $fmrinii_file | sort -nu | head -n 1`)
    set highest_numof_column = (`awk '{print NF}' $fmrinii_file | sort -nu | tail -n 1`)
    echo "lowest_numof_column = $lowest_numof_column" >> $LF
    echo "highest_numof_column = $highest_numof_column" >> $LF
    if ( $lowest_numof_column != $column_number || $highest_numof_column != $column_number) then
        echo "[ERROR]: The input nifti file should only contain one column more than echo number!" >> $LF
        exit 1
    endif
endif

#set output structure and deoblique the input file and check orientation
if ( $echo_number == 1 ) then
    @ k = 1
    foreach curr_bold ($zpdbold)
        if ( ! -e $output_dir/$subject/bold/$curr_bold/$subject"_bld$curr_bold$BOLD_stem.nii.gz" ) then
            mkdir -p $output_dir/$subject/bold/$curr_bold
            set cmd = "$root_dir/utilities/CBIG_preproc_deoblique.sh"
            set cmd = "$cmd -i $boldname[$k]"
            set cmd = "$cmd -o $output_dir/$subject/bold/$curr_bold/${subject}_bld$curr_bold$BOLD_stem.nii.gz"
            echo "[Deoblique]: $cmd" >> $LF
            eval $cmd >>& $LF
        else
            echo "[BOLD INFO]: Input bold nifti file (${subject}_bld${curr_bold}${BOLD_stem}.nii.gz) already exists !" >> $LF
        endif
        @ k++
    end
else
    @ k = 1
    foreach curr_bold ($zpdbold)
        @ j = 1
        while ($j <= $echo_number)
            if ( ! -e $output_dir/$subject/bold/$curr_bold/$subject"_bld$curr_bold"_e$j"$BOLD_stem.nii.gz" ) then
                mkdir -p $output_dir/$subject/bold/$curr_bold
                set cmd = "$root_dir/utilities/CBIG_preproc_deoblique.sh"
                set cmd = "$cmd -i $boldname[$k]"
                set cmd = "$cmd -o $output_dir/$subject/bold/$curr_bold/${subject}_bld${curr_bold}_e$j$BOLD_stem.nii.gz"
                echo "[Deoblique]: $cmd" >> $LF
                eval $cmd >>& $LF
            else
                echo "[BOLD INFO]: Input bold nifti ($subject"_bld$curr_bold"_e$j"$BOLD_stem.nii.gz") file already exists !" >> $LF
            endif
            @ j++
            @ k++
        end
    end
endif
set Bold_file = $output_dir/$subject/logs/$subject.bold
if( -e $Bold_file ) then
    rm $Bold_file
endif
echo $zpdbold >> $Bold_file
echo "" >> $LF

##########################################
# Loop through each preprocess step
##########################################

foreach step ( "`cat $config`" )
    echo "" >> $LF

    #grep current preprocess step and input flag
    set curr_flag = ""
    set curr_step = (`echo $step | awk '{printf $1}'`)
    echo "[$curr_step]: Start..." >> $LF

    #get all arguments of current step
    set inputflag = (`echo $step | awk -F " " '{printf NF}'`)
    if ( $inputflag != 1) then
        set curr_flag = ( `echo $step | cut -f 1 -d " " --complement` )
        echo "[$curr_step]: curr_flag = $curr_flag" >> $LF
    endif

    set zpdbold = `cat $Bold_file`
    echo "[$curr_step]: zpdbold = $zpdbold"    >> $LF

    ##########################################
    # Preprocess step: Skip first n frames 
    ##########################################

    if ( "$curr_step" == "CBIG_preproc_skip" ) then

        set cmd = "$root_dir/CBIG_preproc_skip.csh -s $subject -d $output_dir -bld '$zpdbold' -BOLD_stem $BOLD_stem "
        set cmd = "$cmd -echo_number $echo_number"
        set cmd = "$cmd $curr_flag"
        echo "[$curr_step]: $cmd" >> $LF
        eval $cmd >&  /dev/null

        #update stem
        if ( $inputflag != 1 ) then
            set curr_stem = ("skip"`echo $curr_flag | awk -F "-skip" '{print $2}' | awk -F " " '{print $1}'`)
        else
            set curr_stem = "skip4"
        endif

        echo "[$curr_step]: bold_stem = $curr_stem" >> $LF
        set BOLD_stem = $BOLD_stem"_$curr_stem"


        #check existence of output
        foreach curr_bold ($zpdbold)
            #put output into cleanup file
            @ j=1
            if ( $echo_number >1 ) then 
                while ($j <= $echo_number)
                    echo $output_dir/$subject/bold/$curr_bold/${subject}_bld${curr_bold}_e${j}$BOLD_stem.nii.gz >> $cleanup_file
                    if ( ! -e $output_dir/$subject/bold/$curr_bold/$subject"_bld"${curr_bold}_e${j}$BOLD_stem.nii.gz ) then
                        echo "[ERROR]: file $output_dir/$subject/bold/$curr_bold\
/${subject}_bld${curr_bold}_e${j}$BOLD_stem.nii.gz can not be found" >> $LF
                        echo "[ERROR]: CBIG_preproc_skip fail!" >> $LF
                        exit 1
                    endif
                    @ j++
                end
            else
                echo $output_dir/$subject/bold/$curr_bold/${subject}_bld${curr_bold}$BOLD_stem.nii.gz >> $cleanup_file
                if ( ! -e $output_dir/$subject/bold/$curr_bold/$subject"_bld"${curr_bold}$BOLD_stem.nii.gz ) then
                    echo "[ERROR]: file $output_dir/$subject/bold/$curr_bold/${subject}_bld${curr_bold}$BOLD_stem.nii.gz \
can not be found" >> $LF
                    echo "[ERROR]: CBIG_preproc_skip fail!" >> $LF
                    exit 1
                endif
                @ j++
            endif

        end

    ##########################################
    # Preprocess step: slice time correction 
    ##########################################

    else if ( "$curr_step" == "CBIG_preproc_fslslicetimer" ) then
        set cmd = "$root_dir/CBIG_preproc_fslslicetimer.csh -s $subject -d $output_dir -bld '$zpdbold' "
        set cmd = "$cmd -echo_number $echo_number -BOLD_stem "
        set cmd = "$cmd $BOLD_stem $curr_flag"
        echo "[$curr_step]: $cmd" >> $LF
        eval $cmd >&  /dev/null 

        #update stem
        set curr_stem = "stc"
        echo "[$curr_step]: bold_stem = $curr_stem" >> $LF
        set BOLD_stem = $BOLD_stem"_$curr_stem"

        #check existence of output
        foreach curr_bold ($zpdbold)
            #put output into cleanup file
            if ( $echo_number >1 ) then 
                @ j=1
                while ($j <= $echo_number)
                    echo $output_dir/$subject/bold/$curr_bold/${subject}_bld${curr_bold}_e${j}$BOLD_stem.nii.gz >> $cleanup_file
                    if ( ! -e $output_dir/$subject/bold/$curr_bold/$subject"_bld"${curr_bold}_e${j}$BOLD_stem.nii.gz ) then
                        echo "[ERROR]: file $output_dir/$subject/bold/$curr_bold/${subject}_bld${curr_bold}_e${j}$BOLD_stem.nii.gz \
can not be found" >> $LF
                        echo "[ERROR]: CBIG_preproc_fslslicetimer fail!" >> $LF
                        exit 1
                    endif
                    @ j++
                end
            else
                echo $output_dir/$subject/bold/$curr_bold/${subject}_bld${curr_bold}$BOLD_stem.nii.gz >> $cleanup_file
                if ( ! -e $output_dir/$subject/bold/$curr_bold/$subject"_bld"${curr_bold}$BOLD_stem.nii.gz ) then
                    echo "[ERROR]: file $output_dir/$subject/bold/$curr_bold/${subject}_bld${curr_bold}$BOLD_stem.nii.gz \
can not be found" >> $LF
                    echo "[ERROR]: CBIG_preproc_fslslicetimer fail!" >> $LF
                    exit 1
                endif
                @ j++
            endif
        end

    ##########################################
    # Preprocess step: motion correction and detect outliers using FDRMS & DVARS as metric 
    ##########################################

    else if ( $curr_step == "CBIG_preproc_fslmcflirt_outliers" ) then
        if ( $nocleanup == 1) then            # do not cleanup
            # check if curr_flag contains -nocleanup
            set flag_ind = `echo $curr_flag | awk '{print index($0, "-nocleanup")}'`
            if ( $flag_ind == 0 ) then        # 0 means curr_flag does not contain "-nocleanup", add "-nocleanup"
                set curr_flag = "$curr_flag -nocleanup"
            endif
            echo "[$curr_step]: -nocleanup is passed in wrapper function CBIG_preproc_fMRI_preprocess.csh. \
The intermediate files from motion correction step will not be removed." >> $LF
        endif

        set cmd = "$root_dir/CBIG_preproc_fslmcflirt_outliers.csh -s $subject -d $output_dir -bld '$zpdbold' "
        set cmd = "$cmd -echo_number $echo_number"
        set cmd = "$cmd -BOLD_stem $BOLD_stem $curr_flag"
        echo "[$curr_step]: $cmd" >> $LF
        eval $cmd >&  /dev/null

        #update stem 
        set curr_stem = "mc"
        echo "[$curr_step]: bold_stem = $curr_stem" >> $LF
        set mc_stem = $BOLD_stem
        set BOLD_stem = $BOLD_stem"_$curr_stem"

        set FD_stem = (`echo $curr_flag | awk -F "-FD_th" '{print $2}' | awk -F " " '{print $1}'`)
        set DV_stem = (`echo $curr_flag | awk -F "-DV_th" '{print $2}' | awk -F " " '{print $1}'`)

        #Both FDRMS, DVARS threshold are given
        if ( "$FD_stem" != "" && "$DV_stem" != "") then 
            set OUTLIER_stem = "_FDRMS${FD_stem}_DVARS${DV_stem}_motion_outliers.txt"
            echo "[$curr_step]: FDRMS threshold = $FD_stem"  >> $LF
            echo "[$curr_step]: DVARS threshold = $DV_stem"  >> $LF
        endif
        #Only FDRMS threshold given, use DVARS threshold as default: 50
        if ( "$FD_stem" != "" && "$DV_stem" == "") then 
            set OUTLIER_stem = "_FDRMS${FD_stem}_DVARS50_motion_outliers.txt"
            echo "[$curr_step]: FDRMS threshold = $FD_stem"  >> $LF
            echo "[$curr_step]: DVARS threshold set as default: 50"  >> $LF
        endif
        #Only DVARS threshold given, use FDRMS threshold as default: 0.2
        if ( "$FD_stem" == "" && "$DV_stem" != "") then 
            set OUTLIER_stem = "_FDRMS0.2_DVARS${DV_stem}_motion_outliers.txt"
            echo "[$curr_step]: FDRMS threshold set as default: 0.2"  >> $LF
            echo "[$curr_step]: DVARS threshold = $DV_stem"  >> $LF
        endif
        #FDRMS and DVARS threshold not given, use FDRMS threshold as default: 0.2, use DVARS threshold as default: 50
        if ( "$FD_stem" == "" && "$DV_stem" == "") then 
            set OUTLIER_stem = "_FDRMS0.2_DVARS50_motion_outliers.txt"
            echo "[$curr_step]: FDRMS threshold set as default: 0.2"  >> $LF
            echo "[$curr_step]: DVARS threshold set as default: 50"  >> $LF
        endif
        echo "[$curr_step]: OUTLIER_stem = $OUTLIER_stem" >> $LF

        # if no run was left, then give a warning and exit the preprocessing 
        set zpdbold = `cat $Bold_file`
        if ( "$zpdbold" == "" ) then
            echo "[WARNING]: There is no bold run left after discarding runs with high motion." >> $LF
            echo "Preprocessing Completed!" >> $LF
            exit 0
        endif
         
        #check existence of output
        foreach curr_bold ($zpdbold)
            if ( $echo_number == 1 ) then 
                if ( ! -e $output_dir/$subject/bold/$curr_bold/$subject"_bld"${curr_bold}$BOLD_stem.nii.gz ) then
                    echo "[ERROR]: file $output_dir/$subject/bold/$curr_bold/${subject}_bld${curr_bold}$BOLD_stem.nii.gz \
can not be found" >> $LF
                    echo "[ERROR]: CBIG_preproc_fslmcflirt_outliers fail!" >> $LF
                    exit 1
                endif
            else
            @ j=1
                while ( $j <= $echo_number)
                    if ( ! -e $output_dir/$subject/bold/$curr_bold/$subject"_bld"${curr_bold}_e${j}$BOLD_stem.nii.gz ) then
                        echo "[ERROR]: file $output_dir/$subject/bold/$curr_bold/${subject}_bld${curr_bold}_e${j}$BOLD_stem.nii.gz \
can not be found" >> $LF
                        echo "[ERROR]: CBIG_preproc_fslmcflirt_outliers fail!" >> $LF
                        exit 1
                    endif
                    @ j++
                end
            endif
        end

        # if motion correction is done successfully, the following flag value is set to 1
        set is_motion_corrected = 1

    ##########################################
    # Preprocess step: spatial distortion correction
    ##########################################

    else if ( "$curr_step" == "CBIG_preproc_spatial_distortion_correction" ) then
        # spatial distortion correction can only be performed after motion correction is done
        if ( $is_motion_corrected == 0 ) then
            echo "[ERROR]: BOLD image is not motion corrected. Spatial Distortion Correction cannot be performed." >> $LF
            exit 1
        else
            if ( $nocleanup == 1) then            # do not cleanup
                # check if curr_flag contains -nocleanup
                set flag_ind = `echo $curr_flag | awk '{print index($0, "-nocleanup")}'`
                if ( $flag_ind == 0 ) then        # 0 means curr_flag does not contain "-nocleanup", add "-nocleanup"
                    set curr_flag = "$curr_flag -nocleanup"
                endif
                echo "[$curr_step]: -nocleanup is passed in wrapper function CBIG_preproc_fMRI_preprocess.csh. \
The intermediate files from spatial distortion correction step will not be removed." >> $LF
            endif

            set cmd = "$root_dir/CBIG_preproc_spatial_distortion_correction.csh -s $subject -d $output_dir -bld '$zpdbold' "
            set cmd = "$cmd -echo_number $echo_number"
            set cmd = "$cmd -BOLD_stem $mc_stem $curr_flag"
            echo "[$curr_step]: $cmd" >> $LF
            eval $cmd >& /dev/null

            # Spatial Distortion Correction QC: run BBR on BOLD image that is not distortion corrected

            # Here, we are running BBR on motion-corrected but not distortion-corrceted image. 
            # As a QC step, the BBR costs can be compared between images with/without distortion correction. By right, the image
            # with distortion correction should have a lower BBR cost than the image without distortion correction.
            # Note that this BBR step here is for QC only, but not the REAL preprocessing step.
            rsync -az $output_dir/$subject/bold/ $output_dir/$subject/bold_backup
            rsync -az $output_dir/$subject/logs/ $output_dir/$subject/logs_backup
            rsync -az $output_dir/$subject/qc/ $output_dir/$subject/qc_backup

            if ( $echo_number > 1 ) then
                set MEICA_flag = `grep "CBIG_preproc_multiecho_denoise" $config`
                set MEICA_flag = ( `echo $MEICA_flag | cut -f 1 -d " " --complement` )
                set cmd = "$root_dir/CBIG_preproc_multiecho_denoise.csh -s $subject"
                set cmd = "$cmd -d $output_dir -bld '$zpdbold' -BOLD_stem ${mc_stem}_mc" 
                set cmd = "$cmd -echo_number $echo_number"
                set cmd = "$cmd $MEICA_flag"
                eval $cmd >& /dev/null 
                set cmd = "$root_dir/CBIG_preproc_bbregister.csh -s $subject -d $output_dir -anat_s $anat -anat_d $anat_dir "
                set cmd = "$cmd -bld '$zpdbold' -BOLD_stem ${mc_stem}_mc_me "
                eval $cmd >& /dev/null 
            else
                set cmd = "$root_dir/CBIG_preproc_bbregister.csh -s $subject -d $output_dir -anat_s $anat -anat_d $anat_dir "
                set cmd = "$cmd -bld '$zpdbold' -BOLD_stem ${mc_stem}_mc "
                eval $cmd >& /dev/null 
            endif

            # Extract the BBR cost without distortion correction
            set cmd = "mv $output_dir/$subject/qc/CBIG_preproc_bbregister_intra_sub_reg.cost"
            set cmd = "$cmd $output_dir/$subject/qc_backup/CBIG_preproc_bbregister_intra_sub_reg_no_sdc.cost"
            eval $cmd >& /dev/null 

            # clean up temporary directories
            rm -r -f $output_dir/$subject/bold
            rm -r -f $output_dir/$subject/logs
            rm -r $output_dir/$subject/qc
            mv $output_dir/$subject/bold_backup $output_dir/$subject/bold
            mv $output_dir/$subject/logs_backup $output_dir/$subject/logs
            mv $output_dir/$subject/qc_backup $output_dir/$subject/qc

            #update stem
            set curr_stem = "mc_sdc"
            set BOLD_stem = "$mc_stem"_"$curr_stem"

            #check existence of output
            foreach curr_bold ($zpdbold)
                if ( $echo_number == 1 ) then 
                    if ( ! -e $output_dir/$subject/bold/$curr_bold/$subject"_bld"${curr_bold}$BOLD_stem.nii.gz ) then
                        echo "[ERROR]: file $output_dir/$subject/bold/$curr_bold/${subject}_bld${curr_bold}$BOLD_stem.nii.gz \
can not be found" >> $LF
                        echo "[ERROR]: CBIG_preproc_spatial_distortion_correction fail!" >> $LF
                        exit 1
                    endif
                else
                    @ j=1
                    while ( $j <= $echo_number)
                        if ( ! -e $output_dir/$subject/bold/$curr_bold/$subject"_bld"${curr_bold}_e${j}$BOLD_stem.nii.gz ) then
                            echo "[ERROR]: file $output_dir/$subject/bold/$curr_bold/${subject}_bld${curr_bold}_e${j}$BOLD_stem.nii.gz \
can not be found" >> $LF
                            echo "[ERROR]: CBIG_preproc_spatial_distortion_correction fail!" >> $LF
                            exit 1
                        endif
                        @ j++
                    end
                endif
            end

            # if spatial distortion correction is done successfully, the following flag value is set to 1
            set is_distortion_corrected = 1
        endif

    ##########################################
    # Preprocess step: multi-echo ICA (ME-ICA)
    ##########################################
    else if ( "$curr_step" == "CBIG_preproc_multiecho_denoise" ) then
        ## CBIG_preproc_multiecho_denoise
        if ( $nocleanup == 1) then            # do not cleanup
            # check if curr_flag contains -nocleanup
            set flag_ind = `echo $curr_flag | awk '{print index($0, "-nocleanup")}'`
            if ( $flag_ind == 0 ) then        # 0 means curr_flag does not contain "-nocleanup", add "-nocleanup"
                set curr_flag = "$curr_flag -nocleanup"
            endif
            echo "[$curr_step]: -nocleanup is passed in wrapper function CBIG_preproc_fMRI_preprocess.csh. \
The intermediate files from multi-echo denoising step will not be removed." >> $LF
        endif

        set cmd = "$root_dir/CBIG_preproc_multiecho_denoise.csh -s $subject"
        set cmd = "$cmd -d $output_dir -bld '$zpdbold' -BOLD_stem $BOLD_stem" 
        set cmd = "$cmd -echo_number $echo_number"
        set cmd = "$cmd $curr_flag"
        echo "[$curr_step]: $cmd" >> $LF
        eval $cmd >&  /dev/null

        #update stem
        set curr_stem = "me"
        echo "[$curr_step]: bold_stem = $curr_stem" >> $LF
        set BOLD_stem = $BOLD_stem"_$curr_stem"
        #check existence of output
        foreach curr_bold ($zpdbold)
            if ( ! -e $output_dir/$subject/bold/$curr_bold/$subject"_bld"$curr_bold$BOLD_stem.nii.gz ) then
                echo "[ERROR]: file $output_dir/$subject/bold/$curr_bold/${subject}_bld$curr_bold$BOLD_stem.nii.gz \
can not be found" >> $LF
                echo "[ERROR]: CBIG_preproc_multiecho_denoise fail!" >> $LF
                exit 1
            endif
        end


    ##########################################
    # Preprocess step: function-anatomical registration
    ##########################################

    else if ( "$curr_step" == "CBIG_preproc_bbregister" ) then

        set cmd = "$root_dir/CBIG_preproc_bbregister.csh -s $subject -d $output_dir -anat_s $anat -anat_d $anat_dir "
        set cmd = "$cmd -bld '$zpdbold' -BOLD_stem $BOLD_stem $curr_flag"
        echo "[$curr_step]: $cmd" >> $LF
        eval $cmd >&  /dev/null

        #update stem
        set curr_stem = "reg"
        echo "[$curr_step]: bold_stem = $curr_stem" >> $LF
        set REG_stem = $BOLD_stem
        set MASK_stem = $BOLD_stem
        set REG_stem = $REG_stem"_$curr_stem"

        #combine BBR cost with disortion correction and without distortion correction
        if ( $is_distortion_corrected == 1 ) then
            # in the CBIG_preproc_bbregister_instra_sub_reg.cost file, the first number is the BBR cost
            # with distortion correction, the second number is the BBR cost without distortion correction
            # By right, the first number should not be greater than the second number
            set bbr_cost_with_sdc = `cat $output_dir/$subject/qc/CBIG_preproc_bbregister_intra_sub_reg.cost`
            set bbr_cost_without_sdc = `cat $output_dir/$subject/qc/CBIG_preproc_bbregister_intra_sub_reg_no_sdc.cost`
            # output a warning if BBR cost with SDC is higher than BBR cost without SDC
            set run_number = 1
            while ( $run_number < = $#bbr_cost_with_sdc )
                set bbr_cost_with_sdc_current_run = `printf "%f" $bbr_cost_with_sdc[$run_number]`
                set bbr_cost_without_sdc_current_run = `printf "%f" $bbr_cost_without_sdc[$run_number]`
                if ( `echo "$bbr_cost_with_sdc_current_run > $bbr_cost_without_sdc_current_run" | bc` ) then 
                    echo "[WARNING] BBR cost is higher with distortion correction ($bbr_cost_with_sdc)\
than without distortion correction ($bbr_cost_without_sdc)." >> $LF
                endif
                @ run_number = $run_number + 1
            end
            unset run_number

            set cmd = "paste $output_dir/$subject/qc/CBIG_preproc_bbregister_intra_sub_reg.cost"
            set cmd = "$cmd $output_dir/$subject/qc/CBIG_preproc_bbregister_intra_sub_reg_no_sdc.cost >"
            set cmd = "$cmd $output_dir/$subject/qc/CBIG_preproc_bbregister_intra_sub_reg_sdc.cost"
            eval $cmd >& /dev/null

            rm $output_dir/$subject/qc/CBIG_preproc_bbregister_intra_sub_reg_no_sdc.cost
            rm $output_dir/$subject/qc/CBIG_preproc_bbregister_intra_sub_reg.cost
            set cmd = "mv $output_dir/$subject/qc/CBIG_preproc_bbregister_intra_sub_reg_sdc.cost"
            set cmd = "$cmd $output_dir/$subject/qc/CBIG_preproc_bbregister_intra_sub_reg.cost"
            eval $cmd >& /dev/null

        endif

        #check existence of output
        foreach curr_bold ($zpdbold)
            if ( ! -e $output_dir/$subject/bold/$curr_bold/$subject"_bld"$curr_bold$REG_stem.dat ) then
                echo "[ERROR]: file $output_dir/$subject/bold/$curr_bold/$subject"_bld"$curr_bold$REG_stem.dat \
can not be found" >> $LF
                echo "[ERROR]: CBIG_preproc_bbregister!" >> $LF
                exit 1
            endif
        end

    ##########################################
    # Preprocess step: despiking 
    ##########################################

    else if ( "$curr_step" == "CBIG_preproc_despiking" ) then
        
        set cmd = "$root_dir/CBIG_preproc_despiking.csh -s $subject -d $output_dir -bld '$zpdbold' -BOLD_stem "
        set cmd = "$cmd $BOLD_stem $curr_flag"
        echo "[$curr_step]: $cmd" >> $LF
        eval $cmd >&  /dev/null 

        #update stem
        set curr_stem = "dspk"
        echo "[$curr_step]: bold_stem = $curr_stem" >> $LF
        set BOLD_stem = $BOLD_stem"_$curr_stem"

        #check existence of output
        foreach curr_bold ($zpdbold)
            if ( ! -e $output_dir/$subject/bold/$curr_bold/$subject"_bld"$curr_bold$BOLD_stem.nii.gz ) then
                echo "[ERROR]: file $output_dir/$subject/bold/$curr_bold/${subject}_bld$curr_bold$BOLD_stem.nii.gz \
can not be found" >> $LF
                echo "[ERROR]: CBIG_preproc_despiking fail!" >> $LF
                exit 1
            endif
        end


    ##########################################
    # Preprocess step: Motion Scrubbing and Interpolation
    ##########################################

    else if ( $curr_step == "CBIG_preproc_censor" ) then

        # usage of -nocleanup option of censoring interpolation step is allowing the wrapper function
        if ( $nocleanup == 1) then            # do not cleanup
            # check if curr_flag contains -nocleanup
            set flag_ind = `echo $curr_flag | awk '{print index($0, "-nocleanup")}'`
            if ( $flag_ind == 0 ) then        # 0 means curr_flag does not contain "-nocleanup", add "-nocleanup"
                set curr_flag = "$curr_flag -nocleanup"
            endif
            echo "[$curr_step]: -nocleanup is passed in wrapper function CBIG_preproc_fMRI_preprocess.csh. \
The intermediate censoring interpolation volume will not be removed." >> $LF
        endif

        set cmd = "$root_dir/CBIG_preproc_censor.csh -s $subject -d $output_dir -anat_s $anat -anat_d $SUBJECTS_DIR "
        set cmd = "$cmd -bld '$zpdbold' -BOLD_stem $BOLD_stem -REG_stem $REG_stem -OUTLIER_stem $OUTLIER_stem "
        set cmd = "$cmd $curr_flag"
        echo "[$curr_step]: $cmd" >> $LF
        eval $cmd >&  /dev/null 

        #update stem
        set FD_th = (`echo $OUTLIER_stem | awk -F "FDRMS" '{print $2}' | awk -F "_" '{print $1}'`)
        set DV_th = (`echo $OUTLIER_stem | awk -F "DVARS" '{print $2}' | awk -F "_" '{print $1}'`)
        set low_f = ( `echo $curr_flag | awk -F "-low_f" '{print $2}' | awk -F " " '{print $1}'` )
        set high_f = ( `echo $curr_flag | awk -F "-high_f" '{print $2}' | awk -F " " '{print $1}'` )
        set curr_stem = "interp_FDRMS${FD_th}_DVARS${DV_th}"
        if ( "$low_f" != "" && "$high_f" != "") then 
            set curr_stem = ${curr_stem}"_bp_"$low_f"_"$high_f
        endif
        echo "[$curr_step]: bold_stem = $curr_stem" >> $LF
        set BOLD_stem = $BOLD_stem"_$curr_stem"
         
        #check existence of output
        set zpdbold = `cat $Bold_file`
           
        foreach curr_bold ($zpdbold)
            if ( ! -e $output_dir/$subject/bold/$curr_bold/$subject"_bld"$curr_bold$BOLD_stem.nii.gz ) then
                echo "[ERROR]: file $output_dir/$subject/bold/$curr_bold/${subject}_bld$curr_bold$BOLD_stem.nii.gz \
can not be found" >> $LF
                echo "[ERROR]: CBIG_preproc_censor fail!" >> $LF
                exit 1
            endif
        end

    ##########################################
    # Preprocess step: Bandpass/Lowpass/Highpass Filtering
    ##########################################

    else if ( "$curr_step" == "CBIG_preproc_bandpass" ) then

        set cmd = "$root_dir/CBIG_preproc_bandpass_fft.csh -s $subject -d $output_dir -bld '$zpdbold' -BOLD_stem " 
        set cmd = "$cmd $BOLD_stem -OUTLIER_stem $OUTLIER_stem $curr_flag"
        echo "[$curr_step]: $cmd" >> $LF
        eval $cmd >&  /dev/null 

        #update stem
        set low_f = ( `echo $curr_flag | awk -F "-low_f" '{print $2}' | awk -F " " '{print $1}'` )
        set high_f = ( `echo $curr_flag | awk -F "-high_f" '{print $2}' | awk -F " " '{print $1}'` )
        #bandpass
        if ( "$low_f" != "" && "$high_f" != "") then 
            set curr_stem = "bp_"$low_f"_"$high_f
            echo "[$curr_step]: bandpass filtering.." >> $LF
            echo "[$curr_step]: low_f = $low_f"  >> $LF
            echo "[$curr_step]: high_f = $high_f"  >> $LF
        else
            echo "Please specify both low frequency and high frequency, e.g. -low_f 0.001 -high_f 0.08"
            exit 1
        endif
        echo "[$curr_step]: bold_stem = $curr_stem" >> $LF
        set BOLD_stem = $BOLD_stem"_$curr_stem"

        #check existence of output
        foreach curr_bold ($zpdbold)

            if ( ! -e $output_dir/$subject/bold/$curr_bold/$subject"_bld"$curr_bold$BOLD_stem.nii.gz ) then
                echo "[ERROR]: file $output_dir/$subject/bold/$curr_bold/${subject}_bld$curr_bold$BOLD_stem.nii.gz \
can not be found" >> $LF
                echo "[ERROR]: CBIG_preproc_bandpass fail!" >> $LF
                exit 1
            endif
        end


    ##########################################
    # Preprocess step: Regression ( Use ouput of last step as the MASK input )
    ##########################################

    else if ( $curr_step == "CBIG_preproc_regress" ) then

        set cmd = "$root_dir/CBIG_preproc_regression.csh -s $subject -d $output_dir -anat_s $anat -anat_d "
        set cmd = "$cmd $SUBJECTS_DIR -bld '$zpdbold' -BOLD_stem $BOLD_stem -REG_stem $REG_stem -MASK_stem $BOLD_stem "
        set cmd = "$cmd -OUTLIER_stem $OUTLIER_stem $curr_flag"
        echo "[$curr_step]: $cmd" >> $LF
        eval $cmd >&  /dev/null 

        #update stem
        set censor_flag = ( `echo $curr_flag | grep "-censor"` )
        if ( $censor_flag == 1 ) then
            set curr_stem = "residc"
        else
            set curr_stem = "resid"
        endif

        echo "[$curr_step]: bold_stem = $curr_stem" >> $LF
        set BOLD_stem = $BOLD_stem"_$curr_stem"
        #check existence of output
        foreach curr_bold ($zpdbold)

        #put output into cleanup file
        echo $output_dir/$subject/bold/$curr_bold/${subject}_bld$curr_bold$BOLD_stem.nii.gz >> $cleanup_file

            if ( ! -e $output_dir/$subject/bold/$curr_bold/$subject"_bld"$curr_bold$BOLD_stem.nii.gz ) then
                echo "[ERROR]: file $output_dir/$subject/bold/$curr_bold/${subject}_bld$curr_bold$BOLD_stem.nii.gz \
can not be found" >> $LF
                echo "[ERROR]: CBIG_preproc_regress fail!" >> $LF
                exit 1
            endif
        end

    ##########################################
    # Preprocess step: Create greyplot (quality control)
    ##########################################
    else if ( $curr_step == "CBIG_preproc_QC_greyplot" ) then
        if ( $nocleanup == 1) then            # do not cleanup
            # check if curr_flag contains -nocleanup
            set flag_ind = `echo $curr_flag | awk '{print index($0, "-nocleanup")}'`
            if ( $flag_ind == 0 ) then        # 0 means curr_flag does not contain "-nocleanup", add "-nocleanup"
                set curr_flag = "$curr_flag -nocleanup"
            endif
            echo "[$curr_step]: -nocleanup is passed in wrapper function CBIG_preproc_fMRI_preprocess.csh. \
The intermediate files from plotting QC greyplot will not be removed." >> $LF
        endif

        set cmd = "$root_dir/CBIG_preproc_QC_greyplot.csh -s $subject -d $output_dir -anat_s $anat -anat_d "
        set cmd = "$cmd $SUBJECTS_DIR -bld '$zpdbold' -BOLD_stem $BOLD_stem -REG_stem $REG_stem -MC_stem $mc_stem "
        set cmd = "$cmd -echo_number $echo_number $curr_flag"
        echo "[$curr_step]: $cmd" >> $LF
        eval $cmd >&  /dev/null

        foreach curr_bold ($zpdbold)
            if ( ! -e $output_dir/$subject/qc/$subject"_bld"$curr_bold$BOLD_stem"_greyplot.png" ) then
                echo "[ERROR]: file $output_dir/$subject/qc/${subject}_bld${curr_bold}${BOLD_stem}_greyplot.png \
can not be found" >> $LF
                echo "[ERROR]: CBIG_preproc_QC_greyplot fail!" >> $LF
                exit 1
            endif
        end

    ##########################################
    # Preprocess step: Porjection to fsaverage surface 
    # (project to high resolution => smooth => downsample to low resolution)
    ##########################################

    else if ( $curr_step == "CBIG_preproc_native2fsaverage" ) then

        set cmd = "$root_dir/CBIG_preproc_native2fsaverage.csh -s $subject -d $output_dir -anat_s $anat -anat_d "
        set cmd = "$cmd $SUBJECTS_DIR -bld '$zpdbold' -BOLD_stem $BOLD_stem -REG_stem $REG_stem $curr_flag"
        echo "[$curr_step]: $cmd" >> $LF
        eval $cmd >&  /dev/null

        #update stem
        if ( $inputflag != 1 ) then
            set proj_mesh = ( `echo $curr_flag | awk -F "-proj" '{print $2}' | awk -F " " '{print $1}'` )
            set sm = ( `echo $curr_flag | awk -F "-sm" '{print $2}' | awk -F " " '{print $1}'` )
            set down_mesh = ( `echo $curr_flag | awk -F "-down" '{print $2}' | awk -F " " '{print $1}'` )
            set proj_res = `echo -n $proj_mesh | tail -c -1`
            if($proj_res == "e") then
                set proj_res = 7
            endif

            set down_res = `echo -n $down_mesh | tail -c -1`
            if($down_res == "e") then
                set down_res = 7;
            endif
        else
            set curr_stem = "fs6_sm6_fs5"
        endif

        set curr_stem = fs${proj_res}_sm${sm}_fs${down_res}
        echo "[$curr_step]: bold_stem = $curr_stem" >> $LF
        set SURF_stem = $BOLD_stem"_$curr_stem"
        set FC_SURF_stem = ${BOLD_stem}_fs${proj_res}_sm${sm}

        #check existence of output
        foreach curr_bold ($zpdbold)
            if ( ! -e $output_dir/$subject/surf/lh.$subject"_bld"$curr_bold$SURF_stem.nii.gz || \
! -e $output_dir/$subject/surf/rh.$subject"_bld"$curr_bold$SURF_stem.nii.gz) then
                echo "[ERROR]: file $output_dir/$subject/surf/${subject}_bld$curr_bold$SURF_stem.nii.gz \
can not be found" >> $LF
                echo "[ERROR]: CBIG_preproc_native2fsaverage fail!" >> $LF
                exit 1
            endif
        end

    ##########################################
    # Preprocess step: Compute FC (functional connectivity) metrics
    ##########################################
    else if ( $curr_step == "CBIG_preproc_FC_metrics" ) then

        # usage of -nocleanup option of censoring interpolation step is allowing the wrapper function
        if ( $nocleanup == 1) then            # do not cleanup
            # check if curr_flag contains -nocleanup
            set flag_ind = `echo $curr_flag | awk '{print index($0, "-nocleanup")}'`
            if ( $flag_ind == 0 ) then        # 0 means curr_flag does not contain "-nocleanup", add "-nocleanup"
                set curr_flag = "$curr_flag -nocleanup"
            endif
            echo "[$curr_step]: -nocleanup is passed in wrapper function CBIG_fMRI_preprocess.csh. \
The intermediate files from FC computation step will not be removed." >> $LF
        endif

        set cmd = "$root_dir/CBIG_preproc_FCmetrics_wrapper.csh -s $subject -d $output_dir -bld '$zpdbold' "
        set cmd = "$cmd -BOLD_stem $BOLD_stem -SURF_stem $FC_SURF_stem -OUTLIER_stem $OUTLIER_stem $curr_flag"
        echo "[$curr_step]: $cmd" >> $LF
        eval $cmd >& /dev/null

        # update stem & check existance of output
        if ( "$curr_flag" =~ *"-Pearson_r"* ) then
            set FC_metrics_stem = "${FC_SURF_stem}_all2all"
            if ( "$curr_flag" =~ *"p_name"* ) then
                set parcellation_name = ( `echo $curr_flag | awk -F "-p_name" '{print $2}' | awk -F " " '{print $1}'` )
                set FC_metrics_stem = "${FC_metrics_stem}_${parcellation_name}_with_19Subcortical"
            else 
                if ( "$curr_flag" =~ *"p_type"* ) then
                    set parcellation_type = ( `echo $curr_flag | awk -F "-p_type" '{print $2}' | awk -F " " '{print $1}'` )
                else
                    set parcellation_type = 'Yan'
                endif
                if ( "$curr_flag" =~ *"res"* ) then
                    set res = ( `echo $curr_flag | awk -F "-res" '{print $2}' | awk -F " " '{print $1}'` )
                else
                    set res = '400'
                endif
                if ( "$curr_flag" =~ *"network"* ) then
                    set network = ( `echo $curr_flag | awk -F "-network" '{print $2}' | awk -F " " '{print $1}'` )
                else
                    set network = 'Kong17'
                endif
                set parcellation_name = "${parcellation_type}_${res}Parcels_${network}Networks_order_with_19Subcortical"
                set FC_metrics_stem = "${FC_metrics_stem}_${parcellation_name}"
            endif
            if ( ! -e $output_dir/$subject/FC_metrics/Pearson_r/$subject$FC_metrics_stem.mat ) then
                echo "[ERROR]: file $output_dir/$subject/FC_metrics/Pearson_r/$subject$FC_metrics_stem.mat" \
"can not be found" >> $LF
                echo "[ERROR]: CBIG_preproc_FC_metrics fail!" >> $LF
                exit 1
            endif
        endif

    ##########################################
    # Preprocess step: Porjection to MNI volume space (Project to FS1mm => MNI1mm => MNI2mm => Smooth)
    ##########################################

    else if ( $curr_step == "CBIG_preproc_native2mni" ) then
        if ( $nocleanup == 1) then            # do not cleanup
            # check if curr_flag contains -nocleanup
            set flag_ind = `echo $curr_flag | awk '{print index($0, "-nocleanup")}'`
            if ( $flag_ind == 0 ) then        # 0 means curr_flag does not contain "-nocleanup", add "-nocleanup"
                set curr_flag = "$curr_flag -nocleanup"
            endif
            echo "[$curr_step]: -nocleanup is passed in wrapper function CBIG_preproc_fMRI_preprocess.csh. \
The intermediate files from volumetric projection step will not be removed." >> $LF
        endif

        set cmd = "$root_dir/CBIG_preproc_native2mni.csh -s $subject -d $output_dir -anat_s $anat -anat_d "
        set cmd = "$cmd $SUBJECTS_DIR -bld '$zpdbold' -BOLD_stem $BOLD_stem -REG_stem $REG_stem $curr_flag"
        echo "[$curr_step]: $cmd" >> $LF
        eval $cmd >&  /dev/null 

        #update stem
        set sm = ( `echo $curr_flag | awk -F "-sm " '{print $2}' | awk -F " " '{print $1}'` )
        if ( $sm != "" ) then
            if ( $sm <= 0 ) then
                set curr_stem = "FS1mm_MNI1mm_MNI2mm"
            else
                set curr_stem = "FS1mm_MNI1mm_MNI2mm_sm"$sm
            endif
        else
            set curr_stem = "FS1mm_MNI1mm_MNI2mm_sm6"
        endif
        set final_mask = (`echo $curr_flag | awk -F "-final_mask " '{print $2}' | awk -F " " '{print $1}'`)
        if ( $final_mask != "" ) then
            set curr_stem = ${curr_stem}_finalmask
        endif
        echo "[$curr_step]: bold_stem = $curr_stem" >> $LF
        set VOL_stem = $BOLD_stem"_$curr_stem"
        #check existence of output
        foreach curr_bold ($zpdbold)
            if ( ! -e $output_dir/$subject/vol/$subject"_bld"$curr_bold$VOL_stem.nii.gz ) then
                echo "[ERROR]: file $output_dir/$subject/vol/${subject}_bld$curr_bold$VOL_stem.nii.gz \
can not be found" >> $LF
                echo "[ERROR]: CBIG_preproc_native2mni fail!" >> $LF
                exit 1
            endif
        end


    ##########################################
    # Preprocess step: Porjection to MNI volume space using ANTs (Project to FS1mm => MNI2mm => Smooth)
    ##########################################

    else if ( $curr_step == "CBIG_preproc_native2mni_ants" ) then
        if ( $nocleanup == 1) then            # do not cleanup
            # check if curr_flag contains -nocleanup
            set flag_ind = `echo $curr_flag | awk '{print index($0, "-nocleanup")}'`
            if ( $flag_ind == 0 ) then        # 0 means curr_flag does not contain "-nocleanup", add "-nocleanup"
                set curr_flag = "$curr_flag -nocleanup"
            endif
            echo "[$curr_step]: -nocleanup is passed in wrapper function CBIG_preproc_fMRI_preprocess.csh. \
The intermediate files from volumetric projection step will not be removed." >> $LF
        endif

        set cmd = "$root_dir/CBIG_preproc_native2mni_ants.csh -s $subject -d $output_dir -anat_s $anat -anat_d"
        set cmd = "$cmd $SUBJECTS_DIR -bld '$zpdbold' -BOLD_stem $BOLD_stem -REG_stem $REG_stem $curr_flag"
        echo "[$curr_step]: $cmd" >> $LF
        eval $cmd >&  /dev/null 

        #update stem
        set sm = ( `echo $curr_flag | awk -F "-sm " '{print $2}' | awk -F " " '{print $1}'` )
        if ( $sm != "" ) then
            if ( $sm <= 0 ) then
                set curr_stem = "MNI2mm"
            else
                set curr_stem = "MNI2mm_sm"$sm
            endif
        else
            set curr_stem = "MNI2mm_sm6"
        endif
        set final_mask = (`echo $curr_flag | awk -F "-final_mask " '{print $2}' | awk -F " " '{print $1}'`)
        if ( $final_mask != "" ) then
            set curr_stem = ${curr_stem}_finalmask
        endif
        echo "[$curr_step]: bold_stem = $curr_stem" >> $LF
        set VOL_stem = $BOLD_stem"_$curr_stem"
        #check existence of output
        foreach curr_bold ($zpdbold)
            if ( ! -e $output_dir/$subject/vol/$subject"_bld"$curr_bold$VOL_stem.nii.gz ) then
                echo "[ERROR]: file $output_dir/$subject/vol/${subject}_bld$curr_bold$VOL_stem.nii.gz" >> $LF
                echo "         can not be found" >> $LF
                echo "[ERROR]: CBIG_preproc_native2mni_ants fail!" >> $LF
                exit 1
            endif
        end

    else

    ##########################################
    # Preprocess step can not be recognized 
    ##########################################

        echo "ERROR: $curr_step can not be identified in our preprocessing step" >> $LF
        exit 1

    endif
    echo "[$curr_step]: Done!" >> $LF
end

#########################################
# echo successful message
#########################################
echo "Preprocessing Completed!" >> $LF


##########################################
# clean up intermediate files 
##########################################
if ( $nocleanup != 1) then
foreach file (`cat $cleanup_file`)
    rm $file
end
endif
exit 0

##########################################
# Parse Arguments 
##########################################

parse_args:
set cmdline = "$argv";
while( $#argv != 0 )
    set flag = $argv[1]; shift;

    switch($flag)
        #subject name
        case "-s":
            if ( $#argv == 0 ) goto arg1err;
            set subject = $argv[1]; shift;
            breaksw

        #path to subject's folder
        case "-fmrinii":
            if ( $#argv == 0 ) goto arg1err;
            set fmrinii_file = $argv[1]; shift;
            breaksw

        #anatomical ID
        case "-anat_s":
            if ($#argv == 0) goto arg1err;
            set anat = $argv[1]; shift;
            breaksw

        #directory to recon-all folder
        case "-anat_d":
            if ($#argv == 0) goto arg1err;
            set anat_dir = $argv[1]; shift;
            setenv SUBJECTS_DIR $anat_dir
            breaksw

        #output directory to save out preprocess results
        case "-output_d":
            if ( $#argv == 0 ) goto arg1err;
            set output_dir = $argv[1]; shift;
            breaksw

        #configuration file
        case "-config":
            if ( $#argv == 0 ) goto arg1err;
            set config = $argv[1]; shift;
            breaksw

        #BOLD stem
        case "-stem":
            if ( $#argv == 0 ) goto arg1err;
            set BOLD_stem = "_$argv[1]"; shift;
            breaksw

        case "-nocleanup":
            set nocleanup = 1;
            breaksw

        default:
            echo ERROR: Flag $flag unrecognized.
            echo $cmdline
            exit 1
            breaksw
    endsw
end
goto parse_args_return;

##########################################
# Check Parameters
##########################################

check_params:
if ( "$subject" == "" ) then
    echo "ERROR: subject not specified"
    exit 1;
endif

if ( "$fmrinii_file" == "" ) then
    echo "ERROR: subject's fmri nifti file list not specified"
    exit 1;
endif

# check whether input for -fmrinii is nifti file or text file
if (( `expr "$fmrinii_file" : '.*\.nii\.gz$'` ) || ( `expr "$fmrinii_file" : '.*\.nii$'` )) then 
    set nii_file_input = 1
endif

if ( "$anat" == "" ) then
    echo "ERROR: subject's anatomical ID not specified"
    exit 1;
endif

if ( "$anat_dir" != "$SUBJECTS_DIR" ) then
    echo "ERROR: subject's anatomical data directory doesn't match enviromental variable SUBJECTS_DIR!"
    echo "ERROR: anat_dir = $anat_dir"
    echo "ERROR: SUBJECTS_DIR = $SUBJECTS_DIR"
    exit 1;
endif

if ( "$output_dir" == "" ) then
    echo "ERROR: preprocess output directory not specified"
    exit 1;
endif

if ( "$config" == "" ) then
    echo "ERROR: subject's configuration file not specified"
    exit 1;

endif
goto check_params_return;

##########################################
# ERROR message
##########################################

arg1err:
  echo "ERROR: flag $flag requires one argument"
  exit 1
  
#####################################
# Help
#####################################
BEGINHELP

NAME:
    CBIG_preproc_fMRI_preprocess.csh

DESCRIPTION:
    The pipeline processes fMRI data and projects the data to 
    (1) FreeSurfer fsaverage5, fsaverage6 space
    (2) FreeSurfer nonlinear volumetric space
    (3) FSL MNI152 1mm, MNI152 2mm space.
        
    The pipeline proceeds sequentially as follows (default order), you can change the order and parameters 
    by changing the config file:
    (1) [CBIG_preproc_skip -skip 4] 
        skips first 4 frames of resting data. 
    (2) [CBIG_preproc_fslslicetimer -slice_timing <st_file>] or [CBIG_preproc_fslslicetimer -slice_order <so_file>]
        does slice time correction using FSL slicetimer. If the user does not pass in the slice acquisition direction 
        -direction <direction>, this step will use "Siemens" acquisition direction Superior-Inferior as default. 
        If the direction is Right-Left, <direction> should be 1 representing x axis.
        If the direction is Anterior-Posterior, <direction> should be 2 representing y axis.
        If the direction is Superior-Inferior, <direction> should be 3 representing z axis.
        We recommend the users to pass in the slice timing information <st_file> instead of slice order <so_file>
        (especially for multi-band data). The slice timing file can contain multiple columns (separated by a space) 
        if the slice timing is different for different runs (checkout this example: example_slice_timing.txt).
        If the user does not pass in both the slice timing file <st_file> and the slice order file <so_file>, 
        this step will use "Siemens" ordering as default:
        if the number of slices is odd, the ordering is 1, 3, 5, ..., 2, 4, 6, ...; 
        if the number of slices is even, the ordering is 2, 4, 6, ..., 1, 3, 5, ....
    (3) [CBIG_preproc_fslmcflirt_outliers -FD_th 0.2 -DV_th 50 -discard-run 50 -rm-seg 5 -spline_final] 
        does motion correction with spline interpolation and calculates Framewise Displacement and DVARS, 
        then generates a vector indicating censored frames (1:keep 0:censored). This step throws away the
        runs where the number of outliers are more than the threshold set by -discard-run option.
    (4) [CBIG_spatial_distortion_correction -fpm "oppo_PED" -j_minus <j_minus_image> -j_plus <j_plus_image>\
        -j_minus_trt <j_minus_total_readout_time> -j_plus_trt <j_plus_total_readoutime>\
        -ees <effective_echo_spacing> -te <TE>]
        or
        [CBIG_preproc_spatial_distortion_correction -fpm "mag+phasediff"\ 
        -m <magnitude_image> -p <phase_difference_image> -delta <phase_image_TE_difference> -ees <effective_echo_spacing>\
        -te <TE>]
        corrects for spatial distortion caused by susceptibilty-induced off-resonance field. This step requires fieldmap
        images (either in magnitude and phase differnce form or opposite phase encoding directions form) and assumes that 
        the functional image has gone through motion correction. Note that in the case of opposite phase ecnoding 
        direction, please ensures that FSL version is 5.0.10, the outputs may otherwise be erroneous; also, this script 
        currently only supports phase encoding directions along AP (j-) and PA (j) directions. For more details, please 
        refer to our spatial distortion correction READEME here: $CBIG_CODE_DIR/stable_projects/preprocessing/ 
        CBIG_fMRI_Preproc2016/spatial_distortion_correction_readme.md
    (5) [CBIG_preproc_multiecho_denoise -echo_time 12,30.11,48.22]
        Apply optimal combination of different echos and denoising by ME-ICA method using TEDANA. This step needs 
        echo times for each echo in order. For more details, please refer to our readme for multi-echo preprcessing: 
        $CBIG_CODE_DIR/stable_projects/preprocessing/CBIG_fMRI_Preproc2016/multi_echo_tedana_readme.md
    (6) [CBIG_preproc_bbregister] 
        a) Do bbregister with fsl initialization for each run. 
        b) Choose the best run with lowest bbr cost. Apply the registration matrix of the best run to 
        other runs and recompute the bbr cost. If the cost computed using best run registration is 
        lower than the cost computed using the original registration generated in step a), use the best 
        run registration as the final registration of this run. Otherwise, use the original registration.
        c) To save disk space, it also generates a loose whole brain mask and applies it to input fMRI 
        volumes. If you follow the default config file, then the input fMRI volumes are motion corrected volumes.
    (7) [CBIG_preproc_regress -whole_brain -wm -csf -motion12_itamar -detrend_method detrend -per_run -censor \
         -polynomial_fit 1] 
        regresses out motion, whole brain, white matter, ventricle, linear regressors for each run seperately. 
        If the data have censored frames, this function will first estimate the beta coefficients ignoring the 
        censored frames and then apply the beta coefficients to all frames to regress out those regressors.  
    (8) [CBIG_preproc_censor -nocleanup -max_mem NONE] 
        removes (ax+b) trend of censored frames, then does censoring with interpolation. For interpolation method, 
        please refer to (Power et al. 2014). In our example_config.txt, "-max_mem NONE" means the maximal memory usage 
        is not specified, the actual memory usage will vary according to the size of input fMRI file (linearly 
        proportional). If you want to ensure the memory usage does not exceed 10G, for example, you can pass in 
        "-max_mem 9".
    (9) [CBIG_preproc_despiking]
        uses AFNI 3dDespike to conduct despiking. This function can be used to replace censoring interpolation step (6),  
        depending on the requirement of users.
    (10) [CBIG_preproc_bandpass -low_f 0.009 -high_f 0.08 -detrend] 
        does bandpass filtering with passband = [0.009, 0.08] (boundaries are included). This step applies FFT 
        on timeseries and cuts off the frequencies in stopbands (rectanguluar filter), then performs inverse FFT 
        to get the result.
    (11) [CBIG_preproc_QC_greyplot -FD_th 0.2 -DV_th 50]
        creates greyplots for quality control purpose. Greyplots contain 4 subplots: framewise displacement trace (with 
        censoring threshold), DVARS trace (with censoring threshold), global signal, and grey matter timeseries.
        In our default config file, we only create the grey plots just before projecting the data to surface/volumetric 
        spaces because our aim is to see how much artifacts are there after all data cleaning steps. If the users want 
        to compare the greyplots after different steps, they can insert this step multiple times in the config file 
        (but must be after CBIG_preproc_bbregister step because it needs intra-subject registration information to 
        create masks).
    (12) [CBIG_preproc_native2fsaverage -proj fsaverage6 -down fsaverage5 -sm 6] 
        projects fMRI to fsaverage6, smooths it with fwhm = 6mm and downsamples it to fsaverage5.
    (13) [CBIG_preproc_FC_metrics -Pearson_r -censor -lh_cortical_ROIs_file <lh_cortical_ROIs_file> \
          -rh_cortical_ROIS_file <rh_cortical_ROIs_file>]
        computes FC (functional connectivity) metrics based on both cortical and subcortical ROIs. The cortical ROIs 
        can be passed in by -lh_cortical_ROIs and -rh_cortical_ROIs. The subcortical ROIs are 19 labels extracted 
        from aseg in subject-specific functional space. This function will support for multiple types of FC metrics
        in the future, but currently we only support static Pearson's correlation by using "-Pearson_r" flag. 
        If "-censor" flag is used, the censored frames are ignored when computing FC metrics.
    (14) [CBIG_preproc_native2mni_ants -sm_mask \
          ${CBIG_CODE_DIR}/data/templates/volume/FSL_MNI152_masks/SubcorticalLooseMask_MNI1mm_sm6_MNI2mm_bin0.2.nii.gz \
          -final_mask ${FSL_DIR}/data/standard/MNI152_T1_2mm_brain_mask_dil.nii.gz]
        first, projects fMRI to FSL MNI 2mm space using ANTs registration; second, smooth it by fwhm = 6mm within 
        <sm_mask>; and last, masks the result by <final_mask> to save disk space.
        Caution: if you want to use this step, please check your ANTs software version. There is a bug in early builds 
        of ANTs (before Aug 2014) that causes resampling for timeseries to be wrong. We have tested that our codes 
        would work on ANTs version 2.2.0. 
    (15) [CBIG_preproc_native2mni -down FSL_MNI_2mm -sm 6 -sm_mask <sm_mask> -final_mask <final_mask>] 
        it has the similar functionality as (13) but using FreeSurfer with talairach.m3z, not ANTs. We suggest the 
        users use (13) instead of (14).
        First, this step projects fMRI to FreeSurfer nonlinear space; second, projects the image from FreeSurfer 
        nonlinear space to FSL MNI 1mm space; third, downsamples the image from FSL MNI 1mm space to FSL MNI 2mm space; 
        fourth, smooths it by fwhm = 6mm within <sm_mask>; and last, masks the result by <final_mask> to save disk 
        space.


    Note: this pipeline assumes the user has finished FreeSurfer recon-all T1 preprocessing.

    This pipeline will deoblique and reorient data if needed. 
    Data will be reoriented to RPI (3dinfo), LAS (mri_info).
    This means in freeview:
    - Scroll down coronal, 2nd voxel coordinate decreases
    - Scroll down sagittal, 1st voxel coordinate increases
    - Scroll down axial, 3rd voxel coordinate decreases
     
    Please be aware that T1-T2* registration step must be done before CBIG_preproc_regress and CBIG_preproc_censor. 
    The latter two steps need registration information to create masks.

    To know how to do QC checks, please refer to README.md in the same folder as this script.

   
REQUIRED ARGUMENTS:
    -s  <subject>              : subject ID
    -fmrinii  <fmrinii>        : (1) fmrinii text file or (2) absolute nifti file path
                                (1) fmrinii text file including n+1 columns, the 1st column contains all run numbers, 
                                where n stands for echo number.
                                For single echo case, fmrinii text file should include 2 columns
                                the rest columns specify the absolute path to raw functional nifti files for each echo in
                                corresponding run. An example file is here: 
                                ${CBIG_CODE_DIR}/stable_projects/preprocessing/CBIG_fMRI_Preproc2016/example_fmrinii.txt
                                Example of single echo <fmrinii> content:
                                002 /data/../Sub0015_bld002_rest.nii.gz
                                003 /data/../Sub0015_bld003_rest.nii.gz
                                Example of multi echo <fmrinii> content:
                                001 /data/../Sub0015_bld001_e1_rest.nii.gz /data/../Sub0015_bld001_e2_rest.nii.gz \
                                /data/../Sub0015_bld001_e3_rest.nii.gz
                                002 /data/../Sub0015_bld002_e1_rest.nii.gz /data/../Sub0015_bld002_e2_rest.nii.gz \
                                /data/../Sub0015_bld002_e3_rest.nii.gz
                                (2) absolute nifti file path only support for single run single echo subject. 
                                Input is the absolute nifti file path, and run number set to 001.

    -anat_s  <anat>            : FreeSurfer recon-all folder name of this subject (relative path)
    -anat_d  <anat_dir>        : specify anat directory to recon-all folder (full path), i.e. <anat_dir> contains <anat>
    -output_d  <output_dir>    : output directory to save out preprocess results (full path). This pipeline will create 
                                 a folder named <subject> under <output_dir>. All preprocessing results of this subject 
                                 are stored in <output_dir>/<subject>.
    -config  <config>          : configuration file
                                An example file is here: 
                                ${CBIG_CODE_DIR}/stable_projects/preprocessing/CBIG_fMRI_Preproc2016/example_config.txt
                                Example of <config> content (Remind: this is not a full config file):
                                
                                ###CBIG fMRI preprocessing configuration file
                                ###The order of preprocess steps is listed below
                                CBIG_preproc_skip -skip 4
                                CBIG_preproc_fslslicetimer -slice_timing \
${CBIG_CODE_DIR}/stable_projects/preprocessing/CBIG_fMRI_Preproc2016/example_slice_timing.txt
                                CBIG_preproc_fslmcflirt_outliers -FD_th 0.2 -DV_th 50 -discard-run 50 -rm-seg 5

                                The symbol # in the config file also means comment, you can write anything you want if 
                                you begin a line with #. Each line of the config file representing a function or step 
                                of our preprocessing pipeline, the order of the step representing our preprocessing 
                                order, so it is easy to change the order of your preprocessing according to changing 
                                the config file. In this config file, you can also specify the option of each function. 
                                For example, if you want to skip first 4 frames of the fMRI data, you can add the 
                                option (-skip 4) behind the CBIG_preproc_skip. For further details about these options, 
                                you can use option (-help) for each function, such as (CBIG_preproc_skip -help).

OPTIONAL ARGUMENTS:
    -stem                      : set initial BOLD stem, default set to be "rest"
    -help                      : help
    -version                   : version
    -nocleanup                 : do not delete intermediate volumes

OUTPUTS: 
    CBIG_fMRI_preprocess.csh will create the directory <output_dir>/<subject> as specified in the options. Within the 
    <output_dir>/<subject> folder, there are multiple folders:

    1. surf folder contains the intermediate and final preprocessed fMRI data on the surface. 
        For example, 
        surf/lh.Sub0033_Ses1_bld002_rest_skip4_stc_mc_resid_interp_FDRMS0.2_DVARS50_bp_0.009_0.08_fs6_sm6_fs5.nii.gz 
        is bold data from run 002 ("bld002") of subject "Sub0033_Ses1" that has been projected to the left hemisphere 
        ("lh"). The remaining descriptors in the filename describe the order of the processing steps. In particular,
        "rest" = resting state fmri
        "skip" = first four frames have been removed for T1 equilibrium
        "stc" = slice time correction
        "mc" = motion correction
        "resid" = regression of motion, whole brain, ventricular, white matter signals (standard fcMRI preprocessing)
        "interp_FDRMS0.2_DVARS50" = do interpolation for the censored frames defined by Framewise Displacement > 0.2,
                                    DVARS > 50, 
        "bp_0.009_0.08" = bandpass filtering with passband = [0.009, 0.08] (boundary inclusive).
        "fsaverage6" = data projected to fsaverage6 surface
        "sm6" = data smoothed with a FWHM = 6mm kernel on the surface
        "fsaverage5" = data downsampled to fsaverage5 surface

    2. vol folder contains the intermediate and final preprocessed fMRI data in the MNI152 and freesurfer nonlinear 
       volumetric spaces.
        For example, 
        a. 
        vol/Sub0033_Ses1_bld002_rest_skip4_stc_mc_residc_interp_FDRMS0.2_DVARS50_bp_0.009_0.08_MNI2mm_sm6_finalmask.nii.gz
        is the BOLD data of run 002 ("bld002") in subject "Sub0033_Ses1", generated after CBIG_preproc_native2mni_ants 
        step. The remaining descriptors in the filename describe the order of the processing steps. In particular,
        "rest" = resting state fmri
        "skip" = first four frames have been removed for T1 equilibrium
        "stc" = slice time correction
        "mc" = motion correction
        "resid" = regression of motion, whole brain, ventricular, white matter signals (standard fcMRI preprocessing)
        "interp_FDRMS0.2_DVARS50" = do interpolation for the censored frames defined by Framewise Displacement > 0.2, 
                                    DVARS > 50, 
        "bp_0.009_0.08" = bandpass filtering with passband = [0.009, 0.08] (boundary inclusive).
        "MNI2mm" = projecting the data to MNI152 nonlinear 2mm volumetric space by ANTs
        "sm6" = data smoothed with a FWHM = 6mm kernel
        "finalmask" = masking the final image to save space.
        b. 
        vol/Sub0033_Ses1_bld002_rest_skip4_stc_mc_resid_interp_FDRMS0.2_DVARS50_bp_0.009_0.08_FS1mm_MNI1mm_MNI2mm_\
        sm6_finalmask.nii.gz 
        is the BOLD data of run 002 ("bld002") in subject "Sub0033_Ses1", generated after CBIG_preproc_native2mni step. 
        The remaining descriptors in the filename describe the order of the processing steps. In particular,
        "FS1mm" = projection of data to freesurfer nonlinear 1mm volumetric space
        "MNI1mm" = projection of data to MNI152 nonlinear 1mm volumetric space
        "MNI2mm" = downsampling of data to MNI152 nonlinear 2mm volumetric space
        Other stems are same as in subsection a.

    3. logs folder contains all log files for our preprocessing.
        CBIG_fMRI_preprocess.log contains the log info of CBIG_fMRI_preprocess.csh function, which is a wrapper script.
        Similarly, the name of the log file indicates the function, for example, CBIG_preproc_regress.log corresponds 
        to the function CBIG_preproc_regression.csh. Other log files: env.log includes all environment variables; 
        git.log includes the last git commit info; Sub0033_Ses1.bold contains the run numbers of this subject after 
        censoring; cleanup.txt includes all intermediate files that have been deleted, the user can use -nocleanup 
        option to keep these volumes.
       
    4. bold folder contains the intermediate files for each step.
        bold/002 folder contains all intermediate bold volumes of run 002.
        For example, Sub0033_Ses1_bld002_rest_skip4_stc_mc.nii.gz is the volume after skip -> slice-timing correction 
        -> motion correction

        bold/mask folder contains all the fMRI masks.
        For example, Sub0033_Ses1.func.ventricles.nii.gz means that it's a functional ventricle mask for the subject 
        Sub0033_Ses1; Sub0033_Ses1.brainmask.bin.nii.gz means that it's a binarized brainmask for subject Sub0033_Ses1.

        bold/regression folder contains all regressors and lists for the glm regression.
        For example, Sub0033_Ses1_bld002_all_regressors.txt means all regressors of subject Sub0033_Ses1, run 002.

        bold/mc folder contains the output files of fsl_motion_outliers, and some intermediate files when detecting 
        high-motion outliers. For example, Sub0033_Ses1_bld002_rest_skip4_stc_motion_outliers_DVARS is the text file of 
        DVARS value of each frame of Sub0033_Ses1, run 002; Sub0033_Ses1_bld002_rest_skip4_stc_motion_outliers_FDRMS is 
        the text file of FDRMS value of each frame of Sub0033_Ses1, run 002;

    5. qc folder contains all the files that are useful for quality control.
        For example:
        CBIG_preproc_bbregister_intra_sub_reg.cost contains the number of bbregister cost in T1-T2* registration.
        Sub0033_Ses1_bld002_mc_abs.rms, Sub0033_Ses1_bld002_mc_abs_mean.rms, Sub0033_Ses1_bld002_mc_rel.rms, and 
        Sub0033_Ses1_bld002_mc_rel_mean.rms are motion parameters.
        Sub0033_Ses1_bld002_FDRMS0.2_DVARS50_motion_outliers.txt contains the outlier labels of frames (1-keep, 
        0-censored). For introduction of more qc files, please refer to quality_control_readme.md in the same folder of 
        this script.

    6. FC_metrics folder contains all files related to this subject's FC (functional connectivity) metrics.
       It contains three subfolders currently"
       FC_metrics/ROIs contains the 19 subcortical ROIs file;
       FC_metrics/lists contains the input lists for corresponding matlab function;
       FC_metrics/Pearson_r contains the static Pearson's correlation of this subject.
  
EXAMPLE:
    CBIG_preproc_fMRI_preprocess.csh -s Sub0033_Ses1 -output_d $CBIG_TESTDATA_DIR/stable_projects/preprocessing/\
    CBIG_fMRI_Preproc2016/100subjects_clustering/preproc_out -anat_s Sub0033_Ses1_FS -anat_d \
    $CBIG_TESTDATA_DIR/stable_projects/preprocessing/CBIG_fMRI_Preproc2016/100subjects_clustering/recon_all -fmrinii \
    $CBIG_CODE_DIR/stable_projects/preprocessing/CBIG_fMRI_Preproc2016/unit_tests/100subjects_clustering/fmrinii/\
    Sub0033_Ses1.fmrinii -config $CBIG_CODE_DIR/stable_projects/preprocessing/CBIG_fMRI_Preproc2016/unit_tests/\
    100subjects_clustering/prepro.config/prepro.config

Written by CBIG under MIT license: https://github.com/ThomasYeoLab/CBIG/blob/master/LICENSE.md

