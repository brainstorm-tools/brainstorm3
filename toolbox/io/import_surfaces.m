function [iNewSurfaces, OutputSurfacesFiles, nVertices] = import_surfaces(iSubject, SurfaceFiles, FileFormat, isApplyMriOrient, OffsetMri, SelLabels, Comment)
% IMPORT_SURFACES: Import a set of surfaces in a Subject of Brainstorm database.
% 
% USAGE: iNewSurfaces = import_surfaces(iSubject, SurfaceFiles, FileFormat, offset=[], SelLabels=[all], Comment=[])
%        iNewSurfaces = import_surfaces(iSubject)   : Ask user the files to import
%
% INPUT:
%    - iSubject     : Indice of the subject where to import the surfaces
%                     If iSubject=0 : import surfaces in default subject
%    - SurfaceFiles : Cell array of full filenames of the surfaces to import (format is autodetected)
%                     => if not specified : files to import are asked to the user
%    - FileFormat   : String representing the file format to import.
%                     Please see in_tess.m to get the list of supported file formats
%    - isApplyMriOrient: {0,1}
%    - OffsetMri    : (x,y,z) values to add to the coordinates of the surface before converting it to SCS
%    - SelLabels    : Cell-array of labels, when importing atlases
%    - Comment      : Comment of the output file
%
% OUTPUT:
%    - iNewSurfaces : Indices of the surfaces added in database

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
% Authors: Francois Tadel, 2008-2020

%% ===== PARSE INPUTS =====
% Check command line
if ~isnumeric(iSubject) || (iSubject < 0)
    error('Invalid subject indice.');
end
if (nargin < 3) || isempty(SurfaceFiles)
    SurfaceFiles = {};
    FileFormat = [];
else
    if ischar(SurfaceFiles)
        SurfaceFiles = {SurfaceFiles};
    end
    if (nargin == 2) || ((nargin >= 3) && isempty(FileFormat))
        error('When you pass a SurfaceFiles argument, FileFormat must be defined too.');
    end
end
if (nargin < 4) || isempty(isApplyMriOrient)
    isApplyMriOrient = [];
end
if (nargin < 5) || isempty(OffsetMri)
    OffsetMri = [];
end
if (nargin < 6) || isempty(SelLabels)
    SelLabels = [];
end
if (nargin < 7) || isempty(Comment)
    Comment = [];
end
iNewSurfaces = [];
OutputSurfacesFiles = {};
nVertices = [];

% Get Protocol information
ProtocolInfo = bst_get('ProtocolInfo');
% Get subject directory
sSubject = bst_get('Subject', iSubject);
subjectSubDir = bst_fileparts(sSubject.FileName);
% Check the presence of the MRI: warning if no MRI
if isempty(sSubject.Anatomy)
    res = java_dialog('confirm', ...
        ['WARNING: To import correctly surface files, the subject''s MRI is needed.' 10 10 ...
        'Import subject''s MRI now?' 10 10], 'Import surfaces');
    if res
        import_mri(iSubject, [], [], 1);
        return
    end
end


%% ===== SELECT SURFACE FILES =====
% If surface files to load are not defined : open a dialog box to select it
if isempty(SurfaceFiles)
    % Get last used directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    if isempty(DefaultFormats.SurfaceIn)
        DefaultFormats.SurfaceIn = 'ALL';
    end
    % Get Surface files
    [SurfaceFiles, FileFormat, FileFilter] = java_getfile( 'open', ...
       'Import surfaces...', ...     % Window title
       LastUsedDirs.ImportAnat, ...   % Default directory
       'multiple', 'files', ...      % Selection mode
       bst_get('FileFilters', 'surface'), ...
       DefaultFormats.SurfaceIn);
    % If no file was selected: exit
    if isempty(SurfaceFiles)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = bst_fileparts(SurfaceFiles{1});
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default import format
    DefaultFormats.SurfaceIn = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
end
   

%% ===== APPLY MRI TRANSFORM =====
% Load MRI
if ~isempty(sSubject.Anatomy)
    sMri = bst_memory('LoadMri', sSubject.Anatomy(sSubject.iAnatomy).FileName);
else
    sMri = [];
end
% If user transformation on MRI: ask to apply transformations on surfaces
isMni = isequal(FileFormat, 'MRI-MASK-MNI');
if ~isMni && isempty(isApplyMriOrient) && ~isempty(sMri) && isfield(sMri, 'InitTransf') && ~isempty(sMri.InitTransf)
    isApplyMriOrient = java_dialog('confirm', ['MRI orientation was non-standard and had to be reoriented.' 10 10 ...
                                   'Apply the same transformation to the surfaces ?' 10 ...
                                   'Default answer is: NO', 10 10], 'Import surfaces');
else
    isApplyMriOrient = 0;
end


