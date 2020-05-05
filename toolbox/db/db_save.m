function db_save(isIgnoreTime)
% DB_SAVE: Save Brainstorm database.

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
% Authors: Francois Tadel, 2008-2016

global GlobalData;
% Parse inputs
if (nargin < 1) || isempty(isIgnoreTime)
    isIgnoreTime = 0;
end

% ===== CHECK LAST SAVE =====
% Calculate number of seconds since the last save
elapsed = toc(GlobalData.DataBase.LastSavedTime);
% If we are not required to save the database: return
if ~isIgnoreTime && (elapsed < 10 * 60)
    % disp('BST> Saving ignored.');
    return;
end

% ===== PREPARE BRAINSTORM.MAT =====
% Open progress bar
isProgress = bst_progress('isVisible');
bst_progress('start', 'Database auto-save', 'Saving database...');
% Compatibilty with previous of Brainstorm  (Added 04-June-2013)
if ~isfield(GlobalData.DataBase, 'isProtocolLoaded') || isempty(GlobalData.DataBase.isProtocolLoaded)
    GlobalData.DataBase.isProtocolLoaded = ones(1, length(GlobalData.DataBase.ProtocolInfo));
end
% Brainstorm information stored in root appdata to a 'brainstorm.mat' matrix
BstMat.iProtocol             = GlobalData.DataBase.iProtocol;
BstMat.ProtocolsListInfo     = GlobalData.DataBase.ProtocolInfo;
BstMat.ProtocolsListSubjects = GlobalData.DataBase.ProtocolSubjects;
BstMat.ProtocolsListStudies  = GlobalData.DataBase.ProtocolStudies;
BstMat.isProtocolLoaded      = GlobalData.DataBase.isProtocolLoaded;
BstMat.BrainStormDbDir       = GlobalData.DataBase.BrainstormDbDir;
BstMat.DbVersion             = GlobalData.DataBase.DbVersion;
BstMat.CloneLock             = GlobalData.Program.CloneLock;
BstMat.Colormaps             = GlobalData.Colormaps;
BstMat.ChannelMontages       = GlobalData.ChannelMontages;
BstMat.DataViewer.DefaultFactor = [];
BstMat.Pipelines   = GlobalData.Processes.Pipelines;
BstMat.Preferences = GlobalData.Preferences;
BstMat.Searches    = GlobalData.DataBase.Searches.All;
BstMat.Preferences.TopoLayoutOptions.TimeWindow = [];

% ===== SAVING PROTOCOLS =====
% Save each protocol structure in its data folder
for iProtocol = 1:length(GlobalData.DataBase.ProtocolInfo)
    % Protocol is not loaded: skip
    if ~GlobalData.DataBase.isProtocolLoaded(iProtocol)
        continue;
    end
    % Protocol matrix filename
    ProtocolFile = bst_fullfile(GlobalData.DataBase.ProtocolInfo(iProtocol).STUDIES, 'protocol.mat');
    % If file cannot be saved (protocol read-only): skip
    if ~file_attrib(ProtocolFile, 'w')
        continue;
    end
    % Remove from the central database definition
    BstMat.ProtocolsListSubjects(iProtocol) = db_template('ProtocolSubjects');
    BstMat.ProtocolsListStudies(iProtocol)  = db_template('ProtocolStudies');
    BstMat.isProtocolLoaded(iProtocol)      = 0;
    % Protocol is not modified: skip
    if ~GlobalData.DataBase.isProtocolModified(iProtocol)
        continue;
    end
    % Create protocol matrix
    ProtocolMat.ProtocolInfo      = GlobalData.DataBase.ProtocolInfo(iProtocol);
    ProtocolMat.ProtocolSubjects  = GlobalData.DataBase.ProtocolSubjects(iProtocol);
    ProtocolMat.ProtocolStudies   = GlobalData.DataBase.ProtocolStudies(iProtocol);
    ProtocolMat.DbVersion         = GlobalData.DataBase.DbVersion;
    ProtocolMat.LastAccessDate    = datestr(now);
    ProtocolMat.LastAccessUserDir = bst_get('UserDir');
    % Remove useless fields
    ProtocolMat.ProtocolInfo = rmfield(ProtocolMat.ProtocolInfo, 'STUDIES');
    ProtocolMat.ProtocolInfo = rmfield(ProtocolMat.ProtocolInfo, 'SUBJECTS');
    % Display saving message
    disp(['BST> Saving protocol "' ProtocolMat.ProtocolInfo.Comment '"...']);

    % Save the protocol file
    try
        bst_save(ProtocolFile, ProtocolMat, 'v7');
    catch
        disp(['BST> Error: Cannot save file "' ProtocolFile '".']);
        continue;
    end
    % Unload all the protocols that are not currently used
    if (iProtocol ~= GlobalData.DataBase.iProtocol)
        GlobalData.DataBase.ProtocolSubjects(iProtocol) = db_template('ProtocolSubjects');
        GlobalData.DataBase.ProtocolStudies(iProtocol)  = db_template('ProtocolStudies');
        GlobalData.DataBase.isProtocolLoaded(iProtocol) = 0;
    end
end


% ===== SAVE BRAINSTORM.MAT =====
%disp('BST> Saving user preferences...');
% Get brainstorm database filename
BrainstormDbFile = bst_get('BrainstormDbFile');
% Save file
bst_save(BrainstormDbFile, BstMat, 'v7');
% Record current time
GlobalData.DataBase.LastSavedTime = tic();
% Close progress bar
if ~isProgress
    bst_progress('stop');
end

