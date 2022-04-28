function isError = db_reload_database(iProtocolsList, isFix)
% DB_RELOAD_DATABASE: Reload one or all the protocols of the Brainstorm database.
%
% USAGE:  db_reload_database(iProtocol, isFix);  % If isFix = 1: check for errors in the protocol
%         db_reload_database(iProtocol)          % Reload one protocol, check for errors
%         db_reload_database('current');         % Reload current protocol, check for errors
%         db_reload_database();                  % Reload entire database, check for errors

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
% Authors: Francois Tadel, 2008-2013

global GlobalData;

% Fix database first ?
if (nargin < 2) || isempty(isFix)
    isFix = 1;
end
% Get protocols list
if (nargin < 1) || isempty(iProtocolsList)
    iProtocolsList = 1:length(GlobalData.DataBase.ProtocolInfo);
elseif ischar(iProtocolsList) && strcmpi(iProtocolsList, 'current')
    iProtocolsList = GlobalData.DataBase.iProtocol;
end
isError = zeros(1, length(iProtocolsList));
% Save current protocol
prevProtocol = GlobalData.DataBase.iProtocol;

% Progress bar
isProgressBar = ~bst_progress('isVisible');
if isProgressBar
    bst_progress('start', 'Reload database', 'Reloading database...', 0, 200 * length(iProtocolsList));
end
% For each protocol
for i = 1:length(iProtocolsList)
    bst_progress('set', 200 * (i - 1));
    % Change current protocol
    bst_set('iProtocol', iProtocolsList(i));
    ProtocolInfo = GlobalData.DataBase.ProtocolInfo(iProtocolsList(i));
    % Skipping the protocols that cannnot be mounted
    if ~file_exist(ProtocolInfo.STUDIES) || ~file_exist(ProtocolInfo.SUBJECTS)
        disp(['BST> Error: Protocol "' ProtocolInfo.Comment '" is not accessible.']);
        isError(i) = 1;
        continue;
    end
    % Fix database errors first
    if isFix
        pos = bst_progress('get');
        isError(i) = db_fix_protocol();
        bst_progress('set', pos);
        % If some errors were found: protocol was already reloaded => exit
        if isError(i)
            continue
        end
    end
    % Reload protocol : subjects
    bst_progress('text', ['"' ProtocolInfo.Comment '": Reloading subjects...']);
    db_load_subjects(0, isFix);
    % Reload protocol : studies
    bst_progress('text', ['"' ProtocolInfo.Comment '": Reloading datasets...']);
    db_load_studies(0, isFix);
    % Update links
    bst_progress('text', ['"' ProtocolInfo.Comment '": Updating links...']);
    db_links();
end
% Set protocol as loaded
bst_set('isProtocolLoaded', 1);
% Save database
db_save();
% Set the protocol to first protocol (if it exists)
if ~isempty(prevProtocol)
    gui_brainstorm('SetCurrentProtocol', prevProtocol);
end
% Stop progress bar
if isProgressBar
    bst_progress('stop');
end
% Refresh tree
panel_protocols('UpdateTree');


