function [NewTessFile, iSurface, errMsg] = tess_average( TessFiles, NewComment)
% TESS_CONCATENATE: Concatenate various surface files into one new file.
%
% USAGE:  [NewTessFile, iSurface, errMsg] = tess_average(TessFiles, NewComment='Average')
%          [NewTessMat, iSurface, errMsg] = tess_average(TessMats,  NewComment='Average')
% 
% INPUT: 
%    - TessFiles   : Cell-array of paths to surfaces files to concatenate
%    - TessMats    : Array of loaded surface structures
%    - NewComment  : Name of the output surface
% OUTPUT:
%    - NewTessFile : Filename of the newly created file
%    - iSurface    : Index of the new surface file

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
% Authors: Francois Tadel, 2013

% Parse inputs
if (nargin < 2) || isempty(NewComment)
    NewComment = [];
end
% Initialize returned variables
NewTessFile = [];
iSurface = [];
errMsg = [];
% Save current scouts modifications
panel_scout('SaveModifications');
% Initialize new structure
NewTess = db_template('surfacemat');
isPial = 0;
isWhite = 0;
isAllLeft = 1;
isAllRight = 1;
isSave = 1;

% Progress bar
bst_progress('start', 'Average surfaces', 'Processing... ');
% Process all the files to concatenate
for iFile = 1:length(TessFiles)
    % Load tesselation
    if iscell(TessFiles)
        [oldTess, TessFiles{iFile}] = in_tess_bst(TessFiles{iFile});
        if isempty(oldTess)
            continue
        end
    % Files already loaded in calling function
    else
        oldTess = TessFiles(iFile);
        isSave = 0;
    end
    % Detect if pial/white surface
    isPial  = isPial  || ~isempty(strfind(oldTess.Comment, 'pial')) || ~isempty(strfind(oldTess.Comment, 'cortex'));
    isWhite = isWhite || ~isempty(strfind(oldTess.Comment, 'white'));
    isAllLeft  = isAllLeft  && (~isempty(strfind(oldTess.Comment, 'lh.')) || ~isempty(strfind(oldTess.Comment, 'Lhemi')) || ~isempty(strfind(oldTess.Comment, 'Lwhite')) || ~isempty(strfind(oldTess.Comment, 'left')));
    isAllRight = isAllRight && (~isempty(strfind(oldTess.Comment, 'rh.')) || ~isempty(strfind(oldTess.Comment, 'Rhemi')) || ~isempty(strfind(oldTess.Comment, 'Rwhite')) || ~isempty(strfind(oldTess.Comment, 'right')));
    % Copy first surface contents
    if (iFile == 1)
        NewTess.Vertices = oldTess.Vertices ./ length(TessFiles);
        NewTess.Faces    = oldTess.Faces;
        NewTess.Atlas    = oldTess.Atlas;
        NewTess.iAtlas   = 1;
        NewTess.Faces    = oldTess.Faces;
        NewTess.History  = oldTess.History;
        if isfield(oldTess, 'Reg') && isfield(oldTess.Reg, 'Sphere') && isfield(oldTess.Reg.Sphere, 'Vertices') && ~isempty(oldTess.Reg.Sphere.Vertices)
            NewTess.Reg.Sphere.Vertices = oldTess.Reg.Sphere.Vertices;
        end
    % Check number of vertices
    elseif (size(NewTess.Vertices,1) ~= size(oldTess.Vertices,1))
        errMsg = sprintf('The number of vertices is different in surface #1 (%d) and surface #%d (%d).', size(NewTess.Vertices,1), iFile, size(oldTess.Vertices,1));
        return;
    % Average with the position of the previous surface
    else
        NewTess.Vertices = NewTess.Vertices + oldTess.Vertices ./ length(TessFiles);
    end
    % History: Merged surface #i
    NewTess = bst_history('add', NewTess, 'average', sprintf('Average surface #%d: %s', iFile, oldTess.Comment));
end

% Detect surfaces types
if isPial && isWhite
    fileTag = 'mid';
    NewTess.Comment = 'mid';
else
    fileTag = 'average';
    NewTess.Comment = 'average';
end
% If it is all the same hemisphere
if isAllLeft
    fileTag = ['lh_' fileTag];
    NewTess.Comment = ['lh.' NewTess.Comment];
elseif isAllRight
    fileTag = ['rh_' fileTag];
    NewTess.Comment = ['rh.' NewTess.Comment];
% Else: add the number of vertices
else
    NewTess.Comment = [NewTess.Comment, sprintf('_%dV', size(NewTess.Vertices,1))];
end
% Override comment
if ~isempty(NewComment)
    NewTess.Comment = NewComment;
end

% ===== SAVE IN DATABASE =====
if isSave
    % Create new filename
    NewTessFile = bst_fullfile(bst_fileparts(TessFiles{1}), ['tess_' fileTag '.mat']);
    NewTessFile = file_unique(NewTessFile);
    % Save file
    bst_save(NewTessFile, NewTess, 'v7');
    % Make output filename relative
    NewTessFile = file_short(NewTessFile);
    % Get subject
    [sSubject, iSubject, iFirstSurf] = bst_get('SurfaceFile', TessFiles{1});
    % Register this file in Brainstorm database
    iSurface = db_add_surface(iSubject, NewTessFile, NewTess.Comment, sSubject.Surface(iFirstSurf).SurfaceType);
else
    NewTessFile = NewTess;
    iSurface = [];
end
% Close progress bar
bst_progress('stop');









