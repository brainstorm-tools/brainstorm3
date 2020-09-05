function [NewTessFile, iSurface] = tess_concatenate( TessFiles, NewComment, fileType )
% TESS_CONCATENATE: Concatenate various surface files into one new file.
%
% USAGE:  [NewTessFile, iSurface] = tess_concatenate(TessFiles, NewComment='New surface', fileType='Other')
%          [NewTessMat, iSurface] = tess_concatenate(TessMats,  NewComment='New surface', fileType='Other')
% 
% INPUT: 
%    - TessFiles   : Cell-array of paths to surfaces files to concatenate
%    - TessMats    : Array of loaded surface structures
%    - NewComment  : Name of the output surface
%    - fileType    : File type for the new file {'Cortex', 'InnerSkull', 'OuterSkull', 'Scalp', 'Other'}
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
% Authors: Francois Tadel, 2008-2016

% Parse inputs
if (nargin < 3) || isempty(fileType)
    fileType = [];
end
if (nargin < 2) || isempty(NewComment)
    NewComment = [];
end
% Save current scouts modifications
panel_scout('SaveModifications');
% Initialize new structure
NewTess = db_template('surfacemat');
isLeft = 0;
isRight = 0;
isWhite = 0;
isCortex = 0;
isAseg = 0;
isSave = 1;

