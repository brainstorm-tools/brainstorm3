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

%TODO: Delete this function?
disp('DB_SAVE: Disabled!');
return

global GlobalData;
% Parse inputs
if (nargin < 1) || isempty(isIgnoreTime)
    isIgnoreTime = 0;
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
BstMat.BrainStormDbDir       = GlobalData.DataBase.BrainstormDbDir;
BstMat.CloneLock             = GlobalData.Program.CloneLock;
BstMat.Colormaps             = GlobalData.Colormaps;
BstMat.ChannelMontages       = GlobalData.ChannelMontages;
BstMat.DataViewer.DefaultFactor = [];
BstMat.Pipelines   = GlobalData.Processes.Pipelines;
BstMat.Preferences = GlobalData.Preferences;
BstMat.Searches    = GlobalData.DataBase.Searches.All;
BstMat.Preferences.TopoLayoutOptions.TimeWindow = [];


% ===== SAVE BRAINSTORM.MAT =====
%disp('BST> Saving user preferences...');
% Get brainstorm database filename
BrainstormDbFile = bst_get('BrainstormDbFile');
% Save file
bst_save(BrainstormDbFile, BstMat, 'v7');
% Close progress bar
if ~isProgress
    bst_progress('stop');
end

