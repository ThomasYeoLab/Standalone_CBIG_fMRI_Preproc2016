function CBIG_DrawSurfaceMapsWithBoundary(lh_data, rh_data, lh_labels, rh_labels, mesh_name, surf_type, min_thresh, max_thresh, colors)

% CBIG_DrawSurfaceMapsWithBoundary(lh_data, rh_data, lh_labels, rh_labels, mesh_name, surf_type, min_thresh, max_thresh, colors)
%
% This function visualizes lh_data and rh_data with boundary defined 
% by a parcellation lh_labels, rh_labels in freesurfer space Threshold 
% can be defined by 
% min_thresh and max_thresh.
%
% Input:
%      -lh_data, rh_data: 
%       data of left/right hemisphere. Nx1 vector for each, 
%       N = # of vertices in mesh_name.
%      
%      -lh_labels, rh_labels:
%       parcellation of data of left/right hemisphere. Nx1 vector for each, 
%       N = # of vertices in mesh_name.
%
%      -mesh_name:
%       Freesurfer mesh structure. For example, 'fsaverage5'.
%
%      -surf_type:
%       Freesurfer surface template. Can be 'inflated', 'sphere', or
%       'white'.
%
%      -min_thresh, max_thresh:
%       min and max threshold for lh_data and rh_data. If they are not
%       given, then there is no threshold.
%
%      -colors:
%       color map for visualizetion. A Lx3 matrix, where L is the number of
%       different colors for lh_data and rh_data. Each row is the R, G, B
%       value. If colors is not given, visualization color will be defined
%       by default Matlab colormap.
%
% Example:
% CBIG_DrawSurfaceMapsWithBoundary(lh_data, rh_data, lh_labels,rh_labels,'fsaverage5','inflated');
%
% Written by CBIG under MIT license: https://github.com/ThomasYeoLab/CBIG/blob/master/LICENSE.md


if(~exist('mesh_name', 'var'))
   mesh_name = 'fsaverage'; 
end

if(~exist('surf_type', 'var'))
   surf_type = 'inflated'; 
end

pos = [0.1 0.58 0.16 0.34; ...
    0.4 0.58 0.16 0.34; ...
    0.7 0.80 0.16 0.14; ...
    0.7 0.58 0.16 0.14; ...
    0.1 0.11 0.16 0.34; ...
    0.4 0.11 0.16 0.34; ...
    0.7 0.33 0.16 0.14; ...
    0.7 0.11 0.16 0.14];

h = figure; gpos = get(h, 'Position');
gpos(3) = 1200; gpos(4) = 600; set(h, 'Position', gpos);
for hemis = {'lh' 'rh'}
    
    hemi = hemis{1};
    mesh = CBIG_ReadNCAvgMesh(hemi, mesh_name, surf_type, 'cortex');
    non_cortex = find(mesh.MARS_label == 1);  
    
    if(strcmp(hemi, 'lh'))
        data   = lh_data;
        labels = lh_labels;
    elseif(strcmp(hemi, 'rh'))
        data   = rh_data;
        labels = rh_labels;
    end

    % convert to row vector
    if(size(data, 1) ~= 1)
       data = data';  
    end
    
    if(size(labels, 1) ~= 1)
       labels = labels';  
    end
    
    % resample
    if(size(mesh.vertices, 2) ~= length(data)) % need to resample!
        if(length(data) == 10242)
            from_mesh = CBIG_ReadNCAvgMesh(hemi, 'fsaverage5', 'sphere', 'cortex');
            target_mesh = CBIG_ReadNCAvgMesh(hemi, mesh_name, 'sphere', 'cortex');
            data   = MARS_linearInterpolate(target_mesh.vertices, from_mesh, data);
            labels = MARS_NNInterpolate(target_mesh.vertices, from_mesh, labels);
        else
            error(['Not handling ' num2str(length(data)) ' vertices']);
        end
    end
    
    % threshold
    if(exist('min_thresh', 'var'))
       data(data < min_thresh) = min_thresh;
       data(data > max_thresh) = max_thresh;
       data(non_cortex(1)) = min_thresh;
       data(non_cortex(2)) = max_thresh;
    end
    
    % compute boundary
    BoundaryVec = zeros(length(labels), 1);
    maxNeighbors = size(mesh.vertexNbors, 1);
    for i = 1:length(labels)
        label_vertex = int32(labels(i));
        
        for k = 1:maxNeighbors
            v_neighbor = mesh.vertexNbors(k, i);
            if(v_neighbor ~= 0 && int32(labels(v_neighbor)) ~= label_vertex)
                BoundaryVec(i) = 1;
            end
        end
    end
    data(BoundaryVec == 1) = max(data);
    
    if(strcmp(hemi, 'lh'))
        subplot('Position', pos(1, :)); TrisurfMeshData(mesh, data); shading interp; 
        view(-90, 0); axis off; zoom(1.85);
        subplot('Position', pos(2, :)); TrisurfMeshData(mesh, data); shading interp; 
        view(90, 0); axis off; zoom(1.85);
        subplot('Position', pos(3, :)); TrisurfMeshData(mesh, data); shading interp; 
        view(90, 90); axis off; zoom(3.3);
        subplot('Position', pos(8, :)); TrisurfMeshData(mesh, data); shading interp; 
        view(90, -90); axis off; zoom(3.3);
    else
        subplot('Position', pos(5, :)); TrisurfMeshData(mesh, data); shading interp; 
        view(90, 0); axis off; zoom(1.85);
        subplot('Position', pos(6, :)); TrisurfMeshData(mesh, data); shading interp; 
        view(-90, 0); axis off; zoom(1.85);
        subplot('Position', pos(4, :)); TrisurfMeshData(mesh, data); shading interp; 
        view(90, 90); axis off; zoom(3.3);
        subplot('Position', pos(7, :)); TrisurfMeshData(mesh, data); shading interp; 
        view(90, -90); axis off; zoom(3.3);
    end
end

if(exist('colors', 'var'))
    colormap(colors/max(colors(:))); 
end

if(exist('min_thresh', 'var'))
    colorbar('horiz', 'Position', [0.28 0.5 0.1 0.02]);
    %colorbar('horiz', 'Position', [0.28 0.5 0.1 0.02], 'XTick', [min_thresh max_thresh], ...
    %    'XTickLabel', {num2str(min_thresh, '%0.2g') num2str(max_thresh, '%0.2g')});
end