%% ===== LOAD EACH SURFACE =====
% Process all the selected surfaces
for iFile = 1:length(SurfaceFiles)
    TessFile = SurfaceFiles{iFile};
    
    % ===== LOAD SURFACE FILE =====
    bst_progress('start', 'Importing tesselation', ['Loading file "' TessFile '"...']);
    % Load surfaces(s)
    Tess = in_tess(TessFile, FileFormat, sMri, OffsetMri, SelLabels);
    if isempty(Tess)
        bst_progress('stop');
        return
    end
    
    % ===== INITIALIZE NEW SURFACE =====
    % Get imported base name
    if strcmpi(FileFormat, 'FS')
        [tmp__, fBase, fExt] = bst_fileparts(TessFile);
        importedBaseName = [fBase, strrep(fExt, '.', '_')];
    else
        [tmp__, importedBaseName] = bst_fileparts(TessFile);
    end
    importedBaseName = strrep(importedBaseName, 'tess_', '');
    importedBaseName = strrep(importedBaseName, '_tess', '');
    % Only one surface
    if (length(Tess) == 1)
        % Surface mesh
        if isfield(Tess, 'Faces')
            NewTess = db_template('surfacemat');
            NewTess.Comment  = Tess(1).Comment;
            NewTess.Vertices = Tess(1).Vertices;
            if isfield(Tess, 'Faces')   % Volume meshes do not have Faces field
                NewTess.Faces = Tess(1).Faces;
            end
        % Volume FEM mesh
        else
            NewTess = Tess;
        end
    % Multiple surfaces
    else
        [Tess(:).Atlas] = deal(db_template('Atlas'));
        NewTess = tess_concatenate(Tess);
        NewTess.iAtlas  = find(strcmpi({NewTess.Atlas.Name}, 'Structures'));
        NewTess.Comment = importedBaseName;
    end
    % Comment
    if ~isempty(Comment)
        NewTess.Comment = Comment;
    elseif isempty(NewTess.Comment)
        NewTess.Comment = importedBaseName;
    end

    % ===== APPLY MRI ORIENTATION =====
    if isApplyMriOrient
        % History: Apply MRI transformation
        NewTess = bst_history('add', NewTess, 'import', 'Apply transformation that was applied to the MRI volume');
        % Apply MRI transformation
        NewTess = ApplyMriTransfToSurf(sMri.InitTransf, NewTess);
    end

    % ===== SAVE BST FILE =====
    % History: File name
    NewTess = bst_history('add', NewTess, 'import', ['Import from: ' TessFile]);
    % Produce a default surface filename (surface of volume mesh)
    if isfield(NewTess, 'Faces')
        BstTessFile = bst_fullfile(ProtocolInfo.SUBJECTS, subjectSubDir, ['tess_' importedBaseName '.mat']);
    else
        BstTessFile = bst_fullfile(ProtocolInfo.SUBJECTS, subjectSubDir, ['tess_fem_' importedBaseName '.mat']);
    end
    % Make this filename unique
    BstTessFile = file_unique(BstTessFile);
    % Save new surface in Brainstorm format
    bst_save(BstTessFile, NewTess, 'v7');

    % ===== UPDATE DATABASE ======
    % Add new surface to database
    BstTessFileShort = file_short(BstTessFile);
    iNewSurfaces(end+1) = db_add_surface(iSubject, BstTessFileShort, NewTess.Comment);
    % Unload surface from memory (if this surface with the same name was previously loaded)
    bst_memory('UnloadSurface', BstTessFile);
    % Save output filename
    OutputSurfacesFiles{end+1} = BstTessFile;
    % Return number of vertices
    nVertices(end+1) = length(NewTess.Vertices);
end

% Save database
db_save();
bst_progress('stop');
end   



%% ===== APPLY MRI ORIENTATION =====
function sSurf = ApplyMriTransfToSurf(MriTransf, sSurf)
    % Apply transformation to vertices
    sSurf.Vertices = ApplyMriTransfToPts(MriTransf, sSurf.Vertices);
    % Update faces order: If the surfaces were flipped an odd number of times, invert faces orientation
    if (mod(nnz(strcmpi(MriTransf(:,1), 'flipdim')), 2) == 1)
        sSurf.Faces = sSurf.Faces(:,[1 3 2]);
    end
end

function pts = ApplyMriTransfToPts(MriTransf, pts)
    % Apply step by step all the transformations that have been applied to the MRI
    for i = 1:size(MriTransf,1)
        ttype = MriTransf{i,1};
        val   = MriTransf{i,2};
        switch (ttype)
            case 'flipdim'
                % Detect the dimensions that have constantly negative coordinates
                iDimNeg = find(sum(sign(pts) == -1) == size(pts,1));
                if ~isempty(iDimNeg)
                    pts(:,iDimNeg) = -pts(:,iDimNeg);
                end
                % Flip dimension
                pts(:,val(1)) = val(2)/1000 - pts(:,val(1));
                % Restore initial negative values
                if ~isempty(iDimNeg)
                    pts(:,iDimNeg) = -pts(:,iDimNeg);
                end
            case 'permute'
                pts = pts(:,val);
            case 'vox2ras'
                % Do nothing, applied earlier
        end
    end
end

