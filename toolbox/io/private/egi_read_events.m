function [events, epochs, epochs_tim0] = egi_read_events(sFile, sfid, isUseEpoc)
% EGI_READ_EVENTS: Read events and epochs description from an EGI .raw file.
%
% USAGE:  [events, epochs, epochs_tim0] = egi_read_events(sFile, sfid, isUseEpoc)
%         [events, epochs, epochs_tim0] = egi_read_events(sFile, sfid)             % isUseEpoc = 1;
%
% INPUT:
%     - sFile     : Brainstorm structure for file import
%     - sfid      : Pointer to an open file to read the data from
%     - isUseEpoc : Use EPOC events to generate epochs from the file
% OUTPUT:
%     - events : Brainstorm structure to represent events list
%     - epochs : Brainstorm structure to represent epochs list
%     - epochs_tim0 : Array of sample indices; for each epoch, contain the absolute position of t=0 in file

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2011

% Parse inputs
if (nargin < 3) || isempty(isUseEpoc)
    isUseEpoc = 1;
end
% Initialize returned values
epochs = sFile.epochs;
events = sFile.events;
epochs_tim0 = [];
% If no events: return nothing
if (sFile.header.numEvents == 0)
    return
end

% Position file at the beginning of the data block
fseek(sfid, double(sFile.header.datapos), 'bof');
% For each time sample: channels values, and then events values
% => Skip the channel values 
sizeChannels = sFile.header.numChans * sFile.header.bytesize;
fseek(sfid, sizeChannels, 'cof');
% Read all events at once
eventArray = fread(sfid, [sFile.header.numEvents, sFile.header.numSamples], ...
                   sprintf('%d*%s', sFile.header.numEvents, sFile.header.byteformat), sizeChannels);
% If not enough values read: error
if (numel(eventArray) ~= sFile.header.numEvents * sFile.header.numSamples)
    error('Could not read events tracks.');
end

% === USE EPOC EVENTS ===
if isUseEpoc
    % Look for "epoc" event
    iEpocEvt = find(strcmpi(sFile.header.eventCodes, 'epoc'), 1);
    iTim0Evt = find(strcmpi(sFile.header.eventCodes, 'tim0'), 1);
    if ~isempty(iTim0Evt)
        iTim0Smp = find(eventArray(iTim0Evt,:)) - 1;
    else
        iTim0Smp = [];
    end
    EpochChannel = ones(1, sFile.header.numSamples);
    epochs_tim0 = 0;
    if ~isempty(iEpocEvt)
        % Get all the events "epoc"
        iEpocSmp = find(eventArray(iEpocEvt,:)) - 1;
        % Loop on all the epochs
        if (length(iEpocSmp) >= 2)
            for iEpoch = 1:length(iEpocSmp)
                % Sample bounds for this epoch
                if (iEpoch < length(iEpocSmp))
                    smpBounds = [iEpocSmp(iEpoch), iEpocSmp(iEpoch+1) - 1];
                else
                    smpBounds = [iEpocSmp(iEpoch), sFile.header.numSamples - 1];
                end
                % Save epochs indices
                EpochChannel(smpBounds(1)+1:smpBounds(2)+1) = iEpoch;
                % Look for Time0 for this epoch
                iTim0 = find((iTim0Smp >= smpBounds(1)) & (iTim0Smp <= smpBounds(2)));
                if ~isempty(iTim0)
                    epochs_tim0(iEpoch) = iTim0Smp(iTim0);
                    smpBounds = smpBounds - iTim0Smp(iTim0);
                else
                    epochs_tim0(iEpoch) = 0;
                end
                % Create epoch structure
                epochs(iEpoch).label   = sprintf('Epoch #%d', iEpoch);
                epochs(iEpoch).times   = smpBounds / sFile.prop.sfreq;
                epochs(iEpoch).nAvg    = 1;
                epochs(iEpoch).select  = 1;
                epochs(iEpoch).bad     = 0;
                epochs(iEpoch).channelflag = [];
            end
        end
    end
else
    EpochChannel = ones(1, sFile.header.numSamples);
    epochs_tim0 = 0;
end

iEmptyEvt = [];
% Build Brainstorm events structure
for iEvt = 1:sFile.header.numEvents
    % EVENT GROUP
    % Detect all the non-null values 
    smpList = find(eventArray(iEvt,:)) - 1;
    % Creating the event group structure   
    iEpochs = EpochChannel(smpList+1);
    events(iEvt).label      = sFile.header.eventCodes{iEvt};
    events(iEvt).times      = [];
    events(iEvt).reactTimes = [];
    events(iEvt).select     = 1;
    % If no occurrences of the event: nothing else to do
    if isempty(smpList)
        iEmptyEvt(end+1) = iEvt;
        continue;
    end
    
    % EVENT OCCURRENCES
    % Detecting if it is a "simple event" or an "extended event" (ie. event spans over more than one sample)
    diffList = diff(smpList);
    % Simple events: add each non-null value in the trigger channel as an event occurrence
    samples = [];
    if all(diffList ~= 1)
        samples = smpList - epochs_tim0(iEpochs);
        events(iEvt).epochs  = iEpochs;
    % Extended events: processing sequentially the trigger channel 
    else
        diffList = [2 diffList];
        for i = 1:length(diffList)           
            % If trigger is not in the same event as the previous one: create new occurrence
            if (diffList(i) ~= 1)
                iOcc = size(samples, 2) + 1;
                samples(:,iOcc) = ones(2,1) .* (smpList(i) - epochs_tim0(iEpochs(i)));
                events(iEvt).epochs(1,iOcc)  = iEpochs(i);
            % If not: Extend event in time
            else
                samples(2,iOcc) = smpList(i) - epochs_tim0(iEpochs(i));
            end
        end
    end
    % Set the times
    events(iEvt).times    = samples ./ sFile.prop.sfreq;
    events(iEvt).channels = cell(1, size(events(iEvt).times, 2));
    events(iEvt).notes    = cell(1, size(events(iEvt).times, 2));
end

% %% ===== DELETE EMPTY EVENTS =====
% if ~isempty(iEmptyEvt)
%     events(iEmptyEvt) = [];
%     NO => WE WANT TO KEEP THE EMPTY EVENTS TO KEEP THE CORRESPONDANCE WITH THE INITIAL FILE
% end







