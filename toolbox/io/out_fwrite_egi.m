function out_fwrite_egi(sFile, sfid, SamplesBounds, ChannelsRange, F)
% OUT_FWRITE_EGI: Write a block of recordings from a EGI .raw file.

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
% Authors: Francois Tadel, 2014-2019

% ===== PARSE INPUTS =====
nChannels = double(sFile.header.numChans);
nEvents   = length(sFile.events);
if isempty(ChannelsRange)
    ChannelsRange = [1, nChannels];
    isSaveAll = 1;
elseif isequal(ChannelsRange, [1, nChannels])
    isSaveAll = 1;
else
    ChannelsRange = double(ChannelsRange);
    isSaveAll = 0;
end
if isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end
SamplesBounds = SamplesBounds - round(sFile.prop.times(1) .* sFile.prop.sfreq);

% Convert from Volts to microVolts
F = F * 1e6;
% Everything is stored on 32 bit floats
bytesPerVal = 4;
dataClass = 'float32';


% ===== SEEK IN FILE =====
% Offset of the beginning of the recordings in the file
offsetHeader = round(sFile.header.datapos);
% Save data + events
if isSaveAll
    % Create events matrix
    Fevt = zeros(nEvents, size(F,2));
    for iEvt = 1:nEvents
        evtSmp = round((sFile.events(iEvt).times - sFile.prop.times(1)) .* sFile.prop.sfreq) - SamplesBounds(1) + 1;
        % Extended events
        if (size(evtSmp,1) == 2)
            extSmpEvt = [];
            for iOcc = 1:size(evtSmp,2)
                extSmpEvt = [extSmpEvt, evtSmp(1,iOcc):evtSmp(2,iOcc)];
            end
            evtSmp = extSmpEvt;
        end
        % Keep only the indices between the boundaries to write
        evtSmp((evtSmp < 1) | (evtSmp > size(F,2))) = [];
        % Set the events channel to "1"
        if ~isempty(evtSmp)
            try
                Fevt(iEvt, evtSmp) = 1;
            catch
                disp
            end
        end
    end
    % Add events to the data to write
    F = [F; Fevt];
    % Offsets
    offsetTime    = round(SamplesBounds(1) * (nChannels + nEvents) * bytesPerVal);
    offsetStart   = offsetHeader + offsetTime;
    offsetSkip    = 0;
else
    offsetTime    = round(SamplesBounds(1) * (nChannels + nEvents) * bytesPerVal);
    offsetChannel = round((ChannelsRange(1) - 1 ) * bytesPerVal);
    offsetStart   = offsetHeader + offsetTime + offsetChannel;
    offsetSkip    = round((ChannelsRange(1) - 1 + nEvents) * bytesPerVal);
end
% Position file at the beginning of the block to write
res = fseek(sfid, offsetStart, 'bof');
% If it's not possible to seek there (file not big enough): go the end of the file, and appends zeros until we reach the point we want
if (res == -1)
    fseek(sfid, 0, 'eof');
    nBytes = offsetStart - ftell(sfid);
    if (nBytes > 0)
        fwrite(sfid, 0, 'char', nBytes - 1);
    end
end
    
% ===== WRITE DATA BLOCK =====
% Write epoch data
if (offsetSkip == 0)
    ncount = fwrite(sfid, F, dataClass);
else
    % Offset is skipped BEFORE the values are read: so need to write the first value, and then the rest
    ncount = fwrite(sfid, F(:,1), dataClass);
    if (size(F,2) > 1)
        precision = sprintf('%d*%s', ChannelsRange(2)-ChannelsRange(1)+1, dataClass);
        ncount = ncount + fwrite(sfid, F(:,2:end), precision, offsetSkip);
    end
end
% Check number of values written
if (ncount ~= numel(F))
    error('Error writing data to file.');
end



