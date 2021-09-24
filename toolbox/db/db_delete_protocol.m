function isRemoved = db_delete_protocol(isUserConfirm, isRemoveFiles)
% DB_DELETE_PROTOCOL: Remove current protocol from database.
%
% USAGE:  db_delete_protocol(isUserConfirm, isRemoveFiles)  : Remove protocol #iProtocol from protocols list
%
% INPUT:
%     - isUserConfirm : If 0, do not ask user confirmation (default=1)
%     - isRemoveFiles : If 1, delete all the files in this protocol from the hard drive
%                       If 0, keep the files on the hard drive
%                       If empty or not specified: ask user

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
% Authors: Francois Tadel, 2008-2017

global GlobalData;


%% ===== PARSE INPUTS =====
% Options
if (nargin < 2)
    error('Invalid call to db_delete_protocol().');
end
% Get Protocols list structures (Infos, Subjects, Studies)
sProtocolsListInfo     = GlobalData.DataBase.ProtocolInfo;
sProtocolsListSubjects = GlobalData.DataBase.ProtocolSubjects;
sProtocolsListStudies  = GlobalData.DataBase.ProtocolStudies;
iProtocol              = GlobalData.DataBase.iProtocol;
if isempty(sProtocolsListInfo) || isempty(iProtocol)
    disp('BST> No protocol selected, nothing to delete.');
    return;
end


%% ===== ASK USER CONFIRMATION =====
if isUserConfirm
    % Warning string
    if ~isRemoveFiles
        strWarn = '(Subjects and datasets directories will not be deleted)';
    else
        strWarn = ['<BR><FONT color="#CC0000"><U>WARNING</U>: All the files will be permanently deleted from your hard drive.<BR>' ...
                   bst_fileparts(sProtocolsListInfo(iProtocol).STUDIES) '</FONT>'];
    end
    % Display dialog box
    isConfirmed = java_dialog('confirm', ['<HTML>Remove protocol ''' sProtocolsListInfo(iProtocol).Comment ''' from Brainstorm database ? <BR>' ...
                                          strWarn '<BR><BR>'], sprintf('Remove protocol #%d', iProtocol));
    if ~isConfirmed
        isRemoved = 0;
        return
    end
end

%% ===== REMOVE FILES =====
if isRemoveFiles
    % Remove all the contents of STUDIES and SUBJECTS folders
    file_delete( {sProtocolsListInfo(iProtocol).STUDIES, sProtocolsListInfo(iProtocol).SUBJECTS}, 1, 2);
    % If the parent folder (protocol folder) is empty: remove it
    ProtocolDir = bst_fileparts(sProtocolsListInfo(iProtocol).STUDIES);
    listFiles = dir(fullfile(ProtocolDir, '*'));
    listFiles = setdiff({listFiles.name}, {'..','.'});
    if isempty(listFiles)
        rmdir(ProtocolDir);
    else
        warning(['Protocol folder is not empty, cannot be deleted:' ProtocolDir]);
    end
end
    
%% ===== REMOVE PROTOCOL =====
sProtocolsListInfo(iProtocol)     = [];
sProtocolsListSubjects(iProtocol) = [];
sProtocolsListStudies(iProtocol)  = [];
% Update database
GlobalData.DataBase.ProtocolInfo      = sProtocolsListInfo;
GlobalData.DataBase.ProtocolSubjects  = sProtocolsListSubjects;
GlobalData.DataBase.ProtocolStudies   = sProtocolsListStudies;
GlobalData.DataBase.isProtocolLoaded(iProtocol)   = [];
GlobalData.DataBase.isProtocolModified(iProtocol) = [];
% Update protocols ComboBox
gui_brainstorm('UpdateProtocolsList');

% Get new protocol to select
if isempty(sProtocolsListInfo)
    iProtocol = 0;
elseif (iProtocol == 1)
    iProtocol = 1;
else
    iProtocol = iProtocol - 1;
end
% Select current protocol in combo list
gui_brainstorm('SetCurrentProtocol', iProtocol);

% Save database
% db_save();
isRemoved = 1;



