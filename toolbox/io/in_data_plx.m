function [DataMat, ChannelMat] = in_data_plx( DataFile )
% IN_DATA_PLX: Read a PLX file.
%
% INPUT:
%    - DataFile : Full path to a recordings file (called 'data' files in Brainstorm)
% OUTPUT: 
%    - DataMat : Brainstorm standard recordings ('data') structure

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
% Authors: Konstantinos Nasiotis 2022


%% ===== GET OPTIONS =====
% Get file info
[sFile, ChannelMat] = in_fopen_plexon(DataFile); % This call gets all of the file info (channels, events etc.)

%% Now Read entire recording and assign to DataMat
% Initialize returned structures
DataMat = db_template('DataMat');
DataMat.Comment  = 'EEG/PLX';
DataMat.DataType = 'recordings';
DataMat.Device   = 'Plexon';

isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'Plexon importer', 'Reading entire recording');
end
% Read entire file
DataMat.F = in_fread_plexon(sFile, [], [], []);

% Add the events
DataMat.Events = sFile.events;

% Build time vector
DataMat.Time = sFile.prop.times(1):1/sFile.prop.sfreq:sFile.prop.times(2);

% ChannelFlag
DataMat.ChannelFlag = ones(size(DataMat.F,1), 1);

% Replace NaN with 0
DataMat.F(isnan(DataMat.F)) = 0;

% Save number of trials averaged
DataMat.nAvg = 1;

% Build comment
[fPath, fBase, fExt] = bst_fileparts(DataFile);
DataMat.Comment = fBase;

isProgress = bst_progress('isVisible');
if isProgress
    bst_progress('stop');
end
end
