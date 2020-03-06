function probeFile = initializeProbeFile(RawFilename, output_dir, ChannelMat)

% convertedRawFilename = '0020' % no extension
% output_dir           = 'F:\Adrien\spyking circus test\'; % The temp file folder that the spikesorting takes place %

% %% Testing inputs
% RawFilename = 'a';
% output_dir = 'C:\Users\McGill\Desktop';
% ChannelMat = load('Z:\brainstorm_db\Ripples_Research\data\Jonathan\@rawEEG_2\channel.mat');

%% Initialize
Channels = ChannelMat.Channel;
nChannels = length(Channels);


%% Get which channels belong to which montages

% First check if any montages have been assigned
allMontages = {ChannelMat.Channel.Group};

nEmptyMontage = length(find(cellfun(@isempty,allMontages)));

if nEmptyMontage == length(ChannelMat.Channel)
    keepChannels = find(ismember({ChannelMat.Channel.Type}, 'EEG') | ismember({ChannelMat.Channel.Type}, 'SEEG'));
    
    % No montages have been assigned. Assign all EEG/SEEG channels to a
    % single montage
    for iChannel = 1:length(ChannelMat.Channel)
        if strcmp(ChannelMat.Channel(iChannel).Type, 'EEG') || strcmp(ChannelMat.Channel(iChannel).Type, 'SEEG')
            ChannelMat.Channel(iChannel).Group = 'GROUP1'; % Just adding an entry here
        end
    end
    temp_ChannelsMat = ChannelMat.Channel(keepChannels);

elseif nEmptyMontage == 0
    keepChannels = 1:length(ChannelMat.Channel);
    temp_ChannelsMat = ChannelMat.Channel(keepChannels);
else
    temp_ChannelsMat = ChannelMat.Channel;
end


montages = unique({temp_ChannelsMat.Group});
montages = montages(find(~cellfun(@isempty, montages)));

ChannelsInMontage  = cell(length(montages),2);
for iMontage = 1:length(montages)
    ChannelsInMontage{iMontage,1} = ChannelMat.Channel(strcmp({ChannelMat.Channel.Group}, montages{iMontage})); % Only the channels from the Montage should be loaded here to be used in the spike-events
    
    for iChannel = 1:length(ChannelsInMontage{iMontage})
        ChannelsInMontage{iMontage,2} = [ChannelsInMontage{iMontage,2} find(strcmp({ChannelMat.Channel.Name}, ChannelsInMontage{iMontage}(iChannel).Name))];
    end
end

nMontages = length(montages);
%% Insert the positioning of the electrodes to the probe file
% CONVERSION FROM 3D TO 2D NEEDED

% NOT REALLY NEEDED - MAYBE IN THE FUTURE


%% Start putting together everything

major_prefix = ['total_nb_channels	=  ' num2str(nChannels) '\nradius	=	100\n\nchannel_groups = {\n'];
all_entries = [];

for iMontage = 1:nMontages

    prefix = [' ' num2str(iMontage - 1) ': {''channels'':['];
    channel_numbers = [];
    for iChannel = 1:length(ChannelsInMontage{iMontage,1})
        if iChannel~=length(ChannelsInMontage{iMontage,1})
            channel_numbers = [channel_numbers num2str(ChannelsInMontage{iMontage,2}(iChannel) - 1) ', '];
        else
            channel_numbers = [channel_numbers num2str(ChannelsInMontage{iMontage,2}(iChannel) - 1)];
        end
    end
    channels_line = [prefix channel_numbers '],\n'];
    
    graph_line = '\t''graph'': [],\n';
    
    geometry_numbers = [];
    prefix = '\t''geometry'': {';
    for iChannel = 1:length(ChannelsInMontage{iMontage,1})
        if iChannel~=length(ChannelsInMontage{iMontage,1})
            geometry_numbers = [geometry_numbers num2str(ChannelsInMontage{iMontage,2}(iChannel)-1) ': [' num2str((iMontage-1)*200) ', ' num2str(iChannel-1) '], '];
        else
            geometry_numbers = [geometry_numbers num2str(ChannelsInMontage{iMontage,2}(iChannel)-1) ': [' num2str((iMontage-1)*200) ', ' num2str(iChannel-1) ']} '];
        end
    end
    geometry_line = [prefix geometry_numbers '\n\t},\n'];
    all_entries = [all_entries channels_line graph_line geometry_line];
    
end
    
final = [major_prefix all_entries '}'];

%% Write to file
probeFile = fullfile(output_dir, [RawFilename '.prb']);

outFid = fopen(probeFile, 'w');
fprintf(outFid,final);
fclose(outFid);


end