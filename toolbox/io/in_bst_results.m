function [Results, ResultsFile] = in_bst_results(ResultsFile, LoadFull, varargin)
% IN_BST_RESULTS: Read a sources file in Brainstorm format.
% 
% USAGE:  Results = in_bst_results(ResultsFile, LoadFull, FieldsList) : Read the specified fields
%         Results = in_bst_results(ResultsFile, LoadFull)             : Read all the fields
%         Results = in_bst_results(ResultsFile)                       : Read all the fields and do NOT multiply kernel with data
% 
% INPUT:
%    - ResultsFile : Absolute or relative path to the sources file to read
%    - LoadFull    : If 1, and if file is a "Kernel only" file, load the data, compute Kernel*Data to get the full sources time series
%    - FieldsList  : List of fields to read from the file
% OUTPUT:
%    - Results     : Brainstorm source file structure
%    - ResultsFile : Full path to resolved results file

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
% Authors: Francois Tadel, 2009-2016


%% ===== PARSE INPUTS =====
if (nargin < 2) || isempty(LoadFull)
    LoadFull = 0;
end
% Get protocol folders
ProtocolInfo = bst_get('ProtocolInfo');
% Resolve link
[ResultsFile, DataFile] = file_resolve_link(ResultsFile);
if ~file_exist(ResultsFile)
    error(['Source file was not found: ' 10 file_short(ResultsFile) 10 'Please reload this protocol (right-click > reload).']);
end

% Specific fields
if (nargin < 3)
    % Read all fields
    Results = load(ResultsFile);
    % Get all the fields
    FieldsToRead = fieldnames(Results);
    FieldsToRead{end + 1} = 'GoodChannel';
    FieldsToRead{end + 1} = 'SurfaceFile';
    FieldsToRead{end + 1} = 'nComponents';
    FieldsToRead{end + 1} = 'ZScore';
    FieldsToRead{end + 1} = 'nAvg';
    FieldsToRead{end + 1} = 'Function';
    FieldsToRead{end + 1} = 'DataFile';
else
    % Get fields to read
    FieldsToRead = varargin;
    % If one field is required between "ImageGridAmp" or "ImagingKernel", always read both
    if any(ismember({'ImageGridAmp','ImagingKernel'}, FieldsToRead))
        FieldsToRead{end + 1} = 'ImagingKernel';
        FieldsToRead{end + 1} = 'ImageGridAmp';
        FieldsToRead{end + 1} = 'GoodChannel';
        FieldsToRead{end + 1} = 'OPTIONS';
        FieldsToRead{end + 1} = 'ZScore';
        FieldsToRead{end + 1} = 'nAvg';
        FieldsToRead{end + 1} = 'Time';
        FieldsToRead{end + 1} = 'Function';
        FieldsToRead{end + 1} = 'DataFile';
    end
    % If full results are required, add also "DataFile"
    if LoadFull
        FieldsToRead{end + 1} = 'DataFile';
    end
    % If accessing time: add old field ImageGridTime
    if ismember('Time', FieldsToRead)
        FieldsToRead{end + 1} = 'ImageGridTime';
    end
%     % If user want "SurfaceFile", also read "SourceLoc"
%     if ismember('SurfaceFile', FieldsToRead)
%         FieldsToRead{end + 1} = 'SourceLoc';
%     end
    % Read each field only once
    FieldsToRead = unique(FieldsToRead);
    % Read specified files only
    warning off MATLAB:load:variableNotFound
    Results = load(ResultsFile, FieldsToRead{:});
    warning on MATLAB:load:variableNotFound
end


