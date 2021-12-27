function out_fwrite_spm(sFile, SamplesBounds, iChannels, F)
% OUT_FWRITE_SPM: Write a block of data in SPM binary file (.dat).
%
% USAGE:  out_fwrite_spm(sFile, SamplesBounds=[All], iChannels=[All], F)
%
% INPUTS:
%     - sFile         : Structure for importing files in Brainstorm. Created by in_fopen()
%     - SamplesBounds : [smpStart smpStop], First and last sample to read
%                       Set to [] to specify all the time definition
%     - iChannels     : Indices of the channels to write
%                       Set to [] to specify all the channels
%     - F             : Block of data to write to the file [iChannels x SamplesBounds]

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
% Authors: Francois Tadel, 2017


%% ===== PARSE INPUTS =====
if isempty(iChannels)
    iChannels = 1:size(F,1);
end
if isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

% Convert samples to indices in the file
SamplesBounds = SamplesBounds - round(sFile.prop.times(1) .* sFile.prop.sfreq);
iTimes = (SamplesBounds(1):SamplesBounds(2)) + 1;

% Write data
sFile.header.file_array(iChannels, iTimes) = F;



