function DataMat = in_bst_data( DataFile, varargin )
% IN_BST_DATA: Load a Brainstorm Data file, and compute missing fields.
%
% USAGE:  DataMat = in_bst_data( DataFile, FieldsToRead );
%         DataMat = in_bst_data( DataFile );
% INPUT: 
%     - DataFile    : full path to a recordings file
%     - FieldsToRead: List of strings decribing the fields to be read in the file
% OUTPUT:
%     - DataMat:  Brainstorm MRI structure

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
% Authors: Francois Tadel, 2009-2022


% ===== PARSE INPUTS =====
% Full file name
if ~file_exist(DataFile)
    DataFile = file_fullpath(DataFile);
end
if ~file_exist(DataFile)
    error(['Data file was not found: ' 10 file_short(DataFile) 10 'Please reload this protocol (right-click > reload).']);
end
% Get file in database
isRaw = (length(DataFile) > 9) && ~isempty(strfind(DataFile, 'data_0raw'));

% Fields to read
isAddF = 0;
isAddZScore = 0;
if isempty(varargin)
    file_whos = whos('-file', DataFile);
    FieldsToRead = union({file_whos.name}, fieldnames(db_template('datamat')));
else
    FieldsToRead = varargin;
    if iscell(FieldsToRead{1})
        FieldsToRead = FieldsToRead{1};
    end
    % Remove empty strings
    FieldsToRead = setdiff(FieldsToRead, {''});
    % If there is F without ChannelFlag, add it
    if ismember('F', FieldsToRead) && ~ismember('ChannelFlag', FieldsToRead)
        FieldsToRead{end + 1} = 'ChannelFlag';
    end
    % If reading Time in a raw file: need F (=sFile)
    if isRaw && ismember('Time', FieldsToRead) && ~ismember('F', FieldsToRead)
        FieldsToRead{end + 1} = 'F';
        isAddF = 1;
    end
    % Always read ZScore field
    if ~isRaw && ismember('F', FieldsToRead) && ~ismember('ZScore', FieldsToRead)
        FieldsToRead{end + 1} = 'ZScore';
        isAddZScore = 1;
    end
    % When reading Leff, make sure nAvg is read as well
    if ~isRaw && ismember('Leff', FieldsToRead) && ~ismember('nAvg', FieldsToRead)
        FieldsToRead{end + 1} = 'nAvg';
    end
end

% ===== LOAD FILE =====
try
    warning off
    DataMat = load(DataFile, FieldsToRead{:});
    warning on
catch
    error(['Cannot load recordings file: "' DataFile '".' 10 10 lasterr]);
end

% ===== RAW: TIME VECTOR =====
if isRaw && ismember('Time', FieldsToRead)
    DataMat.Time = panel_time('GetRawTimeVector', DataMat.F);
end

% ===== MISSING FIELDS =====
for i = 1:length(FieldsToRead)
    if ~isfield(DataMat, FieldsToRead{i}) || isempty(DataMat.(FieldsToRead{i}))
        switch(FieldsToRead{i})
            case 'DataType'
                DataMat.DataType = 'recordings';
            case 'nAvg'
                DataMat.nAvg = 1;
            case 'Leff'
                if isfield(DataMat, 'nAvg') && ~isempty(DataMat.nAvg)
                    DataMat.Leff = DataMat.nAvg;
                else
                    DataMat.Leff = 1;
                end
            otherwise
                DataMat.(FieldsToRead{i}) = [];
        end
    end
end
% Remove F field
if isAddF
    DataMat = rmfield(DataMat, 'F');
    FieldsToRead = setdiff(FieldsToRead, 'F');
end

% ===== APPLY Z-SCORE =====
% DEPRECATED
if ismember('ZScore', FieldsToRead) && ~isempty(DataMat.ZScore)
    DataMat.F = process_zscore_dynamic('Compute', DataMat.F, DataMat.ZScore);
    DataMat = rmfield(DataMat, 'ZScore');
