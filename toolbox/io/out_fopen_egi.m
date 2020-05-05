function sFileOut = out_fopen_egi(OutputFile, sFileIn, ChannelMat)
% OUT_FOPEN_EGI: Saves the header of a new empty EGI RAW file.

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
% Authors: Francois Tadel, 2014-2019

% Get file comment
[fPath, fBase, fExt] = bst_fileparts(OutputFile);
c = clock();

% Create a new header structure
sFileOut = sFileIn;
sFileOut.filename  = OutputFile;
sFileOut.condition = '';
sFileOut.format    = 'EEG-EGI-RAW';
sFileOut.byteorder = 'b';
sFileOut.comment   = fBase;
header    = struct();
header.versionNumber = 4;  % FLOAT32
header.recordingTime.Year     = c(1);
header.recordingTime.Month    = c(2);
header.recordingTime.Day      = c(3);
header.recordingTime.Hour     = c(4);
header.recordingTime.Minute   = c(5);
header.recordingTime.Second   = c(6);
header.recordingTime.Millisec = 0;
header.samplingRate  = sFileIn.prop.sfreq;
header.numChans      = length(ChannelMat.Channel);
header.boardGain     = 1;
header.numConvBits   = 0;
header.ampRange      = 0;
header.byteformat    = 'real*4';
header.bytesize      = 4;
fileSamples = round(sFileIn.prop.times .* sFileIn.prop.sfreq);
header.numSamples    = fileSamples(2) - fileSamples(1) + 1;
header.numEvents     = length(sFileIn.events);
header.eventCodes    = {sFileIn.events.label};
header.epochs_tim0   = fileSamples(1);
% Copy some values from the original header if possible
if strcmpi(sFileIn.format, 'EEG-EGI-RAW') && ~isempty(sFileIn.header)
    header.recordingTime = sFileIn.header.recordingTime;
    header.boardGain     = sFileIn.header.boardGain;
    header.numConvBits   = sFileIn.header.numConvBits;
    header.ampRange      = sFileIn.header.ampRange;
end

% Open file
fid = fopen(OutputFile, 'w+', sFileOut.byteorder);
if (fid == -1)
    error('Could not open output file.');
end

% Write header
fwrite(fid, header.versionNumber, 'integer*4');
fwrite(fid, header.recordingTime.Year, 'integer*2');
fwrite(fid, header.recordingTime.Month, 'integer*2');
fwrite(fid, header.recordingTime.Day, 'integer*2');
fwrite(fid, header.recordingTime.Hour, 'integer*2');
fwrite(fid, header.recordingTime.Minute, 'integer*2');
fwrite(fid, header.recordingTime.Second, 'integer*2');
fwrite(fid, header.recordingTime.Millisec, 'integer*4');
fwrite(fid, header.samplingRate, 'integer*2');
fwrite(fid, header.numChans, 'integer*2');
fwrite(fid, header.boardGain, 'integer*2');
fwrite(fid, header.numConvBits, 'integer*2');
fwrite(fid, header.ampRange, 'integer*2');
fwrite(fid, header.numSamples, 'integer*4');
fwrite(fid, header.numEvents, 'integer*2');
% Write event names
for i = 1:header.numEvents
    header.eventCodes{i} = fwrite(fid, str_zeros(sFileIn.events(i).label, 4), 'char');
end

% Save beginning of the data block
header.datapos = ftell(fid);
% Close file
fclose(fid);
% Copy header to the sFile structure
sFileOut.header = header;

end



%% ===== HELPER FUNCTIONS =====
function sout = str_zeros(sin, N)
    sout = char(double(' ') * ones(1,N));
    if (length(sin) <= N)
        sout(1:length(sin)) = sin;
    else
        sout = sin(1:N);
    end
end





