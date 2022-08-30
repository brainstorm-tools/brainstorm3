function hFig = bst_warp_prepare(ChannelFile, Options)
% BST_WARP_PREPARE:  Set up everything for a call to bst_warp (deformation of default anatomy)
% 
% USAGE:  bst_warp_prepare(ChannelFile, Options)
%         bst_warp_prepare(ChannelFile)
% 
% INPUTS:
%     - ChannelFile : Channel file that contains the HeadPoints for the deformation
%     - Options     : Structure of the options
%         |- tolerance    : Percentage of outliers head points, ignored in the calulation of the deformation. 
%         |                 Set to more than 0 when you know your head points have some outliers.
%         |                 If not specified: asked to the user (default 
%         |- isInterp     : If 0, do not do a full interpolation (default: 1)
%         |- isScaleOnly  : If 1, do not perform the full deformation but only a linear scaling in the three directions (default: 0)
%         |- isSurfaceOnly: If 1, do not warp/scale the MRI (default: 0)
%         |- isInteractive: If 0, do not ask anything to the user (default: 1)

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
% Authors: Francois Tadel, 2010-2022

%% ===== CHECK PARAMETERS =====
% Default options
defOptions = struct(...
    'tolerance',     [], ...
    'isInterp',      1, ...
    'isScaleOnly',   [], ...
    'isSurfaceOnly', 0, ...
    'isInteractive', 1);
% Copy default options
if (nargin < 2)
    Options = defOptions;
else
    Options = struct_copy_fields(Options, defOptions, 0);
end
% Additional non-interactive defaults
if ~Options.isInteractive && isempty(Options.isScaleOnly)
    Options.isScaleOnly = 0;
end
if ~Options.isInteractive && isempty(Options.tolerance)
    Options.tolerance = 2;
end
hFig = [];

%% ===== GET DEFAULT ANAT =====
% Start by unloading everything
bst_memory('UnloadAll', 'Forced');
% Progress bar
if Options.isInteractive
    bst_progress('start', 'Warp anatomy', 'Initialization...');
end
% Get default anatomy
sDefSubject = bst_get('Subject', 0);
% If no default anatomy defined: error
if isempty(sDefSubject.Anatomy) || isempty(sDefSubject.Surface) || isempty(sDefSubject.iScalp)
    local_error('Please define a default anatomy before doing this.', Options.isInteractive);
    return;
end
% Load fiducials from default MRI
srcMriFile = file_fullpath(sDefSubject.Anatomy(sDefSubject.iAnatomy).FileName);
srcMriMat = load(srcMriFile, 'SCS', 'Voxsize');
% Check whether fiducials are defined on MRI
if ~isfield(srcMriMat, 'SCS') || ~isfield(srcMriMat.SCS, 'NAS') || isempty(srcMriMat.SCS.NAS) || isempty(srcMriMat.SCS.LPA) || isempty(srcMriMat.SCS.RPA)
    local_error('Fiducials are not defined on default MRI.', Options.isInteractive);
    return;
end


%% ===== GET DIGITIZED HEAD POINTS =====
% Get head points
HeadPoints = channel_get_headpoints(ChannelFile, 1);
% Number of head points
if isempty(HeadPoints)
    nhp = 0;
    destPts = [];
else
    nhp = length(HeadPoints.Loc);
    destPts = HeadPoints.Loc';
end
% Not enough head points
if (nhp < 3)
    local_error('Not enough digitized head points to perform this operation.', Options.isInteractive);
    return;
% Few head points: Scale anatomy ?
elseif Options.isInteractive && isempty(Options.isScaleOnly)
    if (nhp < 70)
        msg = ['There are only ' num2str(nhp) ' digitized head points, this might be ' 10 ...
               'insufficient to deform the default anatomy precisely. ' 10 10 ... 
               'You could instead perform a simple scaling of the anatomy.' 10 10];
    else
        msg = ['Do you want to perform a simple scaling (Scale)' 10 ...
               'or a deformation (Warp) of the default anatomy?' 10 10];
    end
    res = java_dialog('question', msg, 'Warp anatomy', [], {'Warp', 'Scale', 'Cancel'}, 'Scale');
    if isempty(res) || strcmpi(res, 'Cancel')
        bst_progress('stop');
        return;
    elseif strcmpi(res, 'Scale')
        Options.isScaleOnly = 1;
    else
        Options.isScaleOnly = 0;
    end
    if (nhp < 70)
        if ~java_dialog('confirm', ...
              ['There are only ' num2str(nhp) ' digitized head points, this might be ' 10 ...
               'insufficient to deform the default anatomy precisely. ' 10 10 ... 
               'Proceed anyway?'], 'Warp default anatomy');
            bst_progress('stop');
            return;
        end
    end
end


%% ===== GET SUBJECT ANAT =====
% Get study for this channel file
sStudy = bst_get('ChannelFile', ChannelFile);
% Get subject for this channel file
[sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject, 1);
% If there is already an anatomy defined for this subject: warning
if (~isempty(sSubject.Anatomy) || ~isempty(sSubject.Surface))
    if Options.isInteractive
        isOk = java_dialog('confirm', ['Warning: there is already an anatomy defined for this subject.' 10 10 ... 
                                       'This process will delete the existing anatomy, and replace it with ' 10 ...
                                       'a deformed version of the default anatomy.' 10 10 ...
                                       'Delete current subject anatomy ?' 10 10], ...
                                       'Warp default anatomy');
        if ~isOk
            bst_progress('stop');
            return
        end
    end
    % Delete previous surfaces
    if ~isempty(sSubject.Surface)
        SurfaceFiles = cellfun(@(c)file_fullpath(c), {sSubject.Surface.FileName}, 'UniformOutput', 0);
        file_delete(SurfaceFiles, 1);
    end
    if ~isempty(sSubject.Anatomy)
        MriFiles = cellfun(@(c)file_fullpath(c), {sSubject.Anatomy.FileName}, 'UniformOutput', 0);
        file_delete(MriFiles, 1);
    end
end
% Force subject to us default anatomy
s.UseDefaultAnat = 0;
s.Anatomy = [];
s.Surface = [];
% Update subject file
bst_save(file_fullpath(sSubject.FileName), s, 'v7', 1);
% Load default scalp
srcScalpFile = sDefSubject.Surface(sDefSubject.iScalp).FileName;
srcSurf = in_tess_bst(srcScalpFile);
% Display initial surface and head points
if Options.isInteractive
    view_headpoints(ChannelFile, srcScalpFile);
end


%% ===== PROJECT HEAD POINTS =====
% Compute center of mass of the head points, use as the center of projection
if (length(destPts) > 50)
    center = mean(destPts);
else
    center = [0 0 0];
end
% Project digitized head points on the scalp
[destPtsProj, dist] = project_on_surface(srcSurf, destPts, center);


%% ===== REMOVING OUTLIERS =====
if (length(destPts) > 15)
    % Ask the user the tolerance for outliers
    if Options.isInteractive && isempty(Options.tolerance)
        res = java_dialog('input', ['You can choose to ignore the digitized head points that are far ' 10 ...
                                    'away from the scalp in the calculation of the deformation field.' 10 10 ...
                                    'Percentage of head points to ignore [0-100]:'], ...
                                    'Warp default anatomy', [], '2');
        if isempty(res) || isnan(str2double(res))
            bst_progress('stop');
            return
        end
        Options.tolerance = str2double(res) / 100;
    end
    % Remove points that have the maximum distances
    if (Options.tolerance > 0)
        % Number of points to remove
        nRemove = ceil(Options.tolerance * length(destPts));
        disp(['WARP> Remove ' num2str(nRemove) ' points from the head points.']);
        % Sort points by distance to scalp
        [tmp__, iSort] = sort(dist, 1, 'descend');
        iRemove = iSort(1:nRemove);
        % Remove from list of destination points
        destPts(iRemove,:) = [];
        destPtsProj(iRemove,:) = [];
    end
end


%% ===== BUILD TRANSFORMATION =====
% Full deformation
if ~Options.isScaleOnly
    if Options.isInterp
        % Destination landmarks: Fit spherical harmonic to the digitized head points
        fvh = hsdig2fv(destPts, 5, 15/1000, 40*pi/180, 0);
        destPtsParam = fvh.vertices;
        % Source landmarks: Project remeshed digitized surface on scalp
        srcPtsParam = project_on_surface(srcSurf, destPtsParam, center);
    else
        % Destination landmarks: head points
        destPtsParam = destPts;
        % Source landmarks: head points projected on the scalp
        srcPtsParam = destPtsProj;
    end
    
% Scaling only
else
    % Downsample heavily the scalp surface
    [srcFacesParam, srcPtsParam] = reducepatch(srcSurf.Faces, srcSurf.Vertices, 300 / length(srcSurf.Vertices));
    % Destination surface: scale version of the downsampled scalp surface
    destPtsParam = srcPtsParam;
    % Scaling in each direction (x,y,z)
    for dim = 1:3
        % Compute scale factor
        fall = destPts(:,dim) ./ destPtsProj(:,dim);
        fall(isnan(fall) | (fall < .5) | (fall > 1.5)) = [];
        % Apply scale factor
        if ~isempty(fall)
            f = mean(fall);
            destPtsParam(:,dim) = f .* destPtsParam(:,dim);
        end
    end
end


%% ===== WARP =====
% Create list of files to process
SurfaceFiles     = {sDefSubject.Surface.FileName};
SurfaceFilesFull = cellfun(@(c)file_fullpath(c), SurfaceFiles, 'UniformOutput', 0);
MriFiles         = {sDefSubject.Anatomy([sDefSubject.iAnatomy, setdiff(1:length(sDefSubject.Anatomy), sDefSubject.iAnatomy)]).FileName};
MriFilesFull     = cellfun(@(c)file_fullpath(c), MriFiles, 'UniformOutput', 0);
OutputTag        = '_warped';
OutputDir        = bst_fileparts(file_fullpath(sSubject.FileName));
% Main call
bst_warp(destPtsParam, srcPtsParam, SurfaceFilesFull, MriFilesFull, OutputTag, OutputDir, Options.isSurfaceOnly);
           

%% ===== COPY ATLASES =====
% Get list of atlas files (scout files in the default anat folder)
atlasDir = bst_fileparts(file_fullpath(sDefSubject.FileName));
dirScout = dir(bst_fullfile(atlasDir, 'scout_*.mat'));
% Copy all the files file
for i = 1:length(dirScout)
    file_copy(bst_fullfile(atlasDir, dirScout(i).name), bst_fullfile(OutputDir, dirScout(i).name))
end


%% ===== UPDATE DATABASE =====
% Reload subject
db_reload_subjects(iSubject);
% Unload all the surfaces, close all the figures
bst_memory('UnloadAll', 'Forced');
% Get subject again
sSubject = bst_get('Subject', iSubject);
% Display warp head and cortex surfaces
if Options.isInteractive && ~isempty(sSubject.iScalp)
    ScalpFile = sSubject.Surface(sSubject.iScalp).FileName;
    hFig = view_surface(ScalpFile);
end
if Options.isInteractive && ~isempty(sSubject.iCortex)
    CortexFile = sSubject.Surface(sSubject.iCortex).FileName;
    hFig = view_surface(CortexFile);
end

% Close progress bar
if Options.isInteractive
    bst_progress('stop');
end

end    


%% ========================================================================
%  ===== HELPER FUNCTIONS =================================================
%  ========================================================================

%% ===== PROJECT ON SURFACE =====
function [Q, dist] = project_on_surface(sSurf, P, center)
    % Center on (0,0,0)
    P = bst_bsxfun(@minus, P, center);
    sSurf.Vertices = bst_bsxfun(@minus, sSurf.Vertices, center);
    % Project points on surface
    Q = 0 .* P;
    for i = 1:length(P)
        proj = tess_ray_intersect(sSurf.Vertices, sSurf.Faces, [0 0 0], P(i,:))';
        if isempty(proj)
            Q(i,:) = P(i,:);
        elseif (size(proj,1) > 1)
            Q(i,:) = proj(1,:);
        else
            Q(i,:) = proj;
        end
    end
    % Compute the distance between each point and its projection (distance to the scalp surface)
    if (nargout >= 2)
        dist = sum(sqrt((P - Q).^2), 2);
    end
    % Restore center
    Q = bst_bsxfun(@plus, Q, center);
end

%% ===== LOCAL ERROR PROCESSING =====
function local_error(errMsg, isInteractive)
    if isInteractive
        bst_error(errMsg, 'Warp default anatomy', 0);
        bst_progress('stop');
    else
        bst_report('Error', 'process_warp', [], errMsg);
    end
end