%% ===== READ SURFACE FILE =====
% If SurfaceFile was required 
if ismember('SurfaceFile', FieldsToRead) 
    % If SurfaceFile not found, try with SourceLoc
    if ~isfield(Results, 'SurfaceFile') 
        if isfield(Results, 'SourceLoc') && ischar(Results.SourceLoc)
            Results.SurfaceFile = Results.SourceLoc;
        else
            Results.SurfaceFile = '';
        end
    end
    % If SurfaceFile is not defined: give a fake surface name, that will be fixed in the next block
    if isempty(Results.SurfaceFile) 
        Results.SurfaceFile = 'xxxxxxxx';
    end
                
    % ===== SURFACE FILE WAS RENAMED ======
    % If SurfaceFile does not exist: try to find an existing surface that fits this results file
    oldSurfaceFile = bst_fullfile(ProtocolInfo.SUBJECTS, Results.SurfaceFile);
    if ~file_exist(oldSurfaceFile)
        % Get the type of results data (normal or stat)
        isStat = strcmpi(file_gettype(ResultsFile), 'presults');
        
        % === GET POSSIBLE SURFACES ===
        % Get subject corresponding to this results file
        if ~isStat
            sStudy = bst_get('ResultsFile', ResultsFile);
        else
            sStudy = bst_get('StatFile', ResultsFile);
        end
        if isempty(sStudy)
            error('File is not registered in database.');
        end
        % Get surfaces list
        sCortexList = bst_get('SurfaceFileByType', sStudy.BrainStormSubject, 'Cortex', 0);

        % === GET NUMBER OF SOURCES ===
        % Get the number of sources in the current file
        warning off
        resMat = load(ResultsFile, 'ImageGridAmp', 'ImagingKernel', 'tmap', 'nComponents');
        warning on
        if isfield(resMat, 'ImageGridAmp') && ~isempty(resMat.ImageGridAmp)
            nVerticesRes = max(size(resMat.ImageGridAmp, 1));
        elseif isfield(resMat, 'ImagingKernel') && ~isempty(resMat.ImagingKernel)
            nVerticesRes = max(size(resMat.ImagingKernel, 1));
        elseif isfield(resMat, 'tmap') && ~isempty(resMat.tmap)
            nVerticesRes = max(size(resMat.tmap, 1));
        else
            error('Invalid source file.');
        end
        % Error for mixed head models
        if isfield(resMat, 'nComponents') && (resMat.nComponents == 0)
            bst_error(['The cortex file associated with these sources no longer exists.' 10 'Please recalculate the source file.'], 'Load results', 0);
        end
        % Divide by the number of components for each vertex
        if isfield(resMat, 'nComponents') && ~isempty(resMat.nComponents)
            nVerticesRes = nVerticesRes ./ resMat.nComponents;
        end

        % === FIND VALID SURFACE ===
        % Look for each surface if the number of vertices fits the results file
        isFound = 0;
        for i = 1:length(sCortexList)
            % Get the number of vertices
            newSurfaceFile = file_win2unix(sCortexList(i).FileName);
            file_whos = whos('-file', bst_fullfile(ProtocolInfo.SUBJECTS, newSurfaceFile), 'Vertices');
            nVerticesSurf = max(file_whos.size);
            % If number of vertices match: change surface
            if (nVerticesSurf == nVerticesRes) || (isfield(Results, 'HeadModelType') && strcmpi(Results.HeadModelType, 'volume'))
                % Display warning
                java_dialog('warning', ['The cortex file associated with these sources no longer exists.' 10 ...
                                        'Using instead: ' newSurfaceFile], 'Load results');
                % Update field in sources file
                s.SurfaceFile = newSurfaceFile;
                bst_save(ResultsFile, s, 'v7', 1);
                % Return new field
                Results.SurfaceFile = newSurfaceFile;
                % Exit loop
                isFound = 1;
                break;
            end
        end
        % If valid surface file was not found
        if ~isFound
            if ~isempty(sCortexList)
                error(['The cortex file associated with these sources no longer exists.' 10 ...
                       'Please import the anatomy and compute the sources again.']);
            else
                Results.SurfaceFile = [];
            end
        end
    end
end

%% ===== GOOD CHANNELS =====
if ismember('GoodChannel', FieldsToRead)
    if isfield(Results, 'OPTIONS') && ~isempty(Results.OPTIONS) && isfield(Results.OPTIONS, 'GoodChannel') && ~isempty(Results.OPTIONS.GoodChannel)
        Results.GoodChannel = Results.OPTIONS.GoodChannel;
    elseif isfield(Results, 'GoodChannel') && ~isempty(Results.GoodChannel)
        % Keep it, nothing to do
    else
        %error('Missing field GoodChannel in source file.');
        Results.GoodChannel = [];
    end
end

%% ===== TIME =====
if isfield(Results, 'ImageGridTime')
    Results.Time = Results.ImageGridTime;
    Results = rmfield(Results, 'ImageGridTime');
end

%% ===== FILL OTHER MISSING FIELDS =====
for i = 1:length(FieldsToRead)
    if ~isfield(Results, FieldsToRead{i})
        switch(FieldsToRead{i}) 
            case 'Time'
                Results.Time = [1 2];
            case 'nComponents'
                if ~isempty(strfind(ResultsFile, '_unconstr'))
                    Results.nComponents = 3;
                else
                    Results.nComponents = 1;
                end
            case 'nAvg'
                Results.nAvg = [];
            case 'HeadModelType'
                Results.HeadModelType = 'surface';
            case 'ImageGridTime'
                % Just ignore
            case 'Function'
                Results.Function = 'wmne';
            otherwise
                Results.(FieldsToRead{i}) = [];
        end
    end
end


%% ===== DATA FILE =====
DataFileFull = '';
if isfield(Results, 'DataFile')
    % Get DataFile reference from file
    if ~isempty(DataFile)
        Results.DataFile = file_short(DataFile);
    end
