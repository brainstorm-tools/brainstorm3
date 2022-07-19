function isLoaded = db_load_protocol(iProtocols)
% DB_LOAD_PROTOCOL: Load in memory a protocol that hasn't been loaded yet

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
    dbInfo = db_template('databaseinfo');
    ProtocolDB = bst_fullfile(GlobalData.DataBase.ProtocolInfo(iProtocols(i)).STUDIES, 'protocol.db');
    if ~file_exist(ProtocolDB)
        isReload = 1;
    elseif ~file_attrib(ProtocolDB, 'r')
        disp(['BST> Error: Insufficient rights to read the protocol database "' ProtocolDB '".']);
        isReload = 1;
    else
        dbInfo.Rdbms = 'sqlite';
        dbInfo.Location = ProtocolDB;
    end

    % ===== SAVE =====
    % Reload protocol
    if isReload
        db_reload_database(iProtocols(i));
    % Protocol loaded successfully: Copy protoco.mat fields in memory
    else
        % Load database info about protocol
        sqlConn = sql_connect(dbInfo);
        sProtocol = sql_query(sqlConn, 'SELECT', 'Protocol', [], {'UseDefaultAnat', 'UseDefaultChannel'});
        sql_close(sqlConn, dbInfo);
        %TODO: iStudy
        %GlobalData.DataBase.ProtocolInfo(iProtocols(i)).iStudy            = ProtocolMat.ProtocolInfo.iStudy;
        GlobalData.DataBase.ProtocolInfo(iProtocols(i)).UseDefaultAnat    = sProtocol.UseDefaultAnat;
        GlobalData.DataBase.ProtocolInfo(iProtocols(i)).UseDefaultChannel = sProtocol.UseDefaultChannel;
        GlobalData.DataBase.ProtocolInfo(iProtocols(i)).Database          = dbInfo;
        GlobalData.DataBase.isProtocolLoaded(iProtocols(i)) = 1;
        % Refresh tree
        panel_protocols('UpdateTree');
    end
end



