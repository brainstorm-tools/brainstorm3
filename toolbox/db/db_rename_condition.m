function db_rename_condition( oldPath, newPath, isMove, isUpdateStudyPath )
% DB_RENAME_CONDITION: Rename a condition in the Brainstorm database.
%
% USAGE:  db_rename_condition( oldPath, newPath, isMove=1, isUpdateStudyPath=1)
%         db_rename_condition( oldPath, newPath )
% 
% INPUT:
%    - oldPath : Condition path to modify ("SubjectName/ConditionName", or "*/ConditionName")
%    - newPath : New condition path
%    - isMove  : If 1, actually rename the folders 
%                Set to 0 when renaming a subject (moving entire subject folder at once)
%    - isUpdateStudyPath: If 1, modify the study path
%                         If 0, only update the file links

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
% Authors: Francois Tadel, 2009-2014

% Parse inputs
if (nargin < 4) || isempty(isUpdateStudyPath)
    isUpdateStudyPath = 1;
end
if (nargin < 3) || isempty(isMove)
    isMove = 1;
end
% No modification
if strcmpi(oldPath, newPath)
    return;
end
oldPath = strrep(oldPath, '\', '/');
newPath = strrep(newPath, '\', '/');

%% ===== MULTIPLE RENAMING =====
if any(oldPath == '*')
    % Get all the studies concerned by the modification
    sStudies = db_get('StudyWithCondition', oldPath, 'FileName');
    if isempty(sStudies)
        disp(['RENAME> Condition "' oldPath '" does not exist.']);
        return;
    end
    % Recursive calls
    for i = 1:length(sStudies)
        % Get subject/condition names
        [SubjectName, oldCond] = bst_fileparts(bst_fileparts(sStudies(i).FileName), 1);
        [tmp__, newCond] = bst_fileparts(newPath, 1);
        % Rename
        db_rename_condition(bst_fullfile(SubjectName,oldCond), bst_fullfile(SubjectName,newCond), isMove);
    end
    return
end
% Progress bar
bst_progress('start', 'Rename condition', ['Rename: ' oldPath ' => ' newPath]);


%% ===== PREPARING =====
% Get protocol directories
ProtocolInfo = bst_get('ProtocolInfo');
% Get subject/condition names
[oldSubj, oldCond] = bst_fileparts(oldPath, 1);
[newSubj, newCond] = bst_fileparts(newPath, 1);
% Check that old condition exists
if ~isdir(bst_fullfile(ProtocolInfo.STUDIES, oldPath))
    bst_error(['Folder "' oldPath '" does not exists.'], 'Rename', 0);
    return;
end
% Check that new condition does not exist
if isMove && isdir(bst_fullfile(ProtocolInfo.STUDIES, newPath))
    bst_error(['Folder "' newPath '" already exists.'], 'Rename', 0);
    return;
end


%% ===== RENAME FOLDER =====
% Move the folder
if isMove
    isOk = file_move(bst_fullfile(ProtocolInfo.STUDIES, oldPath), bst_fullfile(ProtocolInfo.STUDIES, newPath));
    if ~isOk
        bst_error(['Error: Could not rename "' oldPath '" to "' newPath '".'], 'Rename', 0);
        return;
    end
end


%% ===== UPDATE ALL THE FILES =====
% Get study structure
sqlConn = sql_connect();
sStudy = db_get(sqlConn, 'StudyWithCondition', oldPath);

if isempty(sStudy)
    sql_close(sqlConn);
    return
end

% Update study
if isUpdateStudyPath
    sStudy = replaceStruct(sStudy, 'FileName', oldPath, newPath);
    %sStudy = replaceStruct(sStudy, 'Name',     oldPath, newPath);
    sStudy.Name = newCond;
    sStudy.Condition = newCond;
    % Update sStudy in database
    db_set(sqlConn, 'Study', sStudy, sStudy.Id);
end

% Update functional files
sFunctFiles = db_get(sqlConn, 'FilesWithStudy', sStudy.Id);
for ix = 1 : length(sFunctFiles)
    sFunctFile = sFunctFiles(ix);
    switch sFunctFile.Type
        case {'channel', 'data', 'image', 'noisecov', 'ndatacov', 'matrix', 'datalist', 'matrixlist'}
            sFunctFile = replaceStruct(sFunctFile, 'FileName', oldPath, newPath);

        case 'headmodel'
            oldFile = sFunctFile.FileName;
            sFunctFile = replaceStruct(sFunctFile, 'FileName', oldPath, newPath);
            % Update file
            if isMove
                fileFull = bst_fullfile(ProtocolInfo.STUDIES, sFunctFile.FileName);
            else
                fileFull = bst_fullfile(ProtocolInfo.STUDIES, oldFile);
            end
            if file_exist(fileFull)
                fileMat = load(fileFull);
                [fileMat, isModified] = replaceStruct(fileMat, 'SurfaceFile', oldSubj, newSubj);
                if isModified
                    bst_save(fileFull, fileMat, 'v7');
                end
            end

        case 'result'
            oldFile = sFunctFile.FileName;
            sFunctFile = replaceStruct(sFunctFile, 'FileName', oldPath, newPath);
            sFunctFile = replaceStruct(sFunctFile, 'ExtraStr1', oldPath, newPath); % DataFile
            % Regular files
            if ~sFunctFile.ExtraNum %isLink
                % Update file
                if isMove
                    fileFull = bst_fullfile(ProtocolInfo.STUDIES, sFunctFile.FileName);
                else
                    fileFull = bst_fullfile(ProtocolInfo.STUDIES, oldFile);
                end
                if file_exist(fileFull)
                    fileMat = load(fileFull);
                    [fileMat, isModified1] = replaceStruct(fileMat, 'DataFile',      oldPath, newPath);
                    [fileMat, isModified2] = replaceStruct(fileMat, 'HeadModelFile', oldPath, newPath);
                    [fileMat, isModified3] = replaceStruct(fileMat, 'SurfaceFile',   oldSubj, newSubj);
                    if isModified1 || isModified2 || isModified3
                        bst_save(fileFull, fileMat, 'v6');
                    end
                end
            end

        case 'stat'
            oldFile = sFunctFile.FileName;
            sFunctFile = replaceStruct(sFunctFile, 'FileName', oldPath, newPath);
            % Update file
            if isMove
                fileFull = bst_fullfile(ProtocolInfo.STUDIES, sFunctFile.FileName);
            else
                fileFull = bst_fullfile(ProtocolInfo.STUDIES, oldFile);
            end
            if file_exist(fileFull)
                fileMat = load(fileFull);
                [fileMat, isModified] = replaceStruct(fileMat, 'SurfaceFile', oldSubj, newSubj);
                if isModified
                    bst_save(fileFull, fileMat, 'v6');
                end
            end

        case 'dipoles'
            oldFile = sFunctFile.FileName;
            sFunctFile = replaceStruct(sFunctFile, 'FileName', oldPath, newPath);
            sFunctFile = replaceStruct(sFunctFile, 'ExtraStr1', oldPath, newPath); % DataFile
            % Update file
            if isMove
                fileFull = bst_fullfile(ProtocolInfo.STUDIES, sFunctFile.FileName);
            else
                fileFull = bst_fullfile(ProtocolInfo.STUDIES, oldFile);
            end
            if file_exist(fileFull)
                fileMat = load(fileFull);
                [fileMat, isModified1] = replaceStruct(fileMat, 'DataFile', oldPath, newPath);
                [fileMat, isModified2] = replaceStruct(fileMat, 'SurfaceFile', oldPath, newPath);
                if isModified1 || isModified2
                    bst_save(fileFull, fileMat, 'v7');
                end
            end

        case 'timefreq'
            oldFile = sFunctFile.FileName;
            sFunctFile = replaceStruct(sFunctFile, 'FileName', oldPath, newPath);
            sFunctFile = replaceStruct(sFunctFile, 'ExtraStr1', oldPath, newPath); % DataFile
            % Update file
            if isMove
                fileFull = bst_fullfile(ProtocolInfo.STUDIES, sFunctFile.FileName);
            else
                fileFull = bst_fullfile(ProtocolInfo.STUDIES, oldFile);
            end
            if file_exist(fileFull)
                fileMat = load(fileFull);
                [fileMat, isModified1] = replaceStruct(fileMat, 'DataFile', oldPath, newPath);
                [fileMat, isModified2] = replaceStruct(fileMat, 'SurfaceFile', oldPath, newPath);
                if isModified1 || isModified2
                    bst_save(fileFull, fileMat, 'v6');
                end
            end
    end
    % Update functional file in database
    db_set(sqlConn, 'FunctionalFile', sFunctFile, sFunctFile.Id);
end
sql_close(sqlConn);

% Close progress bar
bst_progress('stop');
% Not moving, not reloading
if isMove
    % Update tree display
    panel_protocols('UpdateTree');
end

end



%% ===== HELPER FUNCTIONS =====
function [s, isModified] = replaceStruct(s, field, oldPath, newPath)
    isModified = 0;
    if isempty(s) || ~isfield(s, field) || isempty(s.(field))
        return
    end
    % Get new and old subject name
    oldSubj = bst_fileparts(oldPath);
    newSubj = bst_fileparts(newPath);
    % Link: two filenames to modify
    if (length(s.(field)) > 4) && strcmpi(s.(field)(1:4), 'link')
        % Split the link
        splitLink = str_split(s.(field), '|');
        % Replace two strings
        for i = 2:3
            % Get file path
            [fPath,fBase,fExt] = bst_fileparts(splitLink{i});
            % Replace "oldPath" with "newPath"
            if ~isempty(strfind(file_win2unix(fPath), file_win2unix(oldPath)))
                fPath = strrep(file_win2unix(fPath), file_win2unix(oldPath), file_win2unix(newPath));
            % If the subject was renamed: change the subject directly (in the case of link files to @default_study)
            elseif ~strcmpi(oldSubj, newSubj)
                fPath = strrep(file_win2unix(fPath), [file_win2unix(oldSubj) '/'], [file_win2unix(newSubj) '/']);
            end
            % Update file path
            splitLink{i} = bst_fullfile(fPath, [fBase, fExt]);
        end
        % Rebuild full link
        s.(field) = ['link|' file_win2unix(splitLink{2}) '|' file_win2unix(splitLink{3})];
    % Regular filename
    else
        % Get file path
        [fPath,fBase,fExt] = bst_fileparts(s.(field));
        % Replace "oldPath" with "newPath"
        if ~isempty(strfind(file_win2unix(fPath), file_win2unix(oldPath)))
            fPath = strrep(file_win2unix(fPath), file_win2unix(oldPath), file_win2unix(newPath));
        % If the subject was renamed: change the subject directly (in the case of link files to @default_study)
        elseif ~strcmpi(oldSubj, newSubj)
            fPath = strrep([file_win2unix(fPath) '/'], [file_win2unix(oldSubj) '/'], [file_win2unix(newSubj) '/']);
            fPath = fPath(1:end-1);
        end
        % Update file path
        s.(field) = bst_fullfile(fPath, [fBase, fExt]);
        s.(field) = file_win2unix(s.(field));
    end
    isModified = 1;
end