elseif isAddZScore
    DataMat = rmfield(DataMat, 'ZScore');
end

% ===== FIX BROKEN RAW LINKS =====
if isfield(DataMat, 'F') && isstruct(DataMat.F) && ~isempty(DataMat.F.filename) && ~file_exist(DataMat.F.filename)
    % Try to look for the file in the current study folder
    studyPath = bst_fileparts(DataFile);
    [rawPath, rawBase, rawExt] = bst_fileparts(DataMat.F.filename);
    newRaw = bst_fullfile(studyPath, [rawBase, rawExt]);
    % If not found, try to look for the file in the same file system
    if ~file_exist(newRaw)
        % Identify the OS for the raw link path
        waspc = isempty(regexp(DataMat.F.filename, '/', 'once')); % '/' is forbidden char in Windows paths
        % Linux/MacOS -> Linux/MacOS
        if ~ispc()
            % Get mountpoint
            [status, dfResult] = system(['df ' DataFile]);
            if ~status % no error
                dfLines = str_split(dfResult, 10);
                iChar = regexp(dfLines{1}, 'Mounted on');
                mountpoint = dfLines{2}(iChar:end);
                % Update raw link path
                if ~waspc
                    % Replace mountpoint
                    [mountDir, mountLabel] = bst_fileparts(mountpoint);
                    iCharRelMount = regexp(DataMat.F.filename, mountLabel);
                    newRaw = bst_fullfile(mountDir, DataMat.F.filename(iCharRelMount:end));
                else
                    % Replace drive letter with mountpoint
                    pathTmp = file_win2unix(DataMat.F.filename);
                    pathTmp = regexprep(pathTmp, '^[A-Z]:/', '');
                    newRaw = bst_fullfile(mountpoint, pathTmp);
                end
            end
        else
            % Get drive letter
            tmp = DataFile;
            driverLetter = '';
            while ~strcmp(tmp, driverLetter)
                driverLetter = tmp;
                tmp = bst_fileparts(tmp);
            end
            % Update raw link path
            if ~waspc
                tmp = DataMat.F.filename;
                % Remove common mountpoints
                tmp2 = regexprep(tmp, '^/Volumes/.*?/', '');
                if strcmp(tmp2, tmp)
                    tmp2 = regexprep(tmp, '^.*/media/.*?/.*?/', '');
                end
                % Add driverletter
                newRaw = bst_fullfile(driverLetter, tmp2);
            else
                % Replace old drive letter
                newRaw = regexprep(DataMat.F.filename, '^[A-Z]:/', driverLetter);
            end
        end
    end
    % If the corrected file exists
    if file_exist(newRaw)
        % Update the file in the returned structure
        DataMat.F.filename = newRaw;
        % Replace the link in the file
        UpdateMat.F = DataMat.F;
        bst_save(DataFile, UpdateMat, 'v6', 1);
    end
end
    
% ===== FIX TRANSPOSED TIME VECTOR =====
if isfield(DataMat, 'Time') && (size(DataMat.Time,1) > 1)
    DataMat.Time = DataMat.Time';
end

% ===== FIX EVENTS STRUCTURES =====
% Imported file
if isfield(DataMat, 'Events') && ~isempty(DataMat.Events)
    [DataMat.Events, isModified] = struct_fix_events(DataMat.Events);
    % Update file if it was modified
    if isModified
        UpdateMat.Events = DataMat.Events;
        bst_save(DataFile, UpdateMat, 'v6', 1);
    end
end
% Link to raw file
if isfield(DataMat, 'F') && ~isempty(DataMat.F) && isstruct(DataMat.F) && isfield(DataMat.F, 'events') && ~isempty(DataMat.F.events)
    [DataMat.F.events, isModified] = struct_fix_events(DataMat.F.events);
    % Update file if it was modified
    if isModified
        UpdateMat.F = DataMat.F;
        bst_save(DataFile, UpdateMat, 'v6', 1);
    end
end



                