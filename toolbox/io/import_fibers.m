function [iNewFibers, OutputFiles, nFibers] = import_fibers(iSubject, FibersFiles, FileFormat, nPoints, CS)
% IMPORT_FIBERS: Import a set of fibers in a Subject of Brainstorm database.
% 
% USAGE: iNewFibers = import_fibers(iSubject, FibersFiles=[ask], FileFormat, nPoints=[ask], CS=[ask])
%
% INPUT:
%    - iSubject    : Indice of the subject where to import the fibers
%                    If iSubject=0 : import fibers in default subject
%    - FibersFiles : Cell array of full filenames of the fibers to import (format is autodetected)
%    - FileFormat  : String representing the file format to import: {'TRK','BST'}
%    - nPoints     : Number of points per fiber
%    - CS          : Coordinates system: {'scs','mni','world'}
%
% OUTPUT:
%    - iNewFibers  : Indices of the fibers added in database
%    - OutputFiles : Path to the newly created tess_fibers_*.mat files
%    - nFibers     : Number of fibers imported per file

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
% Authors: Martin Cousineau, 2019
%          Francois Tadel, 2021


%% ===== PARSE INPUTS =====
% Check command line
if ~isnumeric(iSubject) || (iSubject < 0)
    error('Invalid subject indice.');
end
if (nargin < 3) || isempty(FibersFiles)
    FibersFiles = {};
    FileFormat = [];
else
    if ischar(FibersFiles)
        FibersFiles = {FibersFiles};
    end
    if (nargin == 2) || ((nargin >= 3) && isempty(FileFormat))
        error('When you pass a FibersFiles argument, FileFormat must be defined too.');
    end
end
if nargin < 4
    nPoints = [];
end
iNewFibers = [];
OutputFiles = {};
nFibers = [];
CS = [];
% Get subject
sSubject = bst_get('Subject', iSubject);


%% ===== SELECT FIBER FILES =====
% If fibers files to load are not defined : open a dialog box to select it
if isempty(FibersFiles)
    % Get last used directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    if isempty(DefaultFormats.FibersIn)
        DefaultFormats.FibersIn = 'TRK';
    end
    % Get Fibers files
    [FibersFiles, FileFormat, FileFilter] = java_getfile( 'open', ...
       'Import fibers...', ...     % Window title
       LastUsedDirs.ImportAnat, ...   % Default directory
       'multiple', 'files', ...      % Selection mode
       bst_get('FileFilters', 'fibers'), ...
       DefaultFormats.FibersIn);
    % If no file was selected: exit
    if isempty(FibersFiles)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = bst_fileparts(FibersFiles{1});
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default import format
    DefaultFormats.FibersIn = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
end
% Brainstorm format => SCS coordinates
if strcmpi(FileFormat, 'BST')
    CS = 'scs';
end

%% ===== ASK COORDINATE SYSTEM =====
if isempty(CS)
    CS = java_dialog('question', [...
        '<HTML>In which coordinate system are the fibers defined?<BR><BR>' ...
        '- <B>TRK template</B>: MNI template available in MRI coordinates<BR>' ...
        '- <B>MRI</B>: Voxel coordinates of the reference MRI<BR>' ...
        '- <B>World</B>: Original scanner-based coordinates of the reference MRI<BR>'  ...
        '- <B>MNI</B>: Normalized MNI152 coordinates<BR>' ...
        '- <B>SCS</B>: Brainstorm subject coordinate system<BR><BR>'], ...
        'Import fibers', [], {'TRK', 'MRI', 'MNI', 'World', 'SCS', 'Cancel'}, 'TRK');
    if isempty(CS) || strcmpi(CS, 'Cancel')
        return;
    end
    CS = lower(CS);
end
% For "TRK template"
if strcmpi(CS, 'trk')
    % If the subject is the ICBM152 template: Read as "MRI" coordinates
    if ~isempty(strfind(sSubject.Name, 'ICBM152'))
        CS = 'mri';
    % Else: Load ICBM152 template MRI
    else
        sTemplate = bst_get('AnatomyDefaults', 'ICBM152');
        sMriMni = load(bst_fullfile(sTemplate.FilePath, 'subjectimage_T1.mat'));
    end
end


