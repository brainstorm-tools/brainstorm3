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
    [sStudies, iStudies] = bst_get('StudyWithCondition', oldPath);
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
[sStudy, iStudy] = bst_get('StudyWithCondition', oldPath);
% Update study
if isUpdateStudyPath
    sStudy = replaceStruct(sStudy, 'FileName',        oldPath, newPath);
    sStudy = replaceStruct(sStudy, 'Name',            oldPath, newPath);
    sStudy = replaceStruct(sStudy, 'BrainStormSubject', oldSubj, newSubj);
    sStudy.Condition = {newCond};
end

% === CHANNEL ===
for i = 1:length(sStudy.Channel)
    sStudy.Channel(i) = replaceStruct(sStudy.Channel(i), 'FileName', oldPath, newPath);
end
% === DATA ===
for i = 1:length(sStudy.Data)
    sStudy.Data(i) = replaceStruct(sStudy.Data(i), 'FileName', oldPath, newPath);
end
% === HEADMODEL ===
for i = 1:length(sStudy.HeadModel)
    oldFile = sStudy.HeadModel(i).FileName;
    sStudy.HeadModel(i) = replaceStruct(sStudy.HeadModel(i), 'FileName', oldPath, newPath);
    % Update file
    if isMove
        fileFull = bst_fullfile(ProtocolInfo.STUDIES, sStudy.HeadModel(i).FileName);
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
end
% === RESULT ===
for i = 1:length(sStudy.Result)
    oldFile = sStudy.Result(i).FileName;
    sStudy.Result(i) = replaceStruct(sStudy.Result(i), 'FileName', oldPath, newPath);
    sStudy.Result(i) = replaceStruct(sStudy.Result(i), 'DataFile', oldPath, newPath);
    % Regular files
    if ~sStudy.Result(i).isLink
        % Update file
        if isMove
            fileFull = bst_fullfile(ProtocolInfo.STUDIES, sStudy.Result(i).FileName);
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
end
% === STAT ===
for i = 1:length(sStudy.Stat)
    oldFile = sStudy.Stat(i).FileName;
    sStudy.Stat(i) = replaceStruct(sStudy.Stat(i), 'FileName', oldPath, newPath);
    % Update file
    if isMove
        fileFull = bst_fullfile(ProtocolInfo.STUDIES, sStudy.Stat(i).FileName);
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
end
% === IMAGE ===
for i = 1:length(sStudy.Image)
    sStudy.Image(i) = replaceStruct(sStudy.Image(i), 'FileName', oldPath, newPath);
end
% === NOISECOV ===
for i = 1:length(sStudy.NoiseCov)
    sStudy.NoiseCov(i) = replaceStruct(sStudy.NoiseCov(i), 'FileName', oldPath, newPath);
end
% === DIPOLES ===
for i = 1:length(sStudy.Dipoles)
    oldFile = sStudy.Dipoles(i).FileName;
    sStudy.Dipoles(i) = replaceStruct(sStudy.Dipoles(i), 'FileName', oldPath, newPath);
    sStudy.Dipoles(i) = replaceStruct(sStudy.Dipoles(i), 'DataFile', oldPath, newPath);
    % Update file
    if isMove
        fileFull = bst_fullfile(ProtocolInfo.STUDIES, sStudy.Dipoles(i).FileName);
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
end
% === TIMEFREQ ===
for i = 1:length(sStudy.Timefreq)
    oldFile = sStudy.Timefreq(i).FileName;
    sStudy.Timefreq(i) = replaceStruct(sStudy.Timefreq(i), 'FileName', oldPath, newPath);
    sStudy.Timefreq(i) = replaceStruct(sStudy.Timefreq(i), 'DataFile', oldPath, newPath);
    % Update file
    if isMove
        fileFull = bst_fullfile(ProtocolInfo.STUDIES, sStudy.Timefreq(i).FileName);
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
% === MATRIX ===
for i = 1:length(sStudy.Matrix)
    sStudy.Matrix(i) = replaceStruct(sStudy.Matrix(i), 'FileName', oldPath, newPath);
end


%% ===== UPDATE DATABASE =====
% Update condition in database
bst_set('Study', iStudy, sStudy);
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
