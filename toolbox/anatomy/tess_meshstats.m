function MeshStat = tess_meshstats(tessFile)
% TESS_MESHSTATS: Compute and display statistics for:
%  - Surface triangular meshes, and
%  - Volume tetrahedral meshes
%
% INPUTS:
%    - SurfaceFile : Relative or Full file path to a Braistorm surface file, either:
%                    - triangular: head, skull, cortex, etc. Or
%                    - tetrahedral: FEM mesh
%
% OUTPUTS: 
%    - MeshStat : Matlab structure that contains all mesh statistics:
%                 (edge length, elem volum/Face surface and mesh quality)
%
% DEPENDENCIES:
%    This function requires the iso2mesh toolbox
%    This function replaces fem_meshstats, extends support to triangular meshes
%
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Takfarinas Medani, Francois Tadel, 2023
%          Takfarinas Medani, 2025

% Install/load iso2mesh plugin
isInteractive = 1;
[isInstalled, errMsg] = bst_plugin('Install', 'iso2mesh', isInteractive);
if ~isInstalled
    error(['Could not install or load plugin: iso2mesh' 10 errMsg]);
end

% Get data in database
bst_progress('start', 'Mesh statistics', 'Loading file...');
FullFile = file_fullpath(tessFile);
tessData = load(FullFile);

% Type of mesh
if isfield(tessData, 'Faces')
    % Check type of mesh: accept only tetrahedral
    if (size(tessData.Vertices, 2) ~= 3)
        error('This option is available for surface triangular meshes only.');
    end
    meshType = 'surface_triangle';
    tessData.Elements = tessData.Faces; % adapting the variable
elseif isfield(tessData, 'Elements')
    % Check type of mesh: accept only tetrahedral
    if (size(tessData.Elements,2) ~= 4)
        error('This option is available for FEM tetrahedral meshes only.');
    end
    meshType = 'volume_tetrahedron';
    TissueID = unique(tessData.Tissue);
end

% Display results in figures if no variable in output
isDisplay = (nargout == 0);
hFig = [];

