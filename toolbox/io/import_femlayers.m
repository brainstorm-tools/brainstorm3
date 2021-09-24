function [iNewSurfaces, OutputFiles] = import_femlayers(iSubject, FemFiles, FileFormat, isInteractive)
% IMPORT_FEMLAYERS: Extracts surfaces from FEM 3D mesh and saves them in the database
% 
% USAGE: iNewSurfaces = import_surfaces(iSubject, FemFiles, FileFormat)
%        iNewSurfaces = import_surfaces(iSubject)   : Ask user the files to import
%
% INPUT:
%    - iSubject     : Indice of the subject where to import the surfaces
%                     If iSubject=0 : import surfaces in default subject
%    - FemFiles     : Cell array of full filenames of the surfaces to import (format is autodetected)
%                     => if not specified : files to import are asked to the user
%    - FileFormat   : String representing the file format to import.
%                     Please see in_tess.m to get the list of supported file formats
%    - isInteractive: {0,1} If 0, do not ask any question to the user and use default values
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
% Authors: Francois Tadel, 2020


%% ===== PARSE INPUTS =====
% Check command line
if ~isnumeric(iSubject) || (iSubject < 0)
    error('Invalid subject indice.');
end
if (nargin < 4) || isempty(isInteractive)
    isInteractive = 0;
end
if (nargin < 3) || isempty(FemFiles)
    FemFiles = {};
    FileFormat = [];
else
    if ischar(FemFiles)
        FemFiles = {FemFiles};
    end
    if (nargin == 2) || ((nargin >= 3) && isempty(FileFormat))
        error('When you pass a FemFiles argument, FileFormat must be defined too.');
    end
end
iNewSurfaces = [];
OutputFiles = {};
nVertices = [];

% Get Protocol information
ProtocolInfo = bst_get('ProtocolInfo');
% Get subject directory
sSubject = bst_get('Subject', iSubject);
subjectSubDir = bst_fileparts(sSubject.FileName);


%% ===== INSTALL ISO2MESH =====
% Install/load iso2mesh plugin
[isInstalled, errMsg] = bst_plugin('Install', 'iso2mesh', isInteractive);
if ~isInstalled
    error(errMsg);
end
            

%% ===== SELECT INPUT FILES =====
% If surface files to load are not defined : open a dialog box to select it
if isempty(FemFiles)
    % Get last used directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    % Get Surface files
    [FemFiles, FileFormat, FileFilter] = java_getfile( 'open', ...
       'Import surfaces...', ...     % Window title
       LastUsedDirs.ImportAnat, ...   % Default directory
       'multiple', 'files', ...      % Selection mode
       {{'_fem'}, 'Brainstorm (*.mat)', 'BSTFEM'}, ...
       'BSTFEM');
    % If no file was selected: exit
    if isempty(FemFiles)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = bst_fileparts(FemFiles{1});
    bst_set('LastUsedDirs', LastUsedDirs);
end
   

%% ===== LOAD EACH SURFACE =====
% Process all the selected surfaces
for iFile = 1:length(FemFiles)
    % Load file
    FemFile = FemFiles{iFile};
    bst_progress('start', 'Extract surfaces', ['Loading file "' FemFile '"...']);
    FemMat = load(FemFile);
    % Hexahedral meshes not supported
    if (size(FemMat.Elements,2) > 4)
        error('Hexahedral meshes are not supported.');
    end

    % Create one surface per tissue
    Ntissue = max(FemMat.Tissue);
    bst_progress('start', 'Extract surfaces', 'Extracting surfaces...', 0, Ntissue + 1);
    for iTissue = 1:Ntissue
        bst_progress('text', ['Extracting surfaces: ' FemMat.TissueLabels{iTissue} '...']);
        bst_progress('inc', 1);
        
        % ===== EXTRACT SURFACE =====
        % Select elements of this tissue
        Elements = FemMat.Elements(FemMat.Tissue <= iTissue, 1:4);
        % Create a surface for the outside surface of this tissue
        Faces = tess_voledge(FemMat.Vertices, Elements);
        if isempty(Faces)
            continue;
        end
        % Detect all unused vertices
        Vertices = FemMat.Vertices;
        iRemoveVert = setdiff((1:size(Vertices,1))', unique(Faces(:)));
        % Remove all the unused vertices 
        if ~isempty(iRemoveVert)
            [Vertices, Faces] = tess_remove_vert(Vertices, Faces, iRemoveVert);
        end
        % Remove small elements
        [Vertices, Faces] = tess_remove_small(Vertices, Faces);
        
        % call meshfixe via iso2mesh to remove the inner islandes
        if exist('meshcheckrepair', 'file')
             [Vertices, Faces] = meshcheckrepair(Vertices, Faces, 'meshfix');
        end
        
        % ===== NEW STRUCTURE =====
        NewTess = db_template('surfacemat');
        NewTess.Comment  = FemMat.TissueLabels{iTissue};
        NewTess.Vertices = Vertices;
        NewTess.Faces    = Faces;

        % ===== SAVE BST FILE =====
        % History: File name
        NewTess = bst_history('add', NewTess, 'import', ['Import from: ' FemFile]);
        % Produce a default surface filename
        BstFemFile = bst_fullfile(ProtocolInfo.SUBJECTS, subjectSubDir, ['tess_' NewTess.Comment '.mat']);
        % Make this filename unique
        BstFemFile = file_unique(BstFemFile);
        % Save new surface in Brainstorm format
        bst_save(BstFemFile, NewTess, 'v7');

        % ===== UPDATE DATABASE ======
        % Add new surface to database
        BstFemFileShort = file_short(BstFemFile);
        iNewSurfaces(end+1) = db_add_surface(iSubject, BstFemFileShort, NewTess.Comment);
        % Unload surface from memory (if this surface with the same name was previously loaded)
        bst_memory('UnloadSurface', BstFemFile);
        % Save output filename
        OutputFiles{end+1} = BstFemFile;
        % Return number of vertices
        nVertices(end+1) = length(NewTess.Vertices);
    end
end

% Save database
db_save();
bst_progress('stop');
end   