% Progress bar
bst_progress('start', 'Merge surfaces', 'Processing... ');
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
    % Detect if right/left hemisphere
    if ~isempty(strfind(oldTess.Comment, 'lh.')) || ~isempty(strfind(oldTess.Comment, 'Lhemi')) || ~isempty(strfind(oldTess.Comment, 'Lwhite')) || ~isempty(strfind(oldTess.Comment, 'left'))
        isLeft = 1;
        scoutTag = ' L';
        scoutHemi = 'L';
        scoutComment = 'Cortex';
    elseif ~isempty(strfind(oldTess.Comment, 'rh.')) || ~isempty(strfind(oldTess.Comment, 'Rhemi')) || ~isempty(strfind(oldTess.Comment, 'Rwhite')) || ~isempty(strfind(oldTess.Comment, 'right'))
        isRight = 1;
        scoutTag = ' R';
        scoutHemi = 'R';
        scoutComment = 'Cortex';
    % Detect based on comment (tag ' L' or ' R' already present)
    elseif (length(oldTess.Comment) > 2) && strcmpi(oldTess.Comment(end-1:end), ' L')
        scoutTag = ' L';
        scoutHemi = 'L';
        scoutComment = oldTess.Comment;
    elseif (length(oldTess.Comment) > 2) && strcmpi(oldTess.Comment(end-1:end), ' R')
        scoutTag = ' R';
        scoutHemi = 'R';
        scoutComment = oldTess.Comment;
    % Guess based on the coordinates
    else
        if (nnz(oldTess.Vertices(:,2) > 0) > 5 * nnz(oldTess.Vertices(:,2) < 0))
            scoutTag = ' L';
            scoutHemi = 'L';
        elseif (nnz(oldTess.Vertices(:,2) < 0) > 5 * nnz(oldTess.Vertices(:,2) > 0))
            scoutTag = ' R';
            scoutHemi = 'R';
        else
            scoutTag = '';
            scoutHemi = 'U';
        end
        scoutComment = oldTess.Comment;
    end
    % Detect some specific types of surfaces
    if ~isempty(strfind(oldTess.Comment, 'white'))
        isWhite = 1;
    end
    if ~isempty(strfind(oldTess.Comment, 'cortex_'))
        isCortex = 1;
    end
    if ~isempty(strfind(oldTess.Comment, 'aseg'))
        isAseg = 1;
    end
    % Concatenate current sub-tess to final tesselation structure
    offsetVertices   = size(NewTess.Vertices,1);
    NewTess.Faces    = [NewTess.Faces; oldTess.Faces + offsetVertices];
    NewTess.Vertices = [NewTess.Vertices; oldTess.Vertices];

    % History: Merged surface #i
    NewTess = bst_history('add', NewTess, 'merge', sprintf('Merge surface #%d: %s', iFile, oldTess.Comment));
    % History: Copy history of surface #i
    if isfield(oldTess, 'History') && ~isempty(oldTess.History)
        NewTess = bst_history('add', NewTess, oldTess.History, '  => ');
    end
    
    % Add an atlas "Structures" to reference the origins of each structure (if it does not exist)
    iAtlasStruct = find(strcmpi({oldTess.Atlas.Name}, 'Structures'));
    if isempty(iAtlasStruct)
        % Create new atlas
        iAtlasStruct = length(oldTess.Atlas) + 1;
        oldTess.Atlas(iAtlasStruct) = db_template('atlas');
        oldTess.Atlas(iAtlasStruct).Name = 'Structures';
        % Create one scout that describes all the structure
        oldTess.Atlas(iAtlasStruct).Scouts(1).Vertices = 1:length(oldTess.Vertices);
        oldTess.Atlas(iAtlasStruct).Scouts(1).Seed     = 1;
        oldTess.Atlas(iAtlasStruct).Scouts(1).Label    = scoutComment;
        oldTess.Atlas(iAtlasStruct).Scouts(1).Function = 'Mean';
        oldTess.Atlas(iAtlasStruct).Scouts(1).Region   = [scoutHemi 'U'];
        % Set scout color
        oldTess.Atlas(iAtlasStruct).Scouts(1) = panel_scout('SetColorAuto', oldTess.Atlas(iAtlasStruct).Scouts(1));
    end
    
    % Concatenate atlases/scouts
    for iAtlasOld = 1:length(oldTess.Atlas)
        % Look for the same altas in the new surface
        iAtlasNew = find(strcmpi({NewTess.Atlas.Name}, oldTess.Atlas(iAtlasOld).Name));
        if isempty(iAtlasNew)
            iAtlasNew = length(NewTess.Atlas) + 1;
            NewTess.Atlas(iAtlasNew) = db_template('atlas');
            NewTess.Atlas(iAtlasNew).Name = oldTess.Atlas(iAtlasOld).Name;
        end
        % Loop over all scouts in the old surface to fix the indices of the vertices
        for iScout = 1:length(oldTess.Atlas(iAtlasOld).Scouts)
            % Adjust vertex indices
            oldTess.Atlas(iAtlasOld).Scouts(iScout).Vertices = oldTess.Atlas(iAtlasOld).Scouts(iScout).Vertices + offsetVertices;
            oldTess.Atlas(iAtlasOld).Scouts(iScout).Seed     = oldTess.Atlas(iAtlasOld).Scouts(iScout).Seed     + offsetVertices;
            % Add the first letter of the surface comment to the scout name
            if ~ismember(oldTess.Atlas(iAtlasOld).Scouts(iScout).Label(end), {'L', 'R'})
                oldTess.Atlas(iAtlasOld).Scouts(iScout).Label = [oldTess.Atlas(iAtlasOld).Scouts(iScout).Label, scoutTag];
            end
            % Set region name
            oldRegion = oldTess.Atlas(iAtlasOld).Scouts(iScout).Region;
            if isempty(oldRegion) || (length(oldRegion) < 2)
                oldTess.Atlas(iAtlasOld).Scouts(iScout).Region = [scoutHemi, 'U'];
            elseif (oldTess.Atlas(iAtlasOld).Scouts(iScout).Region(1) == 'U')
                oldTess.Atlas(iAtlasOld).Scouts(iScout).Region(1) = scoutHemi;
            end
        end
        % Add to surface
        if isempty(NewTess.Atlas(iAtlasNew).Scouts) && isempty(oldTess.Atlas(iAtlasOld).Scouts)
            NewTess.Atlas(iAtlasNew).Scouts = repmat(db_template('scout'), 0);
        elseif isempty(NewTess.Atlas(iAtlasNew).Scouts)
            NewTess.Atlas(iAtlasNew).Scouts = oldTess.Atlas(iAtlasOld).Scouts;
        else
            NewTess.Atlas(iAtlasNew).Scouts = [...
                struct_fix(db_template('scout'), NewTess.Atlas(iAtlasNew).Scouts), ...
                struct_fix(db_template('scout'), oldTess.Atlas(iAtlasOld).Scouts)];
        end
    end
    
    % Concatenate FreeSurfer registration spheres
    if isfield(oldTess, 'Reg') && isfield(oldTess.Reg, 'Sphere') && isfield(oldTess.Reg.Sphere, 'Vertices') && ~isempty(oldTess.Reg.Sphere.Vertices)
