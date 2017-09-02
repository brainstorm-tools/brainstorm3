function [OutputFiles, errorMsg] = import_sources(iStudy, SurfaceFile, SourceFiles, SourceFiles2, FileFormat)
% IMPORT_SOURCES: Imports static source maps as results files.
% 
% USAGE:  iNewSources = import_sources(iStudy, SurfaceFile, SourceFiles, SourceFiles2=[], FileFormat)
%
% INPUT:
%    - iStudy       : Index of the study where to import the SourceFiles
%    - SurfaceFile  : Surface from the Brainstorm database on which the maps have to be displayed
%    - SourceFiles  : Full filename, or cell array of filenames, of the source maps to import
%                     => if not specified : file to import is asked to the user
%    - SourceFiles2 : In the case of left/right files to import as one joined matrix (FreeSurfer import)
%    - FileFormat   : One of the available file formats ('FS')

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2013-2017

%% ===== PARSE INPUTS =====
% Initialize returned variables
OutputFiles = {};
errorMsg = [];
% Get default for all the inputs
if (nargin < 5) || isempty(FileFormat)
    FileFormat = [];
end
if (nargin < 4) || isempty(SourceFiles2)
    SourceFiles2 = [];
elseif ~iscell(SourceFiles2)
    SourceFiles2 = {SourceFiles2};
end
if (nargin < 3) || isempty(SourceFiles)
    SourceFiles = [];
elseif ~iscell(SourceFiles)
    SourceFiles = {SourceFiles};
end
if (nargin < 2) || isempty(SurfaceFile)
    SurfaceFile = [];
end
% Interactive mode = user selects the files
isInteractive = isempty(SourceFiles);
% Check matching sizes of SourceFiles and SourceFiles2
if ~isempty(SourceFiles2) && (length(SourceFiles2) ~= length(SourceFiles))
    errorMsg = 'Length of arguments SourceFiles and SourceFiles2 must match.';
    if isInteractive
        bst_error(errorMsg, 'Import source maps', 0);
    end
    return;
end


%% ===== SELECT FILES =====
if isempty(SourceFiles)
    % Get default import directory and formats
    LastUsedDirs   = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Get file
    [SourceFiles, FileFormat] = java_getfile('open', ...
            'Import source maps...', ...   % Window title
            LastUsedDirs.ImportData, ...    % Last used directory
            'multiple', 'files', ...        % Selection mode
            {{'*'}, 'FreeSurfer maps (*.*)',    'FS'; ...
             {'*'}, 'CIVET maps (*.*)',         'CIVET'; ...
             {'.gii'}, 'GIfTI texture (*.gii)', 'GII'; ...
             {'.mri', '.fif', '.img', '.ima', '.nii', '.mgh', '.mgz', '.mnc', '.mni', '.gz', '_subjectimage'}, 'Volume grids (subject space)', 'ALLMRI'; ...
             {'.mri', '.fif', '.img', '.ima', '.nii', '.mgh', '.mgz', '.mnc', '.mni', '.gz', '_subjectimage'}, 'Volume grids (MNI space)',     'ALLMRI-MNI'; ...
            }, DefaultFormats.ResultsIn);
    % If no file was selected: exit
    if isempty(SourceFiles)
        return
    % Make sure it's an array of files
    elseif ~iscell(SourceFiles)
        SourceFiles = {SourceFiles};
    end
    % Save default import directory
    LastUsedDirs.ImportData = bst_fileparts(SourceFiles{1});
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default import format
    DefaultFormats.ResultsIn = FileFormat;
    bst_set('DefaultFormats', DefaultFormats);
end


%% ===== SELECT OUTPUT STUDY =====
% If output folder not defined: Use a folder "Texture" in current subject
if isempty(iStudy)
    % The surface must be specified
    if isempty(SurfaceFile)
        error('Surface file must be specified.');
    end
    % Get subject
    sSubject = bst_get('SurfaceFile', SurfaceFile);
    % Get or create new folder "Texture"
    Condition = 'Texture';
    [sStudy, iStudy] = bst_get('StudyWithCondition', bst_fullfile(sSubject.Name, Condition));
    % If does not exist yet: Create the default study
    if isempty(iStudy)
        iStudy = db_add_condition(sSubject.Name, Condition);
        if isempty(iStudy)
            error('Study could not be created : "%s".', Condition);
        end
        sStudy = bst_get('Study', iStudy);
    end
% Use folder in input
else
    % Get study
    sStudy = bst_get('Study', iStudy);
    % Get subject
    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
end


%% ===== GET ANATOMY =====
% Get various information
isProgressBar = bst_progress('isVisible');
if ~isProgressBar
    bst_progress('start', 'Import source maps', 'Importing source maps...');
end
% If surface file not specified: get the default cortex
if isempty(SurfaceFile) && ~isempty(sSubject.iCortex) && (sSubject.iCortex <= length(sSubject.Surface))
    SurfaceFile = sSubject.Surface(sSubject.iCortex).FileName;
end
% If no cortex available: error
if isempty(SurfaceFile) && ~ismember(FileFormat, {'ALLMRI', 'ALLMRI-MNI'})
    errorMsg = 'No cortex file available for this subject.';
    if isInteractive
        bst_error(errorMsg, 'Import source maps', 0);
    end
    return;