% Convert to millimeter for convenience
tessData.Vertices = 1000 .* tessData.Vertices;
% This loop is only for FEM mesh with multiple tissues
if strcmpi(meshType, 'volume_tetrahedron') && (length(TissueID) > 1)
    % Loop over the tissues
    for iTissue = 1:length(TissueID)
        iTissueID = find(tessData.Tissue == TissueID(iTissue));

        % 1. Edges length
        bst_progress('text', sprintf('Computing edges length...  [%d/%d]', iTissue, length(TissueID)));
        Edges = meshedge(tessData.Elements(iTissueID,:));
        n1 = tessData.Vertices(Edges(:,1),:);
        n2 = tessData.Vertices(Edges(:,2),:);
        EdgeLength = sqrt((n1(:,1)- n2(:,1)).^2 + (n1(:,2)- n2(:,2)).^2 + (n1(:,3)- n2(:,3)).^2);

        tstat.EdgeLengthMax = max(EdgeLength);
        tstat.EdgeLengthMin = min(EdgeLength);
        tstat.EdgeLengthStd = std(EdgeLength);
        tstat.EdgeLengthMean = mean(EdgeLength);
        tstat.EdgeLengthRMS = rms(EdgeLength);

        % 2. Mesh quality: Joe-Liu mesh quality metric (0-1)
        %  quality: a vector of the same length as size(elem,1), with
        %            each element being the Joe-Liu mesh quality metric (0-1) of
        %            the corresponding element. A value close to 1 represents
        %            higher mesh quality (1 means equilateral tetrahedron);
        %            a value close to 0 means nearly degenerated element.
        bst_progress('text', sprintf('Computing mesh quality...  [%d/%d]', iTissue, length(TissueID)));
        quality = 100 .*meshquality(tessData.Vertices, tessData.Elements(iTissueID,:));
        tstat.MeshQualityMax = max(quality);
        tstat.MeshQualityMin = min(quality);
        tstat.MeshQualityStd = std(quality);
        tstat.MeshQualityMean = mean(quality);

        % 3. Volume of elem
        bst_progress('text', sprintf('Computing volume of elements...  [%d/%d]', iTissue, length(TissueID)));
        voli = elemvolume(tessData.Vertices, tessData.Elements(iTissueID,:));
        tstat.MeshVolumeMax = max(voli);
        tstat.MeshVolumeMin = min(voli);
        tstat.MeshVolumeStd = std(voli);
        tstat.MeshVolumeMean = mean(voli);
        tstat.MeshVolumeSum = sum(voli);

        MeshStat.(tessData.TissueLabels{iTissue}) = tstat;

        % Visualization
        if isDisplay
            bst_progress('text', sprintf('Visualisation... [%d/%d]', iTissue, length(TissueID)));
            hFig(end+1) = figure('Name', ['Mesh statistics: ' tessData.TissueLabels{iTissue}], 'NumberTitle', 'off');

            nbins = 30;
            subplot(3,1,1)
            histogram(EdgeLength,nbins);
            xlabel(sprintf('Edge length (mm):   mean=%1.2f | std=%1.2f | min=%1.2f | max=%1.2f', tstat.EdgeLengthMean, tstat.EdgeLengthStd, tstat.EdgeLengthMin, tstat.EdgeLengthMax))
            drawnow

            subplot(3,1,2)
            histogram(quality,nbins);
            xlabel(sprintf('Mesh quality (%%):   mean=%1.2f | std=%1.2f | min=%1.2f | max=%1.2f', tstat.MeshQualityMean, tstat.MeshQualityStd, tstat.MeshQualityMin, tstat.MeshQualityMax))
            drawnow

            subplot(3,1,3)
            histogram(voli,nbins);
            xlabel(sprintf('Element volume (mm3):   mean=%1.2f | std=%1.2f | min=%1.2f | max=%1.2f | sum=%1.2f', tstat.MeshVolumeMean, tstat.MeshVolumeStd, tstat.MeshVolumeMin, tstat.MeshVolumeMax, tstat.MeshVolumeSum))
            drawnow
        end
    end
end

% For all the full Model
% 1. Edges length
bst_progress('text', 'Computing edges length...');
Edges = meshedge(tessData.Elements);
n1 = tessData.Vertices(Edges(:,1),:);
n2 = tessData.Vertices(Edges(:,2),:);
EdgeLength = sqrt((n1(:,1)- n2(:,1)).^2 + (n1(:,2)- n2(:,2)).^2 + (n1(:,3)- n2(:,3)).^2);

MeshStat.FullModel.EdgeLengthMax = max(EdgeLength);
MeshStat.FullModel.EdgeLengthMin = min(EdgeLength);
MeshStat.FullModel.EdgeLengthStd = std(EdgeLength);
MeshStat.FullModel.EdgeLengthMean = mean(EdgeLength);
MeshStat.FullModel.EdgeLengthRMS = rms(EdgeLength);

% 2. Mesh quality: Joe-Liu mesh quality metric (0-100)
bst_progress('text', 'Computing mesh quality...');
quality = 100 .* meshquality(tessData.Vertices, tessData.Elements);
MeshStat.FullModel.MeshQualityMax = max(quality);
MeshStat.FullModel.MeshQualityMin = min(quality);
MeshStat.FullModel.MeshQualityStd = std(quality);
MeshStat.FullModel.MeshQualityMean = mean(quality);

% 3. Volume/Area of elem/face
switch meshType
    case 'surface_triangle'
        strProgress = 'Computing area of faces...';
        measureUnit = 'mm2';
        measureType = 'Triangle Face Area';
        fieldName   = 'MeshArea';

    case 'volume_tetrahedron'
        strProgress = 'Computing volume of elements...';
        measureUnit = 'mm3';
        measureType = 'Tetra Element Volume';
        fieldName   = 'MeshVolume';
