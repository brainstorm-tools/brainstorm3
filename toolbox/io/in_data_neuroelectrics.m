function [DataMat, ChannelMat] = in_data_neuroelectrics(DataFile)
% IN_DATA_MUSE_CSV: Imports a Neuroelectrics .easy/.info or .nedf file, using EEGLAB plugin.
%
% File formats specification:
% https://www.neuroelectrics.com/wiki/index.php/Files_%26_Formats
%
% EEGLAB plugin:
% https://sccn.ucsd.edu/eeglab/plugin_uploader/plugin_list_all.php
%    
% USAGE: [DataMat, ChannelMat] = in_data_neuroelectrics(DataFile, sfreq=[ask], isInteractive=0);

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
% Authors: Francois Tadel, 2022


% ===== INSTALL EEGLAB PLUGIN =====
if ~exist('pop_nedf', 'file')
    [isInstalled, errMsg] = bst_plugin('Install', 'neuroelectrics');
    if ~isInstalled
        error(errMsg);
    end
end


% ===== READ FILE =====
bst_progress('text', 'Reading file (EEGLAB plugin)...');
% Get file extension
[fPath, fBase, fExt] = bst_fileparts(DataFile);
switch lower(fExt)
    % NEDF: Binary
    case '.nedf'   
        % Change the current directory to the plugin path, because the EEGLAB plugin adds stuff to the Matlab path in its own way...
        curDir = pwd;
        cd(bst_fileparts(which('pop_easy')));
        % Read file: pop_nedf(file,acc,locs,channels_selected)
        EEG = pop_nedf(DataFile, 1, 0, []);
        % Restore Matlab directory
        cd(curDir);
    % EASY: Text file + .info header file
    case '.easy'   
        % Read file: pop_easy(file,acc,locs,channels_selected)
        EEG = pop_easy(DataFile, 1, 0, []);
end


% ===== CONVERT EEGLAB TO BRAINSTORM =====
bst_progress('text', 'Converting data structures...');
% Convert EEGLAB structure to continuous Brainstorm structure
EEG.filename = DataFile;
EEG.xmin = 0;
[sFile, ChannelMat] = in_fopen_eeglab(EEG);

% Change the type of accelerometers
for iChan = 1:length(ChannelMat.Channel)
    if ismember(ChannelMat.Channel(iChan).Name, {'x','y','z'})
        ChannelMat.Channel(iChan).Type = 'Accelerometer';
    end
end
ChannelMat.Comment = 'Neuroelectrics channels';

% Read data
ImportOptions = db_template('ImportOptions');
ImportOptions.ImportMode = 'Time';
ImportOptions.DisplayMessages = 0;
[F, Time] = in_fread(sFile, ChannelMat, 1, [], [], ImportOptions);

% Convert to imported Brainstorm data structure
DataMat = db_template('DataMat');
DataMat.F           = F;
DataMat.Time        = Time;
DataMat.Comment     = fBase;
DataMat.ChannelFlag = sFile.channelflag;
DataMat.nAvg        = 1;
DataMat.Device      = 'Neuroelectrics';
DataMat.Events      = sFile.events;

