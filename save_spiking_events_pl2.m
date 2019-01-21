




filename = 'C:\Users\McGill\Desktop\4chDemoPL2.pl2';
pl2 = PL2GetFileIndex(filename);



%% Get the acquisition system events
events_acquisition = db_template('event');

iEnteredEvent = 0;
for iEvent = 1:length(pl2.EventChannels)
    if pl2.EventChannels{iEvent}.NumEvents
        iEnteredEvent = iEnteredEvent + 1;

        events_acquisition(iEnteredEvent).label   = pl2.EventChannels{iEvent}.Name;
        events_acquisition(iEnteredEvent).color   = rand(1,3);
        
        TheEventsInSeconds = PL2EventTs(filename,iEvent);
        
        events_acquisition(iEnteredEvent).times   = TheEventsInSeconds.Ts';
        events_acquisition(iEnteredEvent).samples = round(events_acquisition(iEnteredEvent).times * pl2.AnalogChannels{1}.SamplesPerSecond);    % I USE THE SAMPLING RATE OF THE ANALOG CHANNEL HERE. PROBABLY CORRECT   
        events_acquisition(iEnteredEvent).epochs  = ones(1,length(events_acquisition(iEnteredEvent).times));
        events_acquisition(iEnteredEvent).select  = 1;
    end
end





%%

% Enabled spikes channels holds the indices of the channels that have
% spikes
enabledSpikesChannels = [];
nNeurons = []; % Holds the number of neurons that were picked up on each channel
for iSpikesChannel = 1:length(pl2.SpikeChannels)
    if pl2.SpikeChannels{iSpikesChannel}.Enabled
        enabledSpikesChannels = [enabledSpikesChannels iSpikesChannel];
        nNeurons = [nNeurons pl2.SpikeChannels{iSpikesChannel}.NumberOfUnits];
    end
end
    

%% Create the Brainstorm events struct 
events_spikes = db_template('event');

iEndEvents = length(events_spikes);
for iSpikesChannel = 1:length(enabledSpikesChannels)
    
    for iNeuron = 1:nNeurons(iSpikesChannel)
        iEndEvents = length(events_spikes)+1;
        if nNeurons(iSpikesChannel) == 1
            events_spikes(iEndEvents).label   = ['Spikes Channel ' pl2.AnalogChannels{iSpikesChannel}.Name];
            events_spikes(iEndEvents).color   = rand(1,3);
            events_spikes(iEndEvents).times   = PL2Ts( filename, iSpikesChannel, iNeuron)';
            events_spikes(iEndEvents).samples = round(events_spikes(iEndEvents).times * pl2.SpikeChannels{iSpikesChannel}.SamplesPerSecond);       
            events_spikes(iEndEvents).epochs  = ones(1,length(events_spikes(iEndEvents).times));
            events_spikes(iEndEvents).select  = 1;
            
        else
            events_spikes(iEndEvents).label   = ['Spikes Channel ' pl2.AnalogChannels{iSpikesChannel}.Name ' |' num2str(iNeuron) '|'];
            events_spikes(iEndEvents).color   = rand(1,3);
            events_spikes(iEndEvents).times   = PL2Ts( filename, iSpikesChannel, iNeuron)';
            events_spikes(iEndEvents).samples = round(events_spikes(iEndEvents).times * pl2.SpikeChannels{iSpikesChannel}.SamplesPerSecond);       
            events_spikes(iEndEvents).epochs  = ones(1,length(events_spikes(iEndEvents).times));
            events_spikes(iEndEvents).select  = 1;
        end
    end
end
            

events_spikes = events_spikes(2:end);



%% Merge the two types of events

events = [events_acquisition events_spikes];


