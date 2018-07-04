% Information about the Neuroscope file can be found here:
% http://neurosuite.sourceforge.net/formats.html



%% load the files here.
% 4 types of files:
% 1: .clu
% 2: .fet
% 3: .res
% 4: .spk

folder = 'D:\brainstorm_db\Tutorial_e-Phys\data\Floyd\@rawytu288c-01_converted_converted\ytu288c-01_converted_converted_kilosort_spikes';
study = 'ytu288c-01_converted_converted';
ChannelMat = load('D:\brainstorm_db\Tutorial_e-Phys\data\Floyd\@rawytu288c-01_converted_converted\channel.mat');
DataMat = in_bst_data('D:\brainstorm_db\Tutorial_e-Phys\data\Floyd\@rawytu288c-01_converted_converted\data_0raw_ytu288c-01_converted_converted.mat', 'F');
sFile = DataMat.F; clear DataMat



% nWaveformSamples = 32;
% 
% iSpikeToSelect = 100;


%% .clu files

% The first entry is just the number of unique clusters that exist in the
% .clu file.

% nClusters = clu(1);  or nClusters = unique(clu(2:end));

clu_file = [folder '\' study '.clu.1'];
clu = load(clu_file); % 30467x1 (First entry is nClusters)





%% .res files

res_file = [folder '\' study '.res.1'];
res = load(res_file); % Timestamps of the spikes (in Samples): 30466 x 1


%% .fet files

% 30467 x 18: Spikes x Features

% The first entry (fet(1,1)) is just the number of clusters???? Maybe they mean
% features

% The features comprise of: 3 pricipal components for each channel (3 components x 5 channels = 15)
% The last 3 are: [wranges; wpowers; spikeTimes (in samples)]

fet_file = [folder '\' study '.fet.1'];
fet = dlmread(fet_file);



%% The combination of the .clu files and the .fet file is enough to use on the converter.

% Brainstorm assign each spike to a SINGLE NEURON on each electrode. This
% converter picks up the electrode that showed the strongest (absolute)
% component on the .fet file and assigns the spike to that electrode. Consecutively, it
% checks the .clu file to assign the spike to a specific neuron. If more
% than one clusters are assigned to that electrode, different labels will
% be created for each neuron.

iChannels = zeros(size(fet,1),1); 
for iSpike = 2:size(fet,1) % The first entry will be zeros. Ignore
    [~,iPCA] = max(abs(fet(iSpike,1:end-3)));
    iChannels(iSpike) = ceil(iPCA/3);
end



% Now iChannels holds the Channel that each spike belongs to, and clu
% holds the cluster that each spike belongs to. Assign unique labels to
% multiple neurons on the same electrode.


nChannels = length(ChannelMat.Channel); %Get this from the channelMat

% Initialize
clear events

events = struct;
events(2).label = [];
events(2).epochs = [];
events(2).times = [];
events(2).color = [];
events(2).samples = [];
events(2).reactTimes = [];
events(2).select = [];
index = 0;


uniqueClusters = unique(clu(2:end))'; % The first entry is just the number of clusters

for iCluster = 1:length(uniqueClusters)
    selectedSpikes = find(clu==uniqueClusters(iCluster));
    
    [~,iMaxFeature] = max(sum(abs(fet(selectedSpikes,1:end-3))));
    iElectrode = ceil(iMaxFeature/3);
    
    index = index+1;
    % Write the packet to events
    if uniqueClusters(iCluster)==1
        events(index).label       = 'Spikes Noise |1|';
    else
        events(index).label       = ['Spikes Channel ' ChannelMat.Channel(iElectrode).Name ' |' num2str(uniqueClusters(iCluster)) '|'];
    end    
    events(index).color       = rand(1,3);
    events(index).samples     = fet(selectedSpikes,end)'; % The timestamps are in SAMPLES
    events(index).times       = events(index).samples./sFile.prop.sfreq;
    events(index).epochs      = ones(1,length(events(index).samples));
    events(index).reactTimes  = [];
    events(index).select      = 1;

end