%% ===== ASK NUMBER OF POINTS =====
if isempty(nPoints) && ~strcmpi(FileFormat, 'BST')
    res = java_dialog('input', ['Specify how many points per imported fibers (default: 100).' 10 10], 'Import fibers', [], '100');
    if isempty(res) || isempty(str2num(res))
        return;
    end
    nPoints = str2num(res);
end


%% ===== LOAD MRI =====
% Check the presence of the MRI: warning if no MRI
if isempty(sSubject.Anatomy)
    error('You must import the subject''s MRI first.');
end
% Load MRI
sMri = bst_memory('LoadMri', sSubject.Anatomy(sSubject.iAnatomy).FileName);


%% ===== IMPORT FILES =====
% Process all the selected fibers
for iFile = 1:length(FibersFiles)
    FibersFile = FibersFiles{iFile};
    bst_progress('start', 'Importing fibers', ['Loading file "' FibersFile '"...']);
    
    % === LOAD FIBERS ===
    % Switch between different import functions 
    switch (FileFormat)
        case 'BST'
            FibMat = load(FibersFile);
        case 'TRK'
            % Read using external function
            [header, tracks] = trk_read(FibersFile);
            % Convert to nPoints points
            if ~isempty(nPoints)
                bst_progress('text', ['Interpolating fibers to ' num2str(nPoints) ' points...']);
                tracks = trk_interp(tracks, nPoints);
            end
            % Convert to meters
            tracks = double(tracks) / 1000;
            % Build Brainstorm structure
            FibMat = db_template('fibersmat');
            FibMat.Points = permute(tracks, [3,1,2]);
            FibMat.Header = header;
            FibMat.Comment = sprintf('fibers_%dPt_%dFib', nPoints, size(FibMat.Points, 1));
            FibMat = fibers_helper('ComputeColor', FibMat);
    end
    % If an error occurred: return
    if isempty(FibMat)
        bst_progress('stop');
        return
    elseif (size(FibMat.Points,3) ~= 3) || (~isempty(nPoints) && size(FibMat.Points,2) ~= nPoints)
        error('Invalid matrix orientation.');
    end  
    
    % === APPLY CS TRANSFORM ===
    % Apply transformation
    if ~strcmpi(CS, 'scs')
        % Convert to 2D matrix for calling cs_convert
        shape3d = size(FibMat.Points);
        pts2D = reshape(FibMat.Points, [prod(shape3d(1:end-1)), shape3d(end)]);
        % Convert coordinates to SCS
        switch (lower(CS))
            case 'mri'
                pts2D = cs_convert(sMri, 'mri', 'scs', pts2D);
            case 'mni'
                pts2D = cs_convert(sMri, 'mni', 'scs', pts2D);
            case 'world'
                pts2D = cs_convert(sMri, 'mri', 'scs', pts2D);
            case 'trk'
                pts2D = cs_convert(sMriMni, 'mri', 'mni', pts2D);
                pts2D = cs_convert(sMri, 'mni', 'scs', pts2D);
        end
        if isempty(pts2D)
            error(['Coordinate system "' lower(CS) '" is not available.']);
        end
        % Restore initial matrix dimensions
        FibMat.Points = reshape(pts2D, shape3d);
    end

    % === SAVE BST FILE ===
    % History: File name
    FibMat = bst_history('add', FibMat, 'import', ['Import from: ' FibersFile]);
    % Get imported base name
    [tmp__, importedBaseName] = bst_fileparts(FibersFile);
    importedBaseName = strrep(importedBaseName, 'fibers_', '');
    importedBaseName = strrep(importedBaseName, '_fibers', '');
    % Produce a default fibers filename
    BstFibersFile = bst_fullfile(bst_fileparts(file_fullpath(sSubject.FileName)), ['tess_fibers_' importedBaseName '.mat']);
    % Make this filename unique
    BstFibersFile = file_unique(BstFibersFile);
    % Save new fibers in Brainstorm format
    bst_save(BstFibersFile, FibMat, 'v7');

    % ===== UPDATE DATABASE ======
    % Add new fibers to database
    iNewFibers(end+1) = db_add_surface(iSubject, file_short(BstFibersFile), FibMat.Comment);
    % Unload fibers from memory (if this fibers with the same name was previously loaded)
    bst_memory('UnloadSurface', BstFibersFile);
    % Save output filename
    OutputFiles{end+1} = BstFibersFile;
    % Return number of fibers
    nFibers(end+1) = length(FibMat.Points);
end

% Save database
db_save();
bst_progress('stop');



