
%% Convert Neuroscope spiking events to Brainstorm

% The folder of the NEUROSCOPE files (.res, .fet, .clu)
folder = 'F:\Adrien\Ripples\AA20_d4_20171205-103721-001-p001_0';

% The BRAINSTORM channel file
ChannelMat = load('Z:\brainstorm_db\Ripples_Research\data\Jonathan\@rawAA20_d4_20171205-103721-001-p001_0\channel.mat');

% Sampling rate of the recording (used in the .fet files)
Fs = 30000;


%% Get the unique Montages / Shank that are present in the channel file
montages = unique({ChannelMat.Channel.Group});
montages = montages(find(~cellfun(@isempty, montages)));

%% Get the number of Montages that exist in the Neuroscope files
directoryContents = dir(folder);

iCluFiles = find(contains({directoryContents.name}, '.clu'));
iResFiles = find(contains({directoryContents.name}, '.res'));
% iFetFiles = find(contains({directoryContents.name}, '.fet'));
nMontages = length(iCluFiles); % How many "montages exist"


if (length(iCluFiles)~= length(iResFiles)) || length(montages) ~= length(iCluFiles)
    error('Something is off. You should have the same number of files for .res, .fet, .res filetypes and also the same number of Montages')
elseif length(iCluFiles)==0
    error('No files found. Probably the wrong folder was selected.')
end


%% Start converting
events = struct();
index = 0;

for iMontage = 1:nMontages
    
    % Information about the Neuroscope file can be found here:
    % http://neurosuite.sourceforge.net/formats.html

    %% Load necessary files
    % Extract filename from 'filename.fet.1'
       
    general_file = fullfile(directoryContents(1).folder, directoryContents(iCluFiles(1)).name);
    general_file = general_file(1:end-5);
    
    clu = load([general_file 'clu.' num2str(iMontage);]);
    res = load([general_file 'res.' num2str(iMontage);]);
    fet = dlmread([general_file 'fet.' num2str(iMontage);]);

    ChannelsInMontage = ChannelMat.Channel(strcmp({ChannelMat.Channel.Group}, montages{iMontage})); % Only the channels from the Montage should be loaded here to be used in the spike-events
    
    %% The combination of the .clu files and the .fet file is enough to use on the converter.

    % Brainstorm assign each spike to a SINGLE NEURON on each electrode. This
    % converter picks up the electrode that showed the strongest (absolute)
    % component on the .fet file and assigns the spike to that electrode. Consecutively, it
    % checks the .clu file to assign the spike to a specific neuron. If more
    % than one clusters are assigned to that electrode, different labels will
    % be created for each neuron.

    iChannels = zeros(size(fet,1),1);
    for iSpike = 2:size(fet,1) % The first entry will be zeros. Ignore
        [tmp,iPCA] = max(abs(fet(iSpike,1:end-3)));
        iChannels(iSpike) = ceil(iPCA/3);
    end
    
    % Now iChannels holds the Channel that each spike belongs to, and clu
    % holds the cluster that each spike belongs to. Assign unique labels to
    % multiple neurons on the same electrode.

    % Initialize output structure
    
    spikesPrefix = process_spikesorting_supervised('GetSpikesEventPrefix');

    uniqueClusters = unique(clu(2:end))'; % The first entry is just the number of clusters

    for iCluster = 1:length(uniqueClusters)
        selectedSpikes = find(clu==uniqueClusters(iCluster));

        [tmp,iMaxFeature] = max(sum(abs(fet(selectedSpikes,1:end-3))));
        iElectrode = ceil(iMaxFeature/3);

        index = index+1;
        % Write the packet to events
        if uniqueClusters(iCluster)==0
            events(index).label       = ['Spikes Noise ' montages{iMontage} ' |' num2str(uniqueClusters(iCluster)) '|'];
        elseif uniqueClusters(iCluster)==1
            events(index).label       = ['Spikes MUA ' montages{iMontage} ' |' num2str(uniqueClusters(iCluster)) '|'];
        else
            events(index).label       = [spikesPrefix ' ' ChannelsInMontage(iElectrode).Name ' |' num2str(uniqueClusters(iCluster)) '|'];
        end
        events(index).color       = rand(1,3);
        events(index).times       = fet(selectedSpikes,end)' ./ Fs;  % The timestamps are in SAMPLES
        events(index).epochs      = ones(1,length(events(index).times));
        events(index).reactTimes  = [];
        events(index).select      = 1;
        events(index).channels    = cell(1, size(events(index).times, 2));
        events(index).notes       = cell(1, size(events(index).times, 2));
    end




end






