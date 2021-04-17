function db_rename_subject( oldName, newName, isRefresh )
% DB_RENAME_SUBJECT: Rename a subject in the Brainstorm database.
%
% USAGE:  db_rename_subject( oldPath, newPath, isRefresh )
%         db_rename_subject( oldPath, newPath )

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
% Authors: Francois Tadel, 2011

%% ===== INITIALIZATION =====
% Parse inputs
if (nargin < 3) || isempty(isRefresh)
    isRefresh = 1;
end
% Get protocol directories
ProtocolInfo = bst_get('ProtocolInfo');
% Get subject index
[sSubject, iSubject] = bst_get('Subject', oldName);
if isempty(iSubject)
    return;
end
% No modification
if strcmpi(oldName, newName)
    return;
end
% Progress bar
bst_progress('start', 'Rename subject', ['Rename: ' oldName ' => ' newName]);
% SUBJECTS: Check that old condition exists
if ~isdir(bst_fullfile(ProtocolInfo.SUBJECTS, oldName))
    bst_error(['Folder "anat/' oldName '" does not exists.'], 'Rename', 0);
    return;
end
% SUBJECTS: Check that new condition does not exist
if isdir(bst_fullfile(ProtocolInfo.SUBJECTS, newName))
    bst_error(['Folder "anat/' newName '" already exists.'], 'Rename', 0);
    return;
end
% STUDIES: Check that old condition exists
if ~isdir(bst_fullfile(ProtocolInfo.STUDIES, oldName))
    bst_error(['Folder "data/' oldName '" does not exists.'], 'Rename', 0);
    return;
end
% STUDIES: Check that new condition does not exist
if isdir(bst_fullfile(ProtocolInfo.STUDIES, newName))
    bst_error(['Folder "data/' newName '" already exists.'], 'Rename', 0);
    return;
end

%% ===== MOVE ANATOMY FOLDER =====
isOk = file_move(bst_fullfile(ProtocolInfo.SUBJECTS, oldName), bst_fullfile(ProtocolInfo.SUBJECTS, newName));
if ~isOk
    bst_error(['Could not rename anat/"' oldName '" to anat/"' newName '".'], 'Rename', 0);
    return;
end

%% ===== RENAME ALL THE CONDITIONS =====
dataDir = bst_fullfile(ProtocolInfo.STUDIES, oldName);
listDir = dir(dataDir);
for iDir = 1:length(listDir)
    % Skip non-study folders
    if ~listDir(iDir).isdir || (listDir(iDir).name(1) == '.') || isempty(dir(bst_fullfile(dataDir, listDir(iDir).name, 'brainstormstudy*.mat')))
        continue;
    end
    % Call the function to rename condition (DO NOT MOVE FILES)
    Condition = listDir(iDir).name;
    oldPath = bst_fullfile(oldName, Condition);
    newPath = bst_fullfile(newName, Condition);
    db_rename_condition(oldPath, newPath, 0);
end

%% ===== MOVE DATA FOLDER =====
isOk = file_move(bst_fullfile(ProtocolInfo.STUDIES, oldName), bst_fullfile(ProtocolInfo.STUDIES, newName));
if ~isOk
    bst_error(['Error: Could not rename data/"' oldName '" to data/"' newName '".'], 'Rename', 0);
    return;
end


%% ===== UPDATE DATABASE =====
% Update subject definition
[sSubject, iSubject] = bst_get('Subject', oldName, 1);
sSubject.Name = newName;
% Update subject filename
[fPath, fBase, fExt] = bst_fileparts(sSubject.FileName);
sSubject.FileName = bst_fullfile(newName, [fBase, fExt]);
% Update anatomy
for i = 1:length(sSubject.Anatomy)
    [fPath, fBase, fExt] = bst_fileparts(sSubject.Anatomy(i).FileName);
    sSubject.Anatomy(i).FileName = bst_fullfile(newName, [fBase, fExt]);
end
% Update surfaces
for i = 1:length(sSubject.Surface)
    [fPath, fBase, fExt] = bst_fileparts(sSubject.Surface(i).FileName);
    sSubject.Surface(i).FileName = bst_fullfile(newName, [fBase, fExt]);
end
% Save new subject definition
bst_set('Subject', iSubject, sSubject);
% Close progress bar
bst_progress('stop');
% Update tree display
if isRefresh
    panel_protocols('UpdateTree');
end


