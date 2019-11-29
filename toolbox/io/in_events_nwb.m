function events = in_events_nwb(sFile, nwb2, nEpochs, ChannelMat)
% IN_EVENTS_NWB Read events from a Neurodata Without Borders file.

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
% Authors: Konstantinos Nasiotis, 2019

%% Reads spiking and acquisition events

% Check if an events field exists in the dataset
try
    events_exist = ~isempty(nwb2.stimulus_presentation);
    if ~events_exist
        disp('No events in this .nwb file')
    else
        all_event_keys = keys(nwb2.stimulus_presentation);
        disp(' ')
        disp('The following event types are present in this dataset')
        disp('------------------------------------------------')
        for iEvent = 1:length(all_event_keys)
            disp(all_event_keys{iEvent})
        end
        disp(' ')
    end
catch
    disp('No events in this .nwb file')
    return
end


if events_exist    
    % Initialize list of events
    events = repmat(db_template('event'), 1, length(all_event_keys));

    for iEvent = 1:length(all_event_keys)
        events(iEvent).label    = all_event_keys{iEvent};
        events(iEvent).color    = rand(1,3);
        events(iEvent).times    = nwb2.stimulus_presentation.get(all_event_keys{iEvent}).timestamps.load';     
        events(iEvent).channels = cell(1, size(events(iEvent).times, 2));
        events(iEvent).notes    = cell(1, size(events(iEvent).times, 2));
        % Check on which epoch each event belongs to
        if nEpochs > 1
            % Initialize to first epoch - if some events are not within the
            % epoch bounds, they will stay assigned to the first epoch
            events(iEvent).epochs  = ones(1, length(events(iEvent).times));
            
            % CHECK IF THE INITIALIZATION AS 0 AFFECTS THE CONTINUOUS SIGNALS
            
            for iEpoch = 1:nEpochs
                eventsInThisEpoch = find((events(iEvent).times >= sFile.epochs(iEpoch).times(1)) & (events(iEvent).times < sFile.epochs(iEpoch).times(2)));
                events(iEvent).epochs(eventsInThisEpoch) = iEpoch;
            end
        else
            events(iEvent).epochs  = ones(1, length(events(iEvent).times));
        end
    end 
end

%% Read the Spikes' events
try
    nNeurons = length(nwb2.units.vectordata.get('max_electrode').data.load);
    SpikesExist = 1;
catch
    warning('The format of the spikes (if any are saved) in this .nwb is not compatible with Brainstorm - The field "nwb2.units.vectordata.get("max_electrode")" that assigns spikes to specific electrodes is needed')
    SpikesExist = 0;
end
    
if SpikesExist
     
    amp_channel_IDs = nwb2.general_extracellular_ephys_electrodes.vectordata.get('amp_channel').data.load;
    maxWaveformCh = nwb2.units.vectordata.get('max_electrode').data.load; % The channels on which each Neuron had the maximum amplitude on its waveforms - Assigning each neuron to an electrode
    
    if ~exist('events')
        events_spikes = repmat(db_template('event'), 1, nNeurons);
    end

    for iNeuron = 1:nNeurons

        if iNeuron == 1
            times = nwb2.units.spike_times.data.load(1:sum(nwb2.units.spike_times_index.data.load(iNeuron)));
        else
            times = nwb2.units.spike_times.data.load(sum(nwb2.units.spike_times_index.data.load(iNeuron-1))+1:sum(nwb2.units.spike_times_index.data.load(iNeuron)));
        end
        times = times(times~=0);

        
        % Check if a channel has multiple neurons:
        nNeuronsOnChannel = sum( maxWaveformCh == maxWaveformCh(iNeuron));
        iNeuronsOnChannel = find(maxWaveformCh == maxWaveformCh(iNeuron));
           
        
        theChannel = find(amp_channel_IDs==maxWaveformCh(iNeuron));
        
        if nNeuronsOnChannel == 1
            events_spikes(iNeuron).label  = ['Spikes Channel ' ChannelMat.Channel(theChannel).Name];
        else
            iiNeuron = find(iNeuronsOnChannel==iNeuron);
            events_spikes(iNeuron).label  = ['Spikes Channel ' ChannelMat.Channel(theChannel).Name ' |' num2str(iiNeuron) '|'];
        end
        
        events_spikes(iNeuron).color      = rand(1,3);
        events_spikes(iNeuron).epochs     = ones(1,length(times));
        events_spikes(iNeuron).times      = times;
        events_spikes(iNeuron).reactTimes = [];
        events_spikes(iNeuron).select     = 1;
        events_spikes(iNeuron).channels   = cell(1, size(events_spikes(iNeuron).times, 2));
        events_spikes(iNeuron).notes      = cell(1, size(events_spikes(iNeuron).times, 2));
        
        % Check on which epoch each event belongs to
        if nEpochs > 1
            % Initialize to first epoch - if some events are not within the
            % epoch bounds, they will stay assigned to the first epoch
            events_spikes(iNeuron).epochs  = ones(1, length(events_spikes(iNeuron).times));
            
            for iEpoch = 1:nEpochs
                eventsInThisEpoch = find(events_spikes(iNeuron).times >= sFile.epochs(iEpoch).times(1) & events_spikes(iNeuron).times < sFile.epochs(iEpoch).times(2));
                events_spikes(iNeuron).epochs(eventsInThisEpoch) = iEpoch;
            end
        else
            events_spikes(iNeuron).epochs  = ones(1, length(events_spikes(iNeuron).times));
        end
        
        
    end
        
        
    if exist('events')
        events = [events events_spikes];
    else
        events = events_spikes;
    end
end


end