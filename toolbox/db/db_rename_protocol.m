function isRenamed = db_rename_protocol(newName)
% DB_RENAME_PROTOCOL: Rename current protocol

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
% Authors: Francois Tadel, 2019

global GlobalData;
isRenamed = 0;

% Get protocol to rename
iProtocol = bst_get('iProtocol');
ProtocolInfo = bst_get('ProtocolInfo');
if isempty(iProtocol) || (iProtocol < 1)
    bst_error('No protocol selected.', 'Rename protocol', 0);
    return;
end

% Get new protocol name
if (nargin < 1) || isempty(newName)
    newName = java_dialog('input', 'Enter new protocol name:', 'Rename protocol', [], ProtocolInfo.Comment);
end
if isempty(newName) || isequal(newName, ProtocolInfo.Comment)
    return;
elseif ~isequal(newName, file_standardize(newName))
    bst_error('Invalid protocol name.', 'Rename protocol', 0);
    return;
elseif any(strcmpi(newName, {GlobalData.DataBase.ProtocolInfo.Comment}))
    bst_error(['A protocol named "' newName '" already exists in your database.'], 'Rename protocol', 0);
    return;
end

% New protocol folder
[oldPathAnat, anatName] = bst_fileparts(ProtocolInfo.SUBJECTS);
[oldPathData, dataName] = bst_fileparts(ProtocolInfo.STUDIES);
[basePath, oldName] = bst_fileparts(oldPathData);
newPath = bst_fullfile(basePath, newName);

% Check that anat and data folders are in the same folder
if ~isequal(oldPathData, oldPathAnat)
    bst_error('Only protocols with anat and data folders in the same folder can be renamed.', 'Rename protocol', 0);
    return;
end
% Check if folder already exists
if file_exist(newPath)
    bst_error(['This folder already exists:' 10 newPath], 'Rename protocol', 0);
    return;
end

% Rename protocol folder
isMoved = file_move(oldPathData, newPath);
if ~isMoved
    bst_error(['Could not rename protocol folder.' 10 'Source: ' oldPathData 10 'Destination: ' newPath], 'Rename protocol', 0);
    return;
end

% Change protocol folders
ProtocolInfo.Comment = newName;
ProtocolInfo.SUBJECTS = bst_fullfile(newPath, anatName);
ProtocolInfo.STUDIES = bst_fullfile(newPath, dataName);
db_edit_protocol('edit', ProtocolInfo, iProtocol);

isRenamed = 1;

% Refresh protocols list
gui_brainstorm('UpdateProtocolsList');

        

