function [sFile, ChannelMat, DataMat]= in_data_edf_ft(DataFile)
% in_data_edf_ft: Read EDF recordings using FieldTrip import function
%
% USAGE: [sFile, ChannelMat, DataMat] = in_data_edf_ft(DataFile)

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

    sFile = '';
    [~, filename, ~] = fileparts(DataFile);

    % Load using fieldtrip 
    data = edf2fieldtrip(DataFile);
    
    % save Fieldtrip output
    save(fullfile(bst_get('BrainstormTmpDir'), [filename '.mat']), 'data');

    % Import in Brainstorm 
    [DataMat, ChannelMat] = in_data_fieldtrip(fullfile(bst_get('BrainstormTmpDir'), [filename '.mat']));
end