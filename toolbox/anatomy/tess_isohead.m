function [HeadFile, iSurface] = tess_isohead(iSubject, nVertices, erodeFactor, fillFactor, bgLevel, Comment)
% TESS_GENERATE: Reconstruct a head surface based on the MRI, based on an isosurface
%
% USAGE:  [HeadFile, iSurface] = tess_isohead(iSubject, nVertices=10000, erodeFactor=0, fillFactor=2, bgLevel=GuessFromHistorgram, Comment)
%         [HeadFile, iSurface] = tess_isohead(MriFile,  nVertices=10000, erodeFactor=0, fillFactor=2, bgLevel=GuessFromHistorgram, Comment)
%         [Vertices, Faces]    = tess_isohead(sMri,     nVertices=10000, erodeFactor=0, fillFactor=2)
%
% If input is loaded MRI structure, no surface file is created and the surface vertices and faces are returned instead.

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
% Authors: Francois Tadel, 2012-2022

%% ===== PARSE INPUTS =====
% Initialize returned variables
HeadFile = [];
iSurface = [];
isSave = true;
% Parse inputs
if (nargin < 6)
    if nargin == 5
        % Handle legacy call: tess_isohead(iSubject, nVertices, erodeFactor, fillFactor, Comment)
        if ischar(bgLevel)
            Comment = bgLevel;
            bgLevel = [];
        % Parameter 'bgLevel' is provided: tess_isohead(iSubject, nVertices, erodeFactor, fillFactor, bgLevel)
        else
            Comment = [];
        end
    % Call tess_isohead(iSubject, nVertices, erodeFactor, fillFactor)
    else
        bgLevel = [];
        Comment = [];
    end
end
% MriFile instead of subject index
sMri = [];
if ischar(iSubject)
    MriFile = file_short(iSubject);
    [sSubject, iSubject] = bst_get('MriFile', MriFile);
elseif isnumeric(iSubject)
    % Get subject
    sSubject = bst_get('Subject', iSubject);
    MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
elseif isstruct(iSubject)
    sMri = iSubject;
    MriFile = sMri.FileName;
    [sSubject, iSubject] = bst_get('MriFile', MriFile);
    % Don't save a surface file, instead return surface directly.
    isSave = false;  
else
    error('Wrong input type.');
end

%% ===== LOAD MRI =====
isProgress = ~bst_progress('isVisible');
if isempty(sMri)
    % Load MRI
    bst_progress('start', 'Generate head surface', 'Loading MRI...');
    sMri = bst_memory('LoadMri', MriFile);
    if isProgress
        bst_progress('stop');
    end
end
% Save current scouts modifications
panel_scout('SaveModifications');
% If subject is using the default anatomy: use the default subject instead
if sSubject.UseDefaultAnat
    iSubject = 0;
end
% Check layers
if isempty(sSubject.iAnatomy) || isempty(sSubject.Anatomy)
    bst_error('The generate of the head surface requires at least the MRI of the subject.', 'Head surface', 0);
    return
end
% Check that everything is there
if ~isfield(sMri, 'Histogram') || isempty(sMri.Histogram) || isempty(sMri.SCS) || isempty(sMri.SCS.NAS) || isempty(sMri.SCS.LPA) || isempty(sMri.SCS.RPA)
    bst_error('You need to set the fiducial points in the MRI first.', 'Head surface', 0);
    return
end
% Guess background level
if isempty(bgLevel)
    bgLevel = sMri.Histogram.bgLevel;
end

%% ===== ASK PARAMETERS =====
% Ask user to set the parameters if they are not set
if (nargin < 4) || isempty(erodeFactor) || isempty(nVertices)
    res = java_dialog('input', {'Number of vertices [integer]:', 'Erode factor [0,1,2,3]:', 'Fill holes factor [0,1,2,3]:', '<HTML>Background threshold:<BR>(guessed from MRI histogram)'}, 'Generate head surface', [], {'10000', '0', '2', num2str(bgLevel)});
    % If user cancelled: return
    if isempty(res)
        return
    end
    % Get new values
    nVertices   = str2num(res{1});
    erodeFactor = str2num(res{2});
    fillFactor  = str2num(res{3});
    bgLevel     = str2num(res{4});
    if isempty(bgLevel)
        bgLevel = sMri.Histogram.bgLevel;
    end
