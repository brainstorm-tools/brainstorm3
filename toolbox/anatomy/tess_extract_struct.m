function [NewSurfaceFile, iSurface] = tess_extract_struct( SurfaceFile, StructNames, NewComment )
% TESS_EXTRACT_STRUCT: Extract a few structures from a surface file (based on the "Structures" atlas).
%
% USAGE:  [NewSurfaceFile, iSurface] = tess_concatenate(SurfaceFile, StructNames, NewComment='')
% 
% INPUT: 
%    - SurfaceFile : File name of the surface file to process
%    - StructNames : Cell-array of structure names to extract from the selected file
%    - NewComment  : Name of the output surface
% OUTPUT:
%    - NewSurfaceFile : Filename of the newly created file
%    - iSurface    : Index of the new surface file

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2016

% Parse inputs
if (nargin < 3) || isempty(NewComment)
    NewComment = [];
end
if ischar(StructNames)
    StructNames = {StructNames};
end
% Save current scouts modifications
panel_scout('SaveModifications');

% ===== LOAD FILE =====
% Progress bar
bst_progress('start', 'Extract structure', 'Loading file...');
% Load file
[sSurf, SurfaceFile] = in_tess_bst(SurfaceFile);
if isempty(sSurf)
    return;
end
% Find atlas "Structures"
iAtlas = find(strcmpi({sSurf.Atlas.Name}, 'Structures'));
if isempty(iAtlas)
    error('Atlas "Structures" not found in this file.');
end
% Find all the scout names listed in input
[tmp,iScouts] = intersect(lower({sSurf.Atlas(iAtlas).Scouts.Label}), lower(StructNames));
if isempty(iScouts)
    error('Requested regions were not found.');
end

% ===== REMOVE VERTICES =====
% Get all the vertices in the selected scouts
iKeepVert = [sSurf.Atlas(iAtlas).Scouts(iScouts).Vertices];
% Get all the vertices to remove
iRemoveVert = setdiff(1:size(sSurf.Vertices,1), iKeepVert);
% Remove vertices
[sSurf.Vertices, sSurf.Faces, sSurf.Atlas] = tess_remove_vert(sSurf.Vertices, sSurf.Faces, iRemoveVert, sSurf.Atlas);

% ===== CREATE NEW STRUCTURE =====
% Comment
if ~isempty(NewComment)
    sSurf.Comment = NewComment;
elseif (length(StructNames) == 1)
    sSurf.Comment = [sSurf.Comment ' | ' StructNames{1}];
elseif (length(StructNames) == 2) && (length(StructNames{1}) > 2) && (length(StructNames{2}) > 2) && strcmpi(StructNames{1}(1:end-2), StructNames{2}(1:end-2))
    sSurf.Comment = [sSurf.Comment ' | ' StructNames{1}(1:end-2)];
else
    sSurf.Comment = [sSurf.Comment ' | keep'];
end
% History
sSurf = bst_history('add', sSurf, 'extract', sprintf('Extracted %d structures from %s', length(iScouts), SurfaceFile));
    
% === SAVE NEW FILE ===
% Progress bar
bst_progress('start', 'Extract structure', 'Saving new file...');
% Output filename
NewSurfaceFile = strrep(file_fullpath(SurfaceFile), '.mat', '_keep.mat');
NewSurfaceFile = file_unique(NewSurfaceFile);
% Save file back
bst_save(NewSurfaceFile, sSurf, 'v7');
% Get subject
[sSubject, iSubject] = bst_get('SurfaceFile', SurfaceFile);
% Register this file in Brainstorm database
iSurface = db_add_surface(iSubject, NewSurfaceFile, sSurf.Comment);
% Close progress bar
bst_progress('stop');









