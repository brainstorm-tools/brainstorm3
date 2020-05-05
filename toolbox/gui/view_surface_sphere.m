function [hFig, iDS, iFig] = view_surface_sphere(SurfaceFile)
% VIEW_SURFACE_SPHERE: Display the registration sphere/square for a surface.
%
% USAGE:  [hFig, iDS, iFig] = view_surface(SurfaceFile)
%         [hFig, iDS, iFig] = view_surface(ResultsFile)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2013-2020

% Initialize returned variables
global GlobalData;
hFig = [];
iDS  = [];
iFig = [];

% ===== LOAD DATA =====
% Display progress bar
isProgress = ~bst_progress('isVisible');
if isProgress
    bst_progress('start', 'View surface', 'Loading surface file...');
end
% Get file type
fileType = file_gettype(SurfaceFile);
% If it is a results file
if ismember(fileType, {'results','link'})
    ResultsFile = SurfaceFile;
    ResultsMat = in_bst_results(ResultsFile, 0, 'SurfaceFile');
    SurfaceFile = ResultsMat.SurfaceFile;
else
    ResultsFile = [];
end

% ===== LOAD REGISTRATION =====
% Load vertices
TessMat = in_tess_bst(SurfaceFile);
if isfield(TessMat, 'Reg') && isfield(TessMat.Reg, 'Sphere') && isfield(TessMat.Reg.Sphere, 'Vertices') && ~isempty(TessMat.Reg.Sphere.Vertices)
    sphVertices = double(TessMat.Reg.Sphere.Vertices);
    lrOffset = 0.12;
    surfSmooth = 0.2;
elseif isfield(TessMat, 'Reg') && isfield(TessMat.Reg, 'Square') && isfield(TessMat.Reg.Square, 'Vertices') && ~isempty(TessMat.Reg.Square.Vertices)
    sphVertices = double(TessMat.Reg.Square.Vertices);
    sphVertices(:,3) = 0;   % Add z coordinate 0 for visualization
    lrOffset = 0.155;
    surfSmooth = 0;
else
    bst_error('There is no registered sphere or square available for this surface.', 'View registered sphere/square', 0);
    return;
end

% Get subject MRI file
sSubject = bst_get('SurfaceFile', SurfaceFile);
sMri = in_mri_bst(sSubject.Anatomy(1).FileName);
% Convert: FreeSurfer RAS coord => Voxel
mriSize = size(sMri.Cube(:,:,:,1)) / 2;
sphVertices = bst_bsxfun(@plus, sphVertices .* 1000, mriSize);
% Convert: Voxel => SCS
sphVertices = cs_convert(sMri, 'voxel', 'scs', sphVertices);


% Detect the two hemispheres
[ir, il, isConnected] = tess_hemisplit(TessMat);
% If there is a Structures atlas with left and right hemispheres: split in two spheres
if ~isempty(ir) && ~isempty(il) && ~isConnected
    sphVertices(il,2) = sphVertices(il,2) + lrOffset;
    sphVertices(ir,2) = sphVertices(ir,2) - lrOffset;
end

% ===== DISPLAY SURFACE =====
% Display surface only
if isempty(ResultsFile)
    TessMat.Vertices = sphVertices;
    [hFig, iDS, iFig] = view_surface_matrix(TessMat);
% Display surface + results
else
    % Open cortex with results
    [hFig, iDS, iFig] = view_surface_data(SurfaceFile, ResultsFile, [], 'NewFigure');
    % Get display structure
    TessInfo = getappdata(hFig, 'Surface');
    % Replace the vertices in the patch
    set(TessInfo.hPatch, 'Vertices', sphVertices);
    % Replace the vertice in the loaded structure
    [sSurf, iSurf] = bst_memory('GetSurface', SurfaceFile);
    % Copy the existing loaded surface
    iSurfNew = length(GlobalData.Surface) + 1;
    GlobalData.Surface(iSurfNew) = GlobalData.Surface(iSurf);
    % Replace the vertice in the loaded structure
    GlobalData.Surface(iSurfNew).Vertices = sphVertices;
    % Change the filename so that it does not overlap with the display of the regular brain
    GlobalData.Surface(iSurfNew).FileName = [GlobalData.Surface(iSurf).FileName, '|reg'];
    % Edit the filename in the TessInfo structure
    TessInfo.SurfaceFile = GlobalData.Surface(iSurfNew).FileName;
    setappdata(hFig, 'Surface', TessInfo);
    % Remove the subject information from the dataset so it doesn't get selected by any other viewing function
    GlobalData.DataSet(iDS).SubjectFile = '';
    GlobalData.DataSet(iDS).StudyFile   = '';
    GlobalData.DataSet(iDS).DataFile    = '';
    GlobalData.DataSet(iDS).ChannelFile = '';
end

% ===== CONFIGURE FIGURE =====
iTess = 1;
% Set transparency
panel_surface('SetSurfaceTransparency', hFig, iTess, 0);
% Force sulci display
panel_surface('SetSurfaceSmooth', hFig, iTess, surfSmooth, 0);
panel_surface('SetShowSulci', hFig, iTess, 1);
% Set figure as current figure
bst_figures('SetCurrentFigure', hFig, '3D');

% Camera basic orientation
figure_3d('SetStandardView', hFig, 'top');
% Make sure to update the Headlight
camlight(findobj(hFig, 'Tag', 'FrontLight'), 'headlight');

% Show figure
set(hFig, 'Visible', 'on');
if isProgress
    bst_progress('stop');
end