end
% Check parameters values
if isempty(nVertices) || (nVertices < 50) || (nVertices ~= round(nVertices)) || isempty(erodeFactor) || ~ismember(erodeFactor,[0,1,2,3]) || isempty(fillFactor) || ~ismember(fillFactor,[0,1,2,3])
    bst_error('Invalid parameters.', 'Head surface', 0);
    return
end


%% ===== CREATE HEAD MASK =====
% Progress bar
bst_progress('start', 'Generate head surface', 'Creating head mask...', 0, 100);
% Threshold mri to the level estimated in the histogram
headmask = (sMri.Cube(:,:,:,1) > bgLevel);
% Closing all the faces of the cube
headmask(1,:,:)   = 0*headmask(1,:,:);
headmask(end,:,:) = 0*headmask(1,:,:);
headmask(:,1,:)   = 0*headmask(:,1,:);
headmask(:,end,:) = 0*headmask(:,1,:);
headmask(:,:,1)   = 0*headmask(:,:,1);
headmask(:,:,end) = 0*headmask(:,:,1);
% Erode + dilate, to remove small components
if (erodeFactor > 0)
    headmask = headmask & ~mri_dilate(~headmask, erodeFactor);
    headmask = mri_dilate(headmask, erodeFactor);
end
bst_progress('inc', 10);
% Fill holes
bst_progress('text', 'Filling holes...');
headmask = (mri_fillholes(headmask, 1) & mri_fillholes(headmask, 2) & mri_fillholes(headmask, 3));
bst_progress('inc', 10);

% view_mri_slices(headmask, 'x', 20)


%% ===== CREATE SURFACE =====
% Compute isosurface
bst_progress('text', 'Creating isosurface...');
[sHead.Faces, sHead.Vertices] = mri_isosurface(headmask, 0.5);
bst_progress('inc', 10);
% Downsample to a maximum number of vertices
maxIsoVert = 60000;
if (length(sHead.Vertices) > maxIsoVert)
    bst_progress('text', 'Downsampling isosurface...');
    [sHead.Faces, sHead.Vertices] = reducepatch(sHead.Faces, sHead.Vertices, maxIsoVert./length(sHead.Vertices));
    bst_progress('inc', 10);
end
% Remove small objects
bst_progress('text', 'Removing small patches...');
[sHead.Vertices, sHead.Faces] = tess_remove_small(sHead.Vertices, sHead.Faces);
bst_progress('inc', 10);

% Downsampling isosurface
if (length(sHead.Vertices) > nVertices)
    bst_progress('text', 'Downsampling surface...');
    [sHead.Faces, sHead.Vertices] = reducepatch(sHead.Faces, sHead.Vertices, nVertices./length(sHead.Vertices));
    bst_progress('inc', 10);
end
% Convert to millimeters
sHead.Vertices = sHead.Vertices(:,[2,1,3]);
sHead.Faces    = sHead.Faces(:,[2,1,3]);
sHead.Vertices = bst_bsxfun(@times, sHead.Vertices, sMri.Voxsize);
% Convert to SCS
sHead.Vertices = cs_convert(sMri, 'mri', 'scs', sHead.Vertices ./ 1000);

% Reduce the final size of the meshed volume
erodeFinal = 3;
% Fill holes in surface
%if (fillFactor > 0)
    bst_progress('text', 'Filling holes...');
    [sHead.Vertices, sHead.Faces] = tess_fillholes(sMri, sHead.Vertices, sHead.Faces, fillFactor, erodeFinal);
    bst_progress('inc', 30);
% end


%% ===== SAVE FILES =====
if isSave
    bst_progress('text', 'Saving new file...');
    % Create output filenames
    ProtocolInfo = bst_get('ProtocolInfo');
    SurfaceDir   = bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(MriFile));
    HeadFile  = file_unique(bst_fullfile(SurfaceDir, 'tess_head_mask.mat'));
    % Save head
    if ~isempty(Comment)
        sHead.Comment = Comment;
    else
        sHead.Comment = sprintf('head mask (%d,%d,%d,%d)', nVertices, erodeFactor, fillFactor, round(bgLevel));
    end
    sHead = bst_history('add', sHead, 'bem', 'Head surface generated with Brainstorm');
    bst_save(HeadFile, sHead, 'v7');
    iSurface = db_add_surface( iSubject, HeadFile, sHead.Comment);
else
    % Return surface
    HeadFile = sHead.Vertices;
    iSurface = sHead.Faces;
end

% Close, success
if isProgress
    bst_progress('stop');
end



