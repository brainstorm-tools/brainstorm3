function isLoaded = db_load_protocol(iProtocols)
% DB_LOAD_PROTOCOL: Load in memory a protocol that hasn't been loaded yet

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
% Authors: Francois Tadel, 2013

global GlobalData;

% Parse inputs
if (nargin < 1) || isempty(iProtocols)
    iProtocols = 1:length(GlobalData.DataBase.ProtocolInfo);
end
% Initialize returned variable
isLoaded = 0;

% Load all the protocols sequentially
for i = 1:length(iProtocols)
    % ===== CHECK FOLDERS =====
    isReload = 0;
    % Protocol matrix filename
    ProtocolFile = bst_fullfile(GlobalData.DataBase.ProtocolInfo(iProtocols(i)).STUDIES, 'protocol.mat');
    % Check file
    if ~file_exist(ProtocolFile)
        isReload = 1;
    elseif ~file_attrib(ProtocolFile, 'r')
        disp(['BST> Error: Insufficient rights to read the protocol file "' ProtocolFile '".']);
        isReload = 1;
    end

%     % Check if Brainstorm needs to be updated in order to load this
%     % protocol (new version of the database)
%     SqlFile = bst_fullfile(GlobalData.DataBase.ProtocolInfo(iProtocols(i)).STUDIES, 'protocol.db');
%     if file_exist(SqlFile)
%         res = java_dialog('question', ['This protocol seems to have been ' ...
%             'created with a newer version of the software.' 10 ...
%             'We strongly recommend you update Brainstorm before you continue.' ...
%             10 'Do you want to update the software now?'], 'Load protocol');
%         if strcmpi(res, 'yes')
%             bst_update();
%         else
%             isReload = 1;
%         end
%     end

    % ===== LOAD PROTOCOL.MAT =====
    if ~isReload
        try
            ProtocolMat = load(ProtocolFile);
        catch
            disp(['BST> Error: Cannot read protocol file "' ProtocolFile '".']);
            isReload = 1;
        end
    end
    
%     % ===== CHECK LAST USER =====
%     % If the last user is different from the current user (testing user home directories)
%     if ~isReload && isfield(ProtocolMat, 'LastAccessUserDir') && ~isempty(ProtocolMat.LastAccessUserDir) && ~strcmpi(ProtocolMat.LastAccessUserDir, bst_get('UserDir'))
%         if bst_get('isGUI')
%             isReload = java_dialog('confirm', ['Warning: Another user accessed the protocol "' ProtocolMat.ProtocolInfo.Comment '" recently.' 10 ...
%                                     'User folder: "' ProtocolMat.LastAccessUserDir '"' 10 10 ...
%                                     'You may have to reload it in order to see the latest modifications.' 10 ...
%                                     'Reload protocol now?']);
%         else
%             isReload = 1;
%         end
%     end

    % ===== CHECK DATABASE VERSION =====
    if ~isReload && (~isfield(ProtocolMat, 'DbVersion') || ~isfield(GlobalData.DataBase, 'DbVersion') || (GlobalData.DataBase.DbVersion ~= ProtocolMat.DbVersion))
        isReload = 1;
    end

    bst_splash('hide');
    % ===== SAVE =====
    % Reload protocol
    if isReload
        db_reload_database(iProtocols(i));
        % TODO: CHECK BROKEN LINKS TO RAW DATA
        %      - Get all raw data files (data_0raw....)
        %      - Check which ones are links to external data:
        %         (Not .mat, and dir is diff from dir for the raw data file)
        %      - Make a list of broken links (absolute path to file exist)
        %      - IF brokenlist NOT empty
        %        - Try to fix first path as in in_bst_data L131
        %          (Maybe expose that code part, so it can return the fixed_path)
        %        - IF path was fixed
        %           - Remove it from brokenlist
        %           - FOR broken IN brokenlist
        %             - Apply same fix to other broken links, when suitable
        %             - IF path was fixed
        %                - Remove it from brokenlist
        %      - WHILE brokenlist NOT empty AND numel(brokenlist) < SomeReasonableNumberOfLinksToFix
        %        - Ask user if they want to fix broken links NOW
        %          - Ask User to select the new path for first broken link
        %          - IF path was fixed
        %             - Apply same fix to other broken links, remove them from brokenlist

    % Protocol loaded successfully: Copy protoco.mat fields in memory
    else
        GlobalData.DataBase.ProtocolInfo(iProtocols(i)).iStudy            = ProtocolMat.ProtocolInfo.iStudy;
        GlobalData.DataBase.ProtocolInfo(iProtocols(i)).UseDefaultAnat    = ProtocolMat.ProtocolInfo.UseDefaultAnat;
        GlobalData.DataBase.ProtocolInfo(iProtocols(i)).UseDefaultChannel = ProtocolMat.ProtocolInfo.UseDefaultChannel;
        GlobalData.DataBase.ProtocolSubjects(iProtocols(i))   = ProtocolMat.ProtocolSubjects;
        GlobalData.DataBase.ProtocolStudies(iProtocols(i))    = ProtocolMat.ProtocolStudies;
        GlobalData.DataBase.isProtocolLoaded(iProtocols(i))   = 1;
        GlobalData.DataBase.isProtocolModified(iProtocols(i)) = 0;
        % Refresh tree
        panel_protocols('UpdateTree');
    end
end



