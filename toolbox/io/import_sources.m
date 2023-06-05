function [OutputFile, errorMsg] = import_sources(iStudy, SurfaceFile, SourceFiles, SourceFiles2, FileFormat, Comment, DisplayUnits, TimeVector)
% IMPORT_SOURCES: Imports static source maps as results files.
% 
% USAGE:  OutputFile = import_sources(iStudy, SurfaceFile, SourceFiles, SourceFiles2=[], FileFormat=[], Comment=[], DisplayUnits=[], TimeVector=[])
%
% INPUT:
%    - iStudy       : Index of the study where to import the SourceFiles
%    - SurfaceFile  : Surface from the Brainstorm database on which the maps have to be displayed
%    - SourceFiles  : Full filename, or cell array of filenames, of the source maps to import
%                     => if not specified : file to import is asked to the user who should select
%                     the left and right files at the same time
%    - SourceFiles2 : In the case of left/right files to import as one joined matrix (FreeSurfer import)
%                     SourceFiles = left files and SourceFiles2 = right files
%    - FileFormat   : One of the available file formats ('FS')
%    - Comment      : Comment of the output file
%    - DisplayUnits : What to save in the field DisplayUnits of the new files

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
% Authors: Francois Tadel, 2013-2017
%          Raymundo Cassani, 2023

%% ===== PARSE INPUTS =====
% Initialize returned variables
OutputFile = [];
errorMsg = [];
% Get default for all the inputs
if (nargin < 8) || isempty(TimeVector)
    TimeVector = [];
end
if (nargin < 7) || isempty(DisplayUnits)
    DisplayUnits = [];
end
if (nargin < 6) || isempty(Comment)
    Comment = [];
end
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
             {'*.w'}, 'FreeSurfer weight files (*.w)',    'FS-WFILE'; ...
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
    % Make hemispheres pairs
    if length(SourceFiles) > 1
        [~, baseSourceFiles, extSourceFiles] = cellfun(@(std) bst_fileparts(std), SourceFiles, 'UniformOutput', false);
        shortSourceFiles = strcat(baseSourceFiles, extSourceFiles);
        % Find left- and right-hemisphere files
        leftFileIxs  = find(cellfun(@(std) ~isempty(regexp(std,'(lh\.|_left)', 'once')), shortSourceFiles));
        rightFileIxs = find(cellfun(@(std) ~isempty(regexp(std,'(rh\.|_right)', 'once')), shortSourceFiles));
        % Check for paired files
        if ~isempty(leftFileIxs) && ~isempty(rightFileIxs) && isempty(intersect(leftFileIxs, rightFileIxs))
            SourceFiles1 = [];
            cleanLeftNames  = cellfun(@(std) strrep(strrep(std, 'lh.', ''), '_left', ''), shortSourceFiles(leftFileIxs), 'UniformOutput', false);
            cleanRightNames = cellfun(@(std) strrep(strrep(std, 'rh.', ''), '_right', '') , shortSourceFiles(rightFileIxs), 'UniformOutput', false);
            % Intersect of clean names must be the same
            if isequal(sort(cleanLeftNames), sort(cleanRightNames))
                % Find corresponding right file
                for iLeft = 1 : length(cleanLeftNames)
                    cleanLeftName = cleanLeftNames{iLeft};
                    rightFileIx   = strcmp(cleanLeftName, cleanRightNames);
                    SourceFiles1{end+1} = SourceFiles{leftFileIxs(iLeft)};
                    SourceFiles2{end+1}  = SourceFiles{rightFileIxs(rightFileIx)};
                end
                SourceFiles = SourceFiles1;
            else
                errorMsg = 'Left and right hemisphere files must be provided in pairs.';
                bst_error(errorMsg, 'Import source maps', 0);
            end
            % Check matching sizes of SourceFiles and SourceFiles2
            if ~isempty(SourceFiles2) && (length(SourceFiles2) ~= length(SourceFiles))
                errorMsg = 'Length of arguments SourceFiles and SourceFiles2 must match.';
                bst_error(errorMsg, 'Import source maps', 0);
            end
        end
    end
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
% If surface file not specified: get a default surface
if isempty(SurfaceFile)
    % Volume: Inner skull, Head, Cortex
    if ismember(FileFormat, {'ALLMRI', 'ALLMRI-MNI'})
        if ~isempty(sSubject.iInnerSkull) && (sSubject.iInnerSkull <= length(sSubject.Surface))
            SurfaceFile = sSubject.Surface(sSubject.iInnerSkull).FileName;
        elseif ~isempty(sSubject.iScalp) && (sSubject.iScalp <= length(sSubject.Surface))
            SurfaceFile = sSubject.Surface(sSubject.iScalp).FileName;
        elseif ~isempty(sSubject.iCortex) && (sSubject.iCortex <= length(sSubject.Surface))
            SurfaceFile = sSubject.Surface(sSubject.iCortex).FileName;
        end
    % Surface: Cortex only
    elseif ~isempty(sSubject.iCortex) && (sSubject.iCortex <= length(sSubject.Surface))
        SurfaceFile = sSubject.Surface(sSubject.iCortex).FileName;
    end
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
    sSurf = in_tess_bst(SurfaceFile);
    nVertices = size(sSurf.Vertices,1);
    [rH, lH] = tess_hemisplit(sSurf);
    nVerticesLeft =  length(lH);
    nVerticesRight =  length(rH);