end
% Load cortex
if ~isempty(SurfaceFile)   
    varVertices = whos('-file', file_fullpath(SurfaceFile), 'Vertices');
    nVertices = varVertices.size(1);
end


%% ===== READ SOURCE FILES =====
sMri = [];
% Loop on each input file
for iFile = 1:length(SourceFiles)
    % Read source file
    [map, grid] = in_sources(SourceFiles{iFile}, FileFormat);
    % In the case of a volume grid: convert from MRI coordinates to SCS
    if ~isempty(grid)
        % Load subject MRI
        if isempty(sMri)
            sMri = in_mri_bst(sSubject.Anatomy(sSubject.iAnatomy).FileName);
        end
        % Convert MRI=>SCS
        grid = cs_convert(sMri, 'mri', 'scs', grid);
    end
    % Read additional source file: simply concatenate to the previous one
    if ~isempty(SourceFiles2)
        map = [map; in_sources(SourceFiles2{iFile}, FileFormat)];
    end
    % Check the number of sources
    if isempty(map)
        errorMsg = ['File could not be read: ', SourceFiles{iFile}];
        if isInteractive
            bst_error(errorMsg, 'Import source maps', 0);
        end
        break;
    elseif isempty(grid) && (size(map,1) ~= nVertices)
        errorMsg = sprintf('The number of vertices in the surface (%d) and the source map (%d) do not match.', nVertices, size(map,1));
        if isInteractive
            bst_error(errorMsg, 'Import source maps', 0);
        end
        break;
    end
    % Comment: Use the base filename
    [fPath, fBase, fExt] = bst_fileparts(SourceFiles{iFile});
    if strcmpi(FileFormat, 'FS')
        baseName = [fBase, fExt];
    else
        baseName = fBase;
    end
    baseName = strrep(baseName, 'results_', '');
    baseName = strrep(baseName, '_results', '');
    % If the two files are imported: remove .lh and .rh
    if ~isempty(SourceFiles2)
        baseName = strrep(baseName, 'rh.', '');
        baseName = strrep(baseName, 'lh.', '');
        baseName = strrep(baseName, '_left', '');
        baseName = strrep(baseName, '_right', '');
    end
    
    % === SAVE NEW FILE ===
    % New results structure
    ResultsMat = db_template('resultsmat');
    ResultsMat.ImageGridAmp  = [map, map];
    ResultsMat.ImagingKernel = [];
    ResultsMat.Comment       = baseName;
    ResultsMat.Time          = [0 1];
    ResultsMat.DataFile      = [];
    ResultsMat.SurfaceFile   = file_win2unix(file_short(SurfaceFile));
    ResultsMat.HeadModelFile = [];
    % Surface model
    if isempty(grid)
        ResultsMat.HeadModelType = 'surface';
    % Volume model
    else
        ResultsMat.HeadModelType = 'volume';
        ResultsMat.GridLoc = grid;
    end
    % History
    ResultsMat = bst_history('add', ResultsMat, 'import', ['Imported from: ' SourceFiles{iFile}]);
    % Create output filename
    OutputFiles{iFile} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), ['results_', baseName]);
    % Save new file
    bst_save(OutputFiles{iFile}, ResultsMat, 'v7');
    % Update database
    sStudy = db_add_data(iStudy, OutputFiles{iFile}, ResultsMat);
end

% Update tree
panel_protocols('UpdateNode', 'Study', iStudy);
% Save database
db_save();

% Progress bar
if ~isProgressBar
    bst_progress('stop');
end

end


%% ====== SUPPORT FUNCTIONS =====
% Load source map
function [map, grid] = in_sources(SourceFile, FileFormat)
    grid = [];
    switch (FileFormat)
        case 'FS'
            map = read_curv(SourceFile);
        case 'CIVET'
            map = load(SourceFile, '-ascii');
        case 'GII'
            % Load .gii information
            [sXml, Values] = in_gii(SourceFile);
            % Stack all the maps
            for i = 1:length(Values)
                % Transpose row vectors
                if (size(Values{i},1) == 1)
                    Values{i} = Values{i}';
                end
                % First map
                if (i == 1)
                    map = Values{i};
                % Following maps: stack if same dimensions
                elseif (size(map,2) == size(Values{i},2))
                    map = [map, Values{i}];
                end
            end
        case 'ALLMRI'
            % Read MRI volume
            [sMriSrc, vox2ras] = in_mri(SourceFile, 'ALL', 0, 0);
            % Get position of non-zero points
            iNonZero = find(sMriSrc.Cube);
            [X,Y,Z] = ind2sub(size(sMriSrc.Cube), iNonZero);
            grid = [X .* sMriSrc.Voxsize(1), Y .* sMriSrc.Voxsize(2), Z .* sMriSrc.Voxsize(3)];
%             grid = [X,Y,Z];
%             % Apply vox2raw transformation
%             if ~isempty(vox2ras)
%                 grid = bst_bsxfun(@plus, vox2ras(1:3,1:3) * grid', vox2ras(1:3,4))';
%             end
            % Convert to meters
            grid = grid ./ 1000;
            % Get values of non-zero points
            map = double(sMriSrc.Cube(iNonZero));
        case 'ALLMRI-MNI'
            error('Not supported yet.');
        otherwise
            error('Unsupported file format.');
    end
end



