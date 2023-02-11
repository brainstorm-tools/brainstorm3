function MeshStat = fem_meshstats(FemFile)
% FEM_MESHSTATS: Computes and display FEM mesh volume (tetrahedral only).
%
% INPUTS:
%    - FemFile : Relative file path to a Braistorm tetrahedral FEM mesh
% OUTPUTS: 
%    - MeshStat : Mtlab structure that contains all FEM mesh stqtistics (edge length, elem volum and mesh quality)
%
% DEPENDENCIES:
%    This function require the iso2mesh toolbox

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

% Install/load iso2mesh plugin
isInteractive = 1;
[isInstalled, errInstall] = bst_plugin('Install', 'iso2mesh', isInteractive);
if ~isInstalled
    error('Plugin "iso2mesh" not available.');
end

% Get data in database
bst_progress('start', 'Mesh volume', 'Loading file...');
FemFullFile = file_fullpath(FemFile);
femmat = load(FemFullFile);
% Check type of mesh: accept only tetrahedral
if (size(femmat.Elements,2) ~= 4)
    error('This menu is available for tetrahedral meshes only.');
end
% Display results in figures if no variable in output
isDisplay = (nargout == 0);
hFig = [];

% Convert to millimeter for convenience
femmat.Vertices = 1000 .* femmat.Vertices;

% Loop over the tissues
TissueID = unique(femmat.Tissue);
for iTissue = 1:length(TissueID)
    iTissueID = find(femmat.Tissue == TissueID(iTissue));

    % 1. Edges length
    bst_progress('text', sprintf('Computing edges length...  [%d/%d]', iTissue, length(TissueID)));
    Edges = meshedge(femmat.Elements(iTissueID,:));
    n1 = femmat.Vertices(Edges(:,1),:);
    n2 = femmat.Vertices(Edges(:,2),:);
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
    quality = 100 .*meshquality(femmat.Vertices, femmat.Elements(iTissueID,:));
    tstat.MeshQualityMax = max(quality);
    tstat.MeshQualityMin = min(quality);
    tstat.MeshQualityStd = std(quality);
    tstat.MeshQualityMean = mean(quality);

    % 3. Volume of elem
    bst_progress('text', sprintf('Computing volume of elements...  [%d/%d]', iTissue, length(TissueID)));
    voli = elemvolume(femmat.Vertices, femmat.Elements(iTissueID,:));
    tstat.MeshVolumeMax = max(voli);
    tstat.MeshVolumeMin = min(voli);
    tstat.MeshVolumeStd = std(voli);
    tstat.MeshVolumeMean = mean(voli);
    tstat.MeshVolumeSum = sum(voli);

    MeshStat.(femmat.TissueLabels{iTissue}) = tstat;

    % Visualization
    if isDisplay
        bst_progress('text', sprintf('Visualisation... [%d/%d]', iTissue, length(TissueID)));
        hFig(end+1) = figure('Name', ['Mesh stat: ' femmat.TissueLabels{iTissue}], 'NumberTitle', 'off');
        
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

% For all the full Model
% 1. Edges length
bst_progress('text', 'Computing edges length...');
Edges = meshedge(femmat.Elements);
n1 = femmat.Vertices(Edges(:,1),:);
n2 = femmat.Vertices(Edges(:,2),:);
EdgeLength = sqrt((n1(:,1)- n2(:,1)).^2 + (n1(:,2)- n2(:,2)).^2 + (n1(:,3)- n2(:,3)).^2);

MeshStat.FullModel.EdgeLengthMax = max(EdgeLength);
MeshStat.FullModel.EdgeLengthMin = min(EdgeLength);
MeshStat.FullModel.EdgeLengthStd = std(EdgeLength);
MeshStat.FullModel.EdgeLengthMean = mean(EdgeLength);
MeshStat.FullModel.EdgeLengthRMS = rms(EdgeLength);

% 2. Mesh quality: Joe-Liu mesh quality metric (0-100)
bst_progress('text', 'Computing mesh quality...');
quality = 100 .* meshquality(femmat.Vertices, femmat.Elements);
MeshStat.FullModel.MeshQualityMax = max(quality);
MeshStat.FullModel.MeshQualityMin = min(quality);
MeshStat.FullModel.MeshQualityStd = std(quality);
MeshStat.FullModel.MeshQualityMean = mean(quality);

% 3. Volume of elem
bst_progress('text', 'Computing volume of elements...');
voli = elemvolume(femmat.Vertices, femmat.Elements);
MeshStat.FullModel.MeshVolumeMax = max(voli);
MeshStat.FullModel.MeshVolumeMin = min(voli);
MeshStat.FullModel.MeshVolumeStd = std(voli);
MeshStat.FullModel.MeshVolumeMean = mean(voli);
MeshStat.FullModel.MeshVolumeSum = sum(voli);

% Visualization
if isDisplay
    bst_progress('text', 'Visualisation...');
    hFig(end+1) = figure('Name', 'Mesh stat: all tissues combined', 'NumberTitle', 'off');
    
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
    xlabel(sprintf('Element volume (mm3):   mean=%1.2f | std=%1.2f | min=%1.2f | max=%1.2f | sum=%1.2f', MeshStat.FullModel.MeshVolumeMean, MeshStat.FullModel.MeshVolumeStd, MeshStat.FullModel.MeshVolumeMin, MeshStat.FullModel.MeshVolumeMax, MeshStat.FullModel.MeshVolumeSum))

    % Close all the figures at once
    set(hFig, 'DeleteFcn', @(h,ev)delete(setdiff(hFig,h)));
end

bst_progress('stop');