end


%% ===== READ SOURCE FILES =====
sMri = [];
maps = cell(1, length(SourceFiles));
SPM = cell(1, length(SourceFiles));
% Loop on each input file
for iFile = 1:length(SourceFiles)
    % === GET FILE TYPE ===  
    % Comment: Use the base filename (if not defined in input)
    [fPath, fBase, fExt] = bst_fileparts(SourceFiles{iFile});
    if isempty(Comment)
        if strcmpi(FileFormat, 'FS')
            Comment = [fBase, fExt];
        else
            Comment = fBase;
        end
        Comment = strrep(Comment, 'results_', '');
        Comment = strrep(Comment, '_results', '');
        % If the two files are imported: remove .lh and .rh
        if ~isempty(SourceFiles2)
            Comment = strrep(Comment, 'rh.', '');
            Comment = strrep(Comment, 'lh.', '');
            Comment = strrep(Comment, '_left', '');
            Comment = strrep(Comment, '_right', '');
        end
    end
    % Stat file or regular map
    isStat = ~isempty(strfind(fBase, 'spmT')) && file_exist(bst_fullfile(fPath, 'SPM.mat'));
    if isStat
        bgValue = 0;
    else
        bgValue = NaN;
    end

    % === LOAD FILE ===
    % Read source file
    [maps{iFile}, grid, sMriSrc] = in_sources(SourceFiles{iFile}, FileFormat, bgValue, nVerticesLeft);
    % In the case of a volume grid: convert from MRI coordinates to SCS
    if ~isempty(grid)
        % Load subject MRI
        if isempty(sMri)
            sMri = in_mri_bst(sSubject.Anatomy(sSubject.iAnatomy).FileName);
        end
        % Convert from RAS(source files) to RAS(subject anat)
        if isfield(sMri, 'InitTransf') && ~isempty(sMri.InitTransf) && ismember('vox2ras', sMri.InitTransf(:,1))
            iTransf = find(strcmpi(sMri.InitTransf(:,1), 'vox2ras'));
            ras2vox = inv(sMri.InitTransf{iTransf,2});
            grid = bst_bsxfun(@plus, ras2vox(1:3,1:3) * grid', ras2vox(1:3,4))';
        end
        % Convert MRI=>SCS
        grid = cs_convert(sMri, 'voxel', 'scs', grid);
    end
    % Read additional source file: simply concatenate to the previous one
    if ~isempty(SourceFiles2)
        maps{iFile} = [maps{iFile}; in_sources(SourceFiles2{iFile}, FileFormat, bgValue, nVerticesRight)];
    end
    % Check the number of sources
    if isempty(maps{iFile})
        errorMsg = ['File could not be read: ', SourceFiles{iFile}];
        if isInteractive
            bst_error(errorMsg, 'Import source maps', 0);
        end
        break;
    elseif isempty(grid) && (size(maps{iFile},1) ~= nVertices)
        errorMsg = sprintf('The number of vertices in the surface (%d) and the source map (%d) do not match.', nVertices, size(maps{iFile},1));
        if isInteractive
            bst_error(errorMsg, 'Import source maps', 0);
        end
        break;
    end
    % Load SPM results
    if isStat
        % Load SPM.mat
        SpmMat = load(fullfile(fPath, 'SPM.mat'));
        SPM{iFile} = SpmMat.SPM;
        % Add sorted T values in the file if importing from a volume (not keeping the full distribution otherwise)
        if ~isempty(grid)
            SPM{iFile}.SortedT = sort(sMriSrc.Cube(:));
        end
    end
end
% Concatenate in time all the selected files
map = cat(2, maps{:});

% === STATISTICAL THRESHOLD (SPM) ===
if isStat
    % New stat/results structure
    ResultsMat = db_template('statmat');
    ResultsMat.tmap       = map;
    ResultsMat.pmap       = [];
    ResultsMat.df         = [];
    ResultsMat.SPM        = SPM;
    ResultsMat.Correction = 'no';
    ResultsMat.Type       = 'results';
    FileType = 'presults';
    % Time vector
    if isempty(TimeVector) || (length(TimeVector) ~= size(ResultsMat.tmap,2))
        ResultsMat.Time = 0:(size(map,2)-1);
    else
        ResultsMat.Time = TimeVector;
    end
% === REGULAR SOURCE FILE ===
else
    % New results structure
    ResultsMat = db_template('resultsmat');
    ResultsMat.ImageGridAmp  = [map, map];
    ResultsMat.ImagingKernel = [];
    FileType = 'results';
    % Time vector
    if isempty(TimeVector) || (length(TimeVector) ~= size(ResultsMat.ImageGridAmp,2))
        ResultsMat.Time = 0:(size(map,2)-1);
    else
        ResultsMat.Time = TimeVector;
    end
end
% Fix identical time points
if (length(ResultsMat.Time) == 2) && (ResultsMat.Time(1) == ResultsMat.Time(2))
    ResultsMat.Time(2) = ResultsMat.Time(2) + 0.001;
end

% === SAVE NEW FILE ===
ResultsMat.Comment       = Comment;
ResultsMat.DataFile      = [];
ResultsMat.SurfaceFile   = file_win2unix(file_short(SurfaceFile));
ResultsMat.HeadModelFile = [];
ResultsMat.nComponents   = 1;
ResultsMat.DisplayUnits  = DisplayUnits;
if isequal(DisplayUnits, 's')
    ResultsMat.ColormapType = 'time';
end
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
OutputFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [FileType, '_', ResultsMat.HeadModelType, '_', file_standardize(Comment)]);
% Save new file
bst_save(OutputFile, ResultsMat, 'v7');
% Update database
db_add_data(iStudy, OutputFile, ResultsMat);

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
function [map, grid, sMriSrc] = in_sources(SourceFile, FileFormat, bgValue, nVertices)
    grid = [];
    sMriSrc = [];
    switch (FileFormat)
        case 'FS'
            map = read_curv(SourceFile);
        case 'FS-WFILE'
            map = zeros(nVertices, 1);
            [w,v] = read_wfile(SourceFile);
            % Weight files are zero indexed
            v = v + 1;
            if max(v) > nVertices
                map = [];
            else
                map(v) = w;
            end
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
            if isnan(bgValue)
                iForeground = find(~isnan(sMriSrc.Cube));
            else
                iForeground = find(sMriSrc.Cube ~= bgValue);
            end
            [X,Y,Z] = ind2sub(size(sMriSrc.Cube), iForeground);
            % Apply vox2ras transformation
            if ~isempty(vox2ras)
                grid = [X,Y,Z];
                grid = bst_bsxfun(@plus, vox2ras(1:3,1:3) * grid', vox2ras(1:3,4))';
            else
                grid = [X .* sMriSrc.Voxsize(1), Y .* sMriSrc.Voxsize(2), Z .* sMriSrc.Voxsize(3)];
            end
            % Get values of non-zero points
            map = double(sMriSrc.Cube(iForeground));
            % Replace 0 values with small values
            if isnan(bgValue)
                map(map == 0) = eps;
            end
        case 'ALLMRI-MNI'
            error('Not supported yet.');
        otherwise
            error('Unsupported file format.');
    end
    % Get rid of NaN values
    isNan = isnan(map);
    if any(isNan(:))
        % If there are zero values: replace them with a small value
        isZero = (map == 0);
        if any(isZero(:))
            map(isZero) = eps;
        end
        % Remove NaN values
        map(isNan) = 0;
    end
end



