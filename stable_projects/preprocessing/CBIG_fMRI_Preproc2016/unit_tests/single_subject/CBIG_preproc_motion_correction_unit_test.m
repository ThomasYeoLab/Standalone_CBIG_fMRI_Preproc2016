classdef CBIG_preproc_motion_correction_unit_test < matlab.unittest.TestCase
    %
    % Target project:
    %                 CBIG_fMRI_Preproc2016
    %
    % Case design:
    %                 This is a supplementry of single subject unit test.
    %                 We use a multiecho subject with muliple runs to test
    %                 the motion correction. This will be run in
    %                 comprehensive unit test only. 
    %
    % Written by XUE Aihuiping and CBIG under MIT license: https://github.com/ThomasYeoLab/CBIG/blob/master/LICENSE.md
    
    methods (Test)
        function test_motion_correction_Case(testCase)
            %% path setting
            addpath(fullfile(getenv('CBIG_CODE_DIR'), 'stable_projects', ...
                'preprocessing', 'CBIG_fMRI_Preproc2016', 'utilities'));
            addpath(fullfile(getenv('CBIG_CODE_DIR'), 'stable_projects', ...
                'preprocessing', 'CBIG_fMRI_Preproc2016', 'unit_tests', 'single_subject'))
            UnitTestDir = fullfile(getenv('CBIG_CODE_DIR'), 'stable_projects',...
                'preprocessing', 'CBIG_fMRI_Preproc2016', 'unit_tests');
            OutputDir = fullfile(UnitTestDir, 'output', 'single_subject_motion_correction');
            load(fullfile(getenv('CBIG_CODE_DIR'), 'unit_tests', 'replace_unittest_flag'));
            
            %create output dir (IMPORTANT)
            if(exist(OutputDir, 'dir'))
                rmdir(OutputDir, 's')
            end
            mkdir(OutputDir);
            
            
            %% call CBIG_fMRI_Preproc2016 single_subject unit test script to generate results
            cmd = [fullfile(UnitTestDir, 'single_subject', ...
                'CBIG_preproc_unit_tests_call_fMRI_preproc_motion_correction.sh'), ' ', OutputDir];
            system(cmd); % this will submit a job to HPC
            
            
            %% we need to periodically check whether the job has finished or not
            cmdout = 1;
            while(cmdout ~= 0)
                cmd = 'ssh headnode "qstat | grep preproc | grep `whoami` | wc -l"';
                [~, cmdout] = system(cmd);
                % after job finishes, cmdout should be 0
                cmdout = str2num(cmdout(1: end-1));
                pause(60); % sleep for 1min and check again
            end
            
            subject_id = 'TMR00032_TMSD';
            runs = {'001', '002'};
            echos = {'e1', 'e2', 'e3'};
            
            if(replace_unittest_flag)
                disp('Replacing single subject multi echo preprocessing unit test results...')
                disp('Make sure that the reference directory and its parent directory have write permission!')
                ref_dir = fullfile(getenv('CBIG_TESTDATA_DIR'), 'stable_projects', 'preprocessing', ...
                    'CBIG_fMRI_Preproc2016', 'single_subject', 'data');
                ref_dir_subject = fullfile(ref_dir,'TMR00032_TMSD');
                output_dir = fullfile(getenv('CBIG_CODE_DIR'), 'stable_projects', 'preprocessing', ...
                    'CBIG_fMRI_Preproc2016', 'unit_tests', 'output', 'single_subject_motion_correction', subject_id);
                if(exist(ref_dir_subject, 'dir'))
                    rmdir(ref_dir_subject, 's')
                end
                movefile(output_dir, ref_dir)
            else
                %% check surf files
                pipe_dir1 = fullfile(getenv('CBIG_TESTDATA_DIR'), 'stable_projects', 'preprocessing', ...
                    'CBIG_fMRI_Preproc2016', 'single_subject', 'data');
                pipe_name1 = 'gt';
                pipe_stem1 = '_rest_skip4_mc_me_residc_interp_FDRMS0.2_DVARS75_bp_0.009_0.08_fs6_sm6_fs5';
                
                pipe_dir2 = OutputDir;
                pipe_name2 = 'user-test';
                pipe_stem2 = '_rest_skip4_mc_me_residc_interp_FDRMS0.2_DVARS75_bp_0.009_0.08_fs6_sm6_fs5';
                
                output_dir = fullfile(OutputDir, 'compare_output');
                
                for i = 1: length(runs)
                    CBIG_preproc_compare_two_pipelines(pipe_dir1, pipe_name1, ...
                        pipe_stem1, pipe_dir2, pipe_name2, pipe_stem2, subject_id, ...
                        runs{i}, output_dir, 'surf');
                    corr_file = fullfile(OutputDir, 'compare_output', subject_id,...
                        runs{i}, 'gt_user-test_corr_surf_stat.txt');
                    corr_result = importdata(corr_file);
                    corr_result = regexp(corr_result{3}, ':', 'split'); % we look at the min corr
                    corr_result = corr_result(2);
                    corr_result = str2num(corr_result{1});
                    assert(corr_result > 0.99, ...
                        sprintf(['surface min_corr of run ' runs{i} ' is less than 0.99! The value is %f \n'], ...
                        corr_result))
                end
                
                
                %% check volume files after motion correction
                pipe_stem1 = '_rest_skip4_mc';
                pipe_stem2 = '_rest_skip4_mc';
                
               
                for i = 1:length(runs)
                    for j = 1:length(echos)
                        disp(['Comparing motion correction results for run ' runs{i} ', ' echos{j} '...'])
                        vol_file1 = fullfile(pipe_dir1, subject_id, 'bold', runs{i}, ...
                            [subject_id '_bld' runs{i} '_' echos{j} pipe_stem1 '.nii.gz']);
                        vol_file2 = fullfile(pipe_dir2, subject_id, 'bold', runs{i}, ...
                            [subject_id '_bld' runs{i} '_' echos{j} pipe_stem2 '.nii.gz']);
                        [corr_vol, vol_size] = CBIG_preproc_compare_two_vols(vol_file1, vol_file2);
                        corr_vol_ex = corr_vol(~isnan(corr_vol));
                        corr_result = min(corr_vol_ex);
                        assert(corr_result > 0.99, ...
                            sprintf(['volume min_corr of run ' runs{i} ', ' echos{j} ...
                            ' ...is less than 0.99! ...The value is %f \n'], corr_result))
                    end
                end
                

                %% check final volume files
                pipe_stem1 = '_rest_skip4_mc_me_residc_interp_FDRMS0.2_DVARS75_bp_0.009_0.08';
                pipe_stem2 = '_rest_skip4_mc_me_residc_interp_FDRMS0.2_DVARS75_bp_0.009_0.08';
                
                for i = 1:length(runs)
                    disp(['Comparing motion correction results for run ' runs{i} '...'])
                    vol_file1 = fullfile(pipe_dir1, subject_id, 'bold', runs{i}, ...
                        [subject_id '_bld' runs{i} pipe_stem1 '.nii.gz']);
                    vol_file2 = fullfile(pipe_dir2, subject_id, 'bold', runs{i}, ...
                        [subject_id '_bld' runs{i} pipe_stem2 '.nii.gz']);
                    [corr_vol, vol_size] = CBIG_preproc_compare_two_vols(vol_file1, vol_file2);
                    corr_vol_ex = corr_vol(~isnan(corr_vol));
                    corr_result = min(corr_vol_ex);
                    assert(corr_result > 0.99, ...
                        sprintf(['volume min_corr of run ' runs{i} ' is less than 0.99! The value is %f \n'], ...
                        corr_result))
                end
                             
            end
            
            % remove intermediate output data (IMPORTANT)
            rmdir(OutputDir, 's');
            rmpath(fullfile(getenv('CBIG_CODE_DIR'), 'stable_projects', ...
                'preprocessing', 'CBIG_fMRI_Preproc2016', 'utilities'));
            rmpath(fullfile(getenv('CBIG_CODE_DIR'), 'stable_projects', ...
                'preprocessing', 'CBIG_fMRI_Preproc2016', 'unit_tests', 'single_subject'))
            
        end
    end
end