end
bst_progress('text', strProgress);
voli = elemvolume(tessData.Vertices, tessData.Elements); % can be either volume or area
MeshStat.FullModel.([fieldName 'Max']) = max(voli);
MeshStat.FullModel.([fieldName 'Min']) = min(voli);
MeshStat.FullModel.([fieldName 'Std']) = std(voli);
MeshStat.FullModel.([fieldName 'Mean']) = mean(voli);
MeshStat.FullModel.([fieldName 'Sum']) = sum(voli);

if (meshType == 1)
    % 4. Add the volume of the closed surface fromed by the triangle faces
    % Method 1: %  divergence theorem
    volume = 0;
    for iElem = 1:size(tessData.Elements, 1)
        v1 = tessData.Vertices(tessData.Elements(iElem,1), :);
        v2 = tessData.Vertices(tessData.Elements(iElem,2), :);
        v3 = tessData.Vertices(tessData.Elements(iElem,3), :);
        volume = volume + dot(v1, cross(v2, v3)); 
    end
    volume = abs(volume) / 6 ;
    MeshStat.FullModel.VolumeClosedSurface = volume;
    % % Method 2: %  based on iso2mesh (require generating FEM mesh and the sum elem vol => not recommended )
    % volume = surfvolume(tessData.Vertices,tessData.Elements);
end
% Visualization
if isDisplay
    bst_progress('text', 'Visualisation...');
    strAllTissues = '';
    if strcmpi(meshType, 'volume_tetrahedron')
        strAllTissues = ': all tissues combined';
    end
    hFig(end+1) = figure('Name', ['Mesh statistics' strAllTissues], 'NumberTitle', 'off');
    
    nbins = 30;
    subplot(3,1,1)
    histogram(EdgeLength,nbins);
    xlabel(sprintf('Edge length (mm):   mean=%1.2f | std=%1.2f | min=%1.2f | max=%1.2f', MeshStat.FullModel.EdgeLengthMean, MeshStat.FullModel.EdgeLengthStd, MeshStat.FullModel.EdgeLengthMin, MeshStat.FullModel.EdgeLengthMax))
    drawnow

    subplot(3,1,2)
    histogram(quality,nbins);
    xlabel(sprintf('Mesh quality (%%):   mean=%1.2f | std=%1.2f | min=%1.2f | max=%1.2f', MeshStat.FullModel.MeshQualityMean, MeshStat.FullModel.MeshQualityStd, MeshStat.FullModel.MeshQualityMin, MeshStat.FullModel.MeshQualityMax))
    drawnow
    
    subplot(3,1,3)
    histogram(voli,nbins);
    switch meshType
        case 'surface_triangle'
            xlabel(sprintf('%s (%s):   mean=%1.2f | std=%1.2f | min=%1.2f | max=%1.2f | sum=%1.2f [Enclosed Volume=%1.2f mm3]', measureType, measureUnit, MeshStat.FullModel.([fieldName 'Mean']), MeshStat.FullModel.([fieldName 'Std']),...
                MeshStat.FullModel.([fieldName 'Min']), MeshStat.FullModel.([fieldName 'Max']), MeshStat.FullModel.([fieldName 'Sum']), MeshStat.FullModel.VolumeClosedSurface))

        case 'volume_tetrahedron'
            xlabel(sprintf('%s (%s):   mean=%1.2f | std=%1.2f | min=%1.2f | max=%1.2f | sum=%1.2f', measureType, measureUnit, MeshStat.FullModel.([fieldName 'Mean']), MeshStat.FullModel.([fieldName 'Std']),...
                MeshStat.FullModel.([fieldName 'Min']), MeshStat.FullModel.([fieldName 'Max']), MeshStat.FullModel.([fieldName 'Sum'])))
    end
% Close all the figures at once
set(hFig, 'DeleteFcn', @(h,ev)delete(setdiff(hFig,h)));
end

bst_progress('stop');