%         if (iFile > 1) && (~isfield(NewTess, 'Reg') || ~isfield(NewTess.Reg, 'Sphere') || ~isfield(NewTess.Reg.Sphere, 'Vertices'))
%             NewTess.Reg = [];
%             oldTess.Reg = [];
%         if (iFile == 1)
        if ~isfield(NewTess, 'Reg') || ~isfield(NewTess.Reg, 'Sphere') || ~isfield(NewTess.Reg.Sphere, 'Vertices')
            NewTess.Reg.Sphere.Vertices = oldTess.Reg.Sphere.Vertices;
        else
            NewTess.Reg.Sphere.Vertices = [NewTess.Reg.Sphere.Vertices; oldTess.Reg.Sphere.Vertices];
        end
    end
    % Concatenate BrainSuite registration squares    
    if isfield(oldTess, 'Reg') && isfield(oldTess.Reg, 'Square') && isfield(oldTess.Reg.Square, 'Vertices') && ~isempty(oldTess.Reg.Square.Vertices)
%         if (iFile > 1) && (~isfield(NewTess, 'Reg') || ~isfield(NewTess.Reg, 'Square') || ~isfield(NewTess.Reg.Square, 'Vertices'))
%             NewTess.Reg = [];
%             oldTess.Reg = [];
%         elseif (iFile == 1)
        if ~isfield(NewTess, 'Reg') || ~isfield(NewTess.Reg, 'Square') || ~isfield(NewTess.Reg.Square, 'Vertices')
            NewTess.Reg.Square.Vertices      = oldTess.Reg.Square.Vertices;
            NewTess.Reg.AtlasSquare.Vertices = oldTess.Reg.AtlasSquare.Vertices;
        else
            NewTess.Reg.Square.Vertices      = [NewTess.Reg.Square.Vertices;      oldTess.Reg.Square.Vertices];
            NewTess.Reg.AtlasSquare.Vertices = [NewTess.Reg.AtlasSquare.Vertices; oldTess.Reg.AtlasSquare.Vertices];
        end
    end
end
% Sort scouts by name
for iAtlas = 1:length(NewTess.Atlas)
    [tmp, iSort] = sort({NewTess.Atlas(iAtlas).Scouts.Label});
    NewTess.Atlas(iAtlas).Scouts = NewTess.Atlas(iAtlas).Scouts(iSort);
end

% Detect surfaces types
if isLeft && isRight
    % File type: Cortex
    if isempty(fileType)
        fileType = 'Cortex';
    end
    % White matter
    if isWhite
        fileTag = 'cortex_white';
        if isempty(NewComment)
            NewComment = sprintf('white_%dV', length(NewTess.Vertices));
        end
    % Pial/cortex external envelope
    else
        fileTag = 'cortex_pial';
        if isempty(NewComment)
            NewComment = sprintf('cortex_%dV', length(NewTess.Vertices));
        end
    end
elseif isCortex && isAseg
    fileTag = 'cortex_mixed';
    if isempty(fileType)
        fileType = 'Cortex';
    end
    if isempty(NewComment)
        NewComment = sprintf('cortex_mixed_%dV', length(NewTess.Vertices));
    end
else
    fileTag = 'concat';
    if isempty(fileType)
        fileType = 'Other';
    end
    if isempty(NewComment)
        NewComment = 'New surface';
    end
end
% Surface comments
NewTess.Comment = NewComment;
% History: Merge completed
NewTess = bst_history('add', NewTess, 'merge', 'Merge completed');


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
    [sSubject, iSubject] = bst_get('SurfaceFile', TessFiles{1});
    % Register this file in Brainstorm database
    iSurface = db_add_surface(iSubject, NewTessFile, NewComment, fileType);
else
    NewTessFile = NewTess;
    iSurface = [];
end
% Close progress bar
bst_progress('stop');









