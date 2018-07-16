function CBIG_Yeo2011_unit_tests_cmp_clusters( your_clusters, cmp_dir )
% CBIG_Yeo2011_unit_tests_cmp_clusters( your_clusters, cmp_dir )
%
% Compare your 100 subjects clustering result with the ground-truth unit
% test result.
% 
% Inputs:
%     - your_clusters
%       Your 17 network clustering result by running the script in the same
%       folder:
%       CBIG_preproc_unit_tests_general_cluster_GSP_80_low_motion+20_w_censor.csh
%     
%     - cmp_dir
%       The directory to store the comparison between your clustering
%       result and the ground truth.
% 
% Written by Jingwei Li and CBIG under MIT license: https://github.com/ThomasYeoLab/CBIG/blob/master/LICENSE.md

input_file = your_clusters;

%% Compute overlap with ground truth
ref_file = '/mnt/eql/yeo1/CBIG_private_unit_tests_data/stable_projects/brain_parcellation/Yeo2011_fcMRI_clustering/100subjects_clustering/clustering/GSP_80_low_mt_20_w_censor_clusters017_scrub.mat';
ref_labels = load(ref_file);
input_labels = load(input_file);

[labels, assign, cost, dice_overlap] = CBIG_HungarianClusterMatch([ref_labels.lh_labels; ref_labels.rh_labels], [input_labels.lh_labels; input_labels.rh_labels]);
disp('Dice overlap:')
disp(num2str(dice_overlap));
if(min(dice_overlap) > 0.99 && cost < -18700)
    disp('Clustering result was replicated.')
else
    disp('ERROR: Clustering result was too different from ground truth.')
end
save(fullfile(cmp_dir, 'your_overlap_with_groundtruth.mat'), 'cost', 'dice_overlap')

%% Draw surface map
ref_file = [getenv('CBIG_CODE_DIR') '/stable_projects/brain_parcellation/Yeo2011_fcMRI_clustering/1000subjects_reference/1000subjects_clusters017_ref.mat'];
ref = load(ref_file);
CBIG_DrawSurfaceMaps(input_labels.lh_labels, input_labels.rh_labels, 'fsaverage5','inflated',0, 17, ref.colors)
set(gcf, 'PaperPositionMode', 'auto')
print(gcf, '-dpng', fullfile(cmp_dir, 'your_clusters017_scrub.png'))
close
gt_fig = '/mnt/eql/yeo1/CBIG_private_unit_tests_data/stable_projects/brain_parcellation/Yeo2011_fcMRI_clustering/100subjects_clustering/clustering/figures/GSP_80_low_mt_20_w_censor_cluster017_scrub.png';
fprintf('\nCheck out this figure: %s.\nCompare it with %s.\n', fullfile(cmp_dir, 'your_clusters017_scrub.png'), gt_fig);

end

