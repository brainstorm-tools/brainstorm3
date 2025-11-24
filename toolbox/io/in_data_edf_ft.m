function [DataMat, ChannelMat] = in_data_edf_ft(DataFile)
% in_data_edf_ft: Read entire EDF/EDF+ file using FieldTrip import function
%                 data is upsampled to the highest sampling rate
%
% USAGE: [DataMat, ChannelMat] = in_data_edf_ft(DataFile)

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
% Authors: Edouard Delaire 2024
%          Raymundo Cassani 2024

%% ===== INSTALL PLUGIN FIELDTRIP =====
if ~exist('edf2fieldtrip', 'file')
    [isInstalled, errMsg] = bst_plugin('Install', 'fieldtrip');
    if ~isInstalled
        error(errMsg);
    end
end

% Temporary FieldTrip file
[~, filename] = bst_fileparts(DataFile);
tmpfilename = bst_fullfile(bst_get('BrainstormTmpDir', 0, 'fieldtrip'), [filename '.mat']);
% Read EDF using FieldTrip
data = edf2fieldtrip(DataFile);
% Save read data
save(tmpfilename, 'data');
% Import in Brainstorm
[DataMat, ChannelMat] = in_data_fieldtrip(tmpfilename);