%     % If file doesn't exist: maybe it is relative
%     if ~isempty(Results.DataFile) && ~file_exist(Results.DataFile)
%         Results.DataFile = bst_fullfile(ProtocolInfo.STUDIES, Results.DataFile);
%     end
    % Get full data file path
    if ~isempty(Results.DataFile)
        DataFileFull = file_fullpath(Results.DataFile);
    end
end

    

%% ===== GRID LOC =====
if isfield(Results, 'GridLoc') && ~isempty(Results.GridLoc)
    % Check matrix orientation
    if (size(Results.GridLoc,2) ~= 3)
        Results.GridLoc = Results.GridLoc';
    end
end
    
%% ===== COMPUTE FULL RESULTS =====
DataMat = [];
if LoadFull && isfield(Results, 'ImageGridAmp') && isempty(Results.ImageGridAmp) && ~isempty(Results.ImagingKernel)
    if ~isempty(DataFileFull) && file_exist(DataFileFull)
        % Load data
        DataMat = load(DataFileFull, 'F', 'Time', 'nAvg');
        % Reading continuous recordings
        if isstruct(DataMat.F)
            error('Cannot use this operation on source files attached to continuous RAW files.');
        end
        % Multiply kernel with recordings
        Results.ImageGridAmp = Results.ImagingKernel * DataMat.F(Results.GoodChannel, :);
        % Remove kernel
        Results.ImagingKernel = [];
        % If time is required
        if ismember('Time', FieldsToRead)
            Results.Time = DataMat.Time;
        end
    else
        error('Data file not found for this sources kernel.');
    end
% Get data Time vector
elseif LoadFull && ismember('Time', FieldsToRead) && isempty(Results.Time) && ~isempty(DataFileFull) && file_exist(DataFileFull)
    % Load data
    DataMat = in_bst_data(Results.DataFile, 'Time', 'nAvg');
    Results.Time = DataMat.Time;
% Get the number of averages for dSPM, GLS, and LCMV
elseif isfield(Results, 'Function') && ismember(Results.Function, {'dspm', 'glsp', 'lcmvp'}) && ~isempty(DataFileFull) && file_exist(DataFileFull)
    DataMat = in_bst_data(Results.DataFile, 'nAvg');
end


%% ===== SCALE VALUES WITH SNR CHANGES =====
% OLD VERSIONS: If nAvg is not saved in the results file, then read it from the data file
% (now nAvg is always saved in the source files)
if isfield(Results, 'nAvg') && isempty(Results.nAvg)
    if ~isempty(DataMat) && isfield(DataMat, 'nAvg') && ~isempty(DataMat.nAvg)
        Results.nAvg = DataMat.nAvg;
    else
        Results.nAvg = 1;
    end
end
% Apply a scaling to the dSPM/GLSp/lcmvp functions, to compensate for the
% fact that the scaling applied to the NoiseCov was not correct The
% situation often arises when the noise covariance was based on "raw"
% (unaveraged) data, but the kernel is now being applied to an averaged
% data set.
if isfield(Results, 'Function') && ismember(Results.Function, {'dspm','glsp','lcmvp'}) && isfield(Results, 'ImageGridAmp') && ~isempty(DataMat)
    if (DataMat.nAvg ~= Results.nAvg)
        Factor = sqrt(DataMat.nAvg) / sqrt(Results.nAvg);
        disp(sprintf('BST> Loading %s maps: scaling the values by %1.2f to match the number of trials averaged (%d => %d)', Results.Function, Factor, Results.nAvg, DataMat.nAvg));
        % Apply on full source matrix or kernel
        if ~isempty(Results.ImageGridAmp)
            Results.ImageGridAmp = Factor * Results.ImageGridAmp;
        elseif ~isempty(Results.ImagingKernel)
            Results.ImagingKernel = Factor * Results.ImagingKernel;
        end
    end
end


%% ===== APPLY Z-SCORE =====
% Check for structure integrity
if ismember('ZScore', FieldsToRead) && ~isempty(Results.ZScore) && (~isfield(Results.ZScore, 'mean') || ~isfield(Results.ZScore, 'std') || ~isfield(Results.ZScore, 'abs') || ~isfield(Results.ZScore, 'baseline') || isempty(Results.ZScore.abs))
    Results.ZScore = [];
end
% Apply to full sources (ImageGridAmp)
if ismember('ZScore', FieldsToRead) && ismember('ImageGridAmp', FieldsToRead) && ~isempty(Results.ZScore) && ~isempty(Results.ImageGridAmp)
    Results.ImageGridAmp = process_zscore_dynamic('Compute', Results.ImageGridAmp, Results.ZScore, Results.Time);
    Results = rmfield(Results, 'ZScore');
end

% ===== FIX TRANSPOSED TIME VECTOR =====
if isfield(Results, 'Time') && (size(Results.Time,1) > 1)
    Results.Time = Results.Time';
end





