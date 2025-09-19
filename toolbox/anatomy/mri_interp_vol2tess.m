function [OutputFile, errorMsg] = mri_interp_vol2tess(MriFileSrc, MriFileRef, Condition, DisplayUnits, ProjFrac)
% MRI_VOL2TESS: Estimates average voxel intensities along the surface
% normals from pial surface to white matter surface and projects the result to
% the pial surface as a texture.
% 
% USAGE:  OutputFile = mri_vol2tess(MriFileSrc, MriFileRef, Condition, DisplayUnits, ProjFrac)
%
% INPUT:
%    - MriFileSrc : Source MRI file
%    - MriFileRef : Reference MRI file
%    - Condition  : Condition name for the projection
%    - DisplayUnits:  Units of projected data for display
%    - ProjFrac   : Weights for depth-weighted projection of data,
%                   give as a 3-element vector for white matter, mid and 
%                   pial surface, respectively (default: [0.1 0.8 0.1])
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
% Authors: Diellor Basha, 2024

%% ===== INITIALIZATION =====
errorMsg = '';
OutputFile = '';
if nargin < 5, ProjFrac = [0.1 0.8 0.1]; end
if nargin < 4, DisplayUnits = []; end
if nargin < 3, Condition = []; end

%% ===== LOAD ANATOMY AND CHECKS =====
isProgressBar = bst_progress('isVisible');
if ~isProgressBar
    bst_progress('start', 'Load anatomy', 'Loading subject surface and MRI...');
end

% Parse input files and surfaces
if isstruct(MriFileSrc)
    sMriSrc = MriFileSrc;
    sMriRef = MriFileRef;
else
    sSubject = bst_get('MriFile', MriFileSrc);
    [sStudy, iStudy] = bst_get('StudyWithCondition', bst_fullfile(sSubject.Name, Condition));
    MriFileRef = sSubject.Anatomy(sSubject.iAnatomy).FileName;

    sMriSrc = in_mri_bst(MriFileSrc);
    sMriRef = in_mri_bst(MriFileRef);
end

Comment = sMriSrc.Comment;

if isempty(sMriRef) || isempty(sMriSrc)
    errorMsg = 'MRI files could not be loaded.';
    return;
end

if isempty(iStudy)
    iStudy = db_add_condition(sSubject.Name, Condition);
    sStudy = bst_get('Study', iStudy);
end

% Validate MRI dimensions
refSize = size(sMriRef.Cube(:,:,:,1));
srcSize = size(sMriSrc.Cube(:,:,:,1));
if ~isequal(refSize, srcSize)
    errorMsg = 'Source and reference MRI dimensions do not match.';
    return;
end

%% ===== LOAD SURFACES =====
% Find and load pial, mid, and white "low" resolution surfaces from sSubject.Surface 

% Collect all surface file names
allFiles = {sSubject.Surface.FileName};

% Find indices for each surface type
idxPial  = find(~cellfun('isempty', regexp(allFiles, 'cortex_pial_low\.mat$', 'once')), 1);
idxMid   = find(~cellfun('isempty', regexp(allFiles, 'cortex_mid_low\.mat$', 'once')), 1);
idxWhite = find(~cellfun('isempty', regexp(allFiles, 'cortex_white_low\.mat$', 'once')), 1);

% Assign file names if found
if ~isempty(idxPial)
    pialFile = allFiles{idxPial};
else
    error('Pial surface (cortex_pial_low) not found.');
end
if ~isempty(idxMid)
    midFile = allFiles{idxMid};
else
    error('Mid surface (cortex_mid_low) not found.');
end
if ~isempty(idxWhite)
    whiteFile = allFiles{idxWhite};
else
    error('White surface (cortex_white_low) not found.');
end

% Load the surfaces
sPial  = in_tess_bst(pialFile);
sMid   = in_tess_bst(midFile);
sWhite = in_tess_bst(whiteFile);

SurfaceFiles = {pialFile, midFile, whiteFile};
sSurf = {sPial, sMid, sWhite};
vol2tess = cell(1, numel(SurfaceFiles)); % Use cell array to handle different vertex counts

cube2vec = double(sMriSrc.Cube(:,:,:,1));
cube2vec = cube2vec(:);

for nSurf = 1:numel(SurfaceFiles)
    nVertices = size(sSurf{nSurf}.Vertices, 1);
    tess2mri_interp = tess_interp_mri(SurfaceFiles{nSurf}, sMriRef);
    ivol2tess = tess2mri_interp' * cube2vec;
    vWeights = sum(tess2mri_interp, 1);
    ivol2tess = ivol2tess ./ vWeights';
    ivol2tess(~isfinite(ivol2tess)) = 0;
    vol2tess{nSurf} = ivol2tess;
end

% If all surfaces have the same number of vertices, you can concatenate:
if all(cellfun(@(v) numel(v), vol2tess) == numel(vol2tess{1}))
    vol2tess_mat = cell2mat(vol2tess);
    map = vol2tess_mat * ProjFrac';
else
    error('Surface vertex counts do not match. Cannot combine projections.');
end

% === STORE AS REGULAR SOURCE FILE ===
ResultsMat = db_template('resultsmat');
if size(map, 2) > 1
    ResultsMat.ImageGridAmp  = map;
else
    ResultsMat.ImageGridAmp  = [map, map];
end
ResultsMat.ImagingKernel = [];
FileType = 'results';
ResultsMat.Time = 0:(size(ResultsMat.ImageGridAmp,2)-1);
% Fix identical time points
if (length(ResultsMat.Time) == 2) && (ResultsMat.Time(1) == ResultsMat.Time(2))
    ResultsMat.Time(2) = ResultsMat.Time(2) + 0.001;
end

% === SAVE NEW FILE ===
ResultsMat.Comment       = Comment;
ResultsMat.DataFile      = [];
ResultsMat.SurfaceFile   = file_win2unix(file_short(pialFile));
ResultsMat.HeadModelFile = [];
ResultsMat.nComponents   = 1;
ResultsMat.DisplayUnits  = DisplayUnits;
if isequal(DisplayUnits, 's')
    ResultsMat.ColormapType = 'time';
end
ResultsMat.HeadModelType = 'surface';
% History
ResultsMat = bst_history('add', ResultsMat, 'project', ['Projected from: ' sMriSrc.Comment]);
% Create output filename
OutputFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [FileType, '_', ResultsMat.HeadModelType, '_', file_standardize(Comment)]);
% Save new file
bst_save(OutputFile, ResultsMat, 'v7');
% Update database
OutputFile = file_short(OutputFile);
db_add_data(iStudy, OutputFile, ResultsMat);

% Update tree
panel_protocols('UpdateNode', 'Study', iStudy);
% Save database
db_save();

% Progress bar
if ~isProgressBar
    bst_progress('stop');
end
%% ====== VISUALIZE RESULT ======= 
view_surface_data(pialFile, OutputFile);
if ~isProgressBar
    bst_progress('stop');
end

end
