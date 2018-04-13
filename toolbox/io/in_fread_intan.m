function F = in_fread_intan(sFile, SamplesBounds, iChannels)
% IN_FREAD_INTAN Read a block of recordings from a Intan files
%
% USAGE:  F = in_fread_blackrock(sFile, SamplesBounds=[], iChannels=[])

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Konstantinos Nasiotis 2018


% Parse inputs
if (nargin < 3) || isempty(iChannels)
    iChannels = 1:sFile.header.ChannelCount;
end
if (nargin < 2) || isempty(SamplesBounds)
    SamplesBounds = sFile.prop.samples;
end


% Read the corresponding recordings
F = zeros(length(iChannels), diff(SamplesBounds)+1);

for iChannel = 1:length(iChannels)
    
    fid = fopen(fullfile(sFile.filename,sFile.header.chan_files(iChannel).name), 'r');
    fseek(fid, SamplesBounds(1), 'bof');
    data_channel = fread(fid, SamplesBounds(2) - SamplesBounds(1) +1, 'int16');
    F(iChannel,:) = data_channel*0.195; % Convert to microvolts
    fclose(fid);
end
