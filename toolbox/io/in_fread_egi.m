function F = in_fread_egi(sFile, sfid, iEpoch, SamplesBounds)
% IN_FREAD_EGI:  Read a block of recordings from a EGI .raw file
%
% USAGE:  F = in_fread_egi(sFile, sfid, iEpoch, SamplesBounds) : Read all channels
%         F = in_fread_egi(sFile, sfid, iEpoch)                : Read all channels, all the times
%         F = in_fread_egi(sFile, sfid)                        : Read all channels, all the times, for first epoch

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
% Author: Francois Tadel 2009-2011

% ===== PARSE INPUTS =====
if (nargin < 4)
    SamplesBounds = [];
end
if (nargin < 3)
    iEpoch = 1;
end

%% ===== READ BLOCK =====
nChan = sFile.header.numChans;
nEvt  = sFile.header.numEvents;
% Epochs and events
if isempty(SamplesBounds) 
    if ~isempty(sFile.epochs)
        SamplesBounds = round(sFile.epochs(iEpoch).times .* sFile.prop.sfreq);
    else
        SamplesBounds = [0, sFile.header.numSamples - 1];
    end
end
if ~isempty(sFile.epochs) 
    SamplesBounds = SamplesBounds + sFile.header.epochs_tim0(iEpoch);
end

% Get start and length of block to read
offsetData = SamplesBounds(1) * (nChan + nEvt) * sFile.header.bytesize;
nSamplesToRead = SamplesBounds(2) - SamplesBounds(1) + 1;
% Position file at the beginning of the data block
fseek(sfid, double(sFile.header.datapos + offsetData), 'bof');

% For each time sample: channels values, and then events values
% => Skip the events values 
sizeEvents = nEvt * sFile.header.bytesize;
% Read all events at once
F = fread(sfid, [nChan, nSamplesToRead], ...
          sprintf('%d*%s', nChan, sFile.header.byteformat), sizeEvents);
% Convert from microVolts to Volts
F = F * 1e-6;



