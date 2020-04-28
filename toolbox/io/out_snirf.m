function  out_snirf(ExportFile,DataMat,ChannelMatOut)

% Create an empty snirf data structure
snirfdata=jsnirfcreate();


nirs_channels = strcmpi({ChannelMatOut.Channel.Type}, 'NIRS')';
nirs_aux = ~nirs_channels;

n_channel=sum(nirs_channels);
n_aux=sum(nirs_aux);

% Set data
snirfdata.SNIRFData.data.dataTimeSeries=DataMat.F(nirs_channels,:)'; % Time*Channels
snirfdata.SNIRFData.data.time=DataMat.Time'; % Time*1

% Set auxiliary data
aux_channel=find(nirs_aux);
for i_aux=1:n_aux
    snirfdata.SNIRFData.aux(i_aux).name=ChannelMatOut.Channel(aux_channel(i_aux)).Name;
    snirfdata.SNIRFData.aux(i_aux).dataTimeSeries=DataMat.F(aux_channel(i_aux),:)';
    snirfdata.SNIRFData.aux(i_aux).time=DataMat.Time';
end    

% Set Probe; maybe can be simplified with the export of the measurment list
[isrcs, idets, chan_measures, measure_type] = nst_unformat_channels({ChannelMatOut.Channel(nirs_channels).Name});

src_pos=[];
for i_src=unique(isrcs) % iterate over the source index
    src_pos(end+1,:)=ChannelMatOut.Channel(i_src).Loc(:,1)';
end    
det_pos=[];
for i_det=unique(idets) % iterate over the detector index
    det_pos(end+1,:)=ChannelMatOut.Channel(i_det).Loc(:,2)';
end    

% Todo : export detectorLabels and sourceLabels (string array)
snirfdata.SNIRFData.probe.wavelengths=ChannelMatOut.Nirs.Wavelengths;
snirfdata.SNIRFData.probe.sourcePos=src_pos;
snirfdata.SNIRFData.probe.detectorPos=det_pos;

% Set landmark position (eg fiducials) 
% Todo : make sure those landmark are defined ? Add AC,PC,IH
snirfdata.SNIRFData.probe.landmarkPos =  [ ChannelMatOut.SCS.NAS ; ...
                                           ChannelMatOut.SCS.LPA ; ...
                                           ChannelMatOut.SCS.RPA ] ;
                                           
snirfdata.SNIRFData.probe.landmarkLabels(1)="Nasion";
snirfdata.SNIRFData.probe.landmarkLabels(2)="LeftEar";
snirfdata.SNIRFData.probe.landmarkLabels(3)="RightEar";

% Set Measurment list
for ichan=1:n_channel
    measurement=struct('sourceIndex',[],'detectorIndex',[],...
              'wavelengthIndex',[],'dataType',1,'dataTypeIndex',1); 
          
    measurement.sourceIndex=isrcs(ichan);
    measurement.detectorIndex=idets(ichan);
    measurement.wavelengthIndex=find(ChannelMatOut.Nirs.Wavelengths==chan_measures(ichan));

    snirfdata.SNIRFData.data.measurementList(ichan)=measurement;      

end   

% Set Stim 
n_event=length(DataMat.Events);
for i_event=1:n_event
    stim=struct('name','','data',[]);
    stim.name=DataMat.Events(i_event).label;
    
    % Fill stimulus time course; each line correspond to [starttime duration value]
    n_stimuli=size(DataMat.Events(i_event).times,2);
    is_extended=size(DataMat.Events(i_event).times,1)==2;
    data=zeros(n_stimuli,3);
    for i_stim=1:n_stimuli
        starttime=DataMat.Events(i_event).times(1,i_stim);
        
        if is_extended 
            duration=DataMat.Events(i_event).times(2,i_stim) - starttime;
        else
            duration=0;
        end    
        value=1;
        data(i_stim,:)=[starttime duration value];
    end    
    stim.data=data;
    snirfdata.SNIRFData.stim(i_event)=stim;   
end    


% Save snirf file. 
savesnirf(snirfdata, ExportFile);
end

function [isrcs, idets, measures, measure_type] = nst_unformat_channels(channel_labels, warn_bad_channels)
% NST_UNFORMAT_CHANNELS extract sources, dectectors and measures information 
% from channel labels with *homogeneous* type (eg wavelength or Hb).
%
%   [ISRCS, IDETS, MEAS, CHAN_TYPE] = NST_UNFORMAT_CHANNELS(CHANNEL_LABELS)
%       CHANNEL_LABELS (cell array of str): 
%           each str is formatted as 'SxDyWLz' or 'SxDyHbt', where:
%               x: source index
%               y: detector index
%               z: wavelength
%               t: Hb type (O, R, T).
%           Consistency is asserted so that:
%               - channels are unique
%               - channel type is homogeneous
%           Warning is issued if:
%               - the number of measures per pair is not homogeneous
%                 eg one pair has only one wavelength
%
%           Examples: S1D2WL685, S01D7WL830, S3D01HbR
%           
%
%        ISRCS (array of int): extracted source indexes
%        IDETS (array of int): extracted detector indexes
%        MEAS (array of int | cell array of str): extracted measure values
%        CHAN_TYPE (array of int): channel type (see NST_CHANNEL_TYPES for enum).
%
%   See also NST_UNFORMAT_CHANNEL, NST_CHANNEL_TYPES, NST_FORMAT_CHANNEL

assert(iscellstr(channel_labels));

if nargin < 2
    warn_bad_channels = 0;
end
    

nb_channels = length(channel_labels);
isrcs = zeros(1, nb_channels);
idets = zeros(1, nb_channels);
measures = cell(1, nb_channels);
mtypes = zeros(1, nb_channels);
reformated_channels = cell(1, nb_channels);
for ichan=1:nb_channels
    [isrc, idet, meas, mtype] = nst_unformat_channel(channel_labels{ichan}, warn_bad_channels);
    isrcs(ichan) = isrc;
    idets(ichan) = idet;
    measures{ichan} = meas;
    mtypes(ichan) = mtype;
    if ~isnan(isrc) && ~isnan(idet)
        % reformat channels to make sure formatting is consistent
        % -> allow proper duplicate detection after
        reformated_channels{ichan} = nst_format_channel(isrc, idet, meas);
    else
        reformated_channels{ichan} = '';
    end
end

% check uniqueness
[~, i_unique] = unique(reformated_channels);
duplicates = reformated_channels;
duplicates(i_unique) = [];
duplicates(strcmp(duplicates, '')) = []; %remove unrecognized channels
i_duplicates = ismember(reformated_channels, unique(duplicates));
if ~isempty(duplicates)
    msg = sprintf('Duplicated channels: "%s". Indexes: %s', ...
                  strjoin(channel_labels(i_duplicates), ', '), num2str(i_duplicates));
    throw(MException('NIRSTORM:NonUniqueChannels', msg));
end

% check homogeneity of channel type
mtypes = mtypes(~isnan(mtypes));
if length(unique(mtypes)) > 1
    throw(MException('NIRSTORM:NonHomogeneousMeasure', 'Measure type is not homogeneous.'));
end

measure_types = nst_measure_types();
measure_type = mtypes(1);
if measure_type == measure_types.WAVELENGTH
   measures = cell2mat(measures);
end

%% Check number of measures per pair
max_idet = (max(idets)+1);
pairs_hash = isrcs(~isnan(isrcs)) * max_idet + idets(~isnan(isrcs));
unique_pairs_hash = unique(pairs_hash);
mcounts = sparse(ones(1, length(unique_pairs_hash)), unique_pairs_hash, ...
                      ones(1, length(unique_pairs_hash)), 1, max(unique_pairs_hash), ...
                      nb_channels);
if ~iscell(measures)                 
    all_measures = unique(measures(~isnan(measures)));
else
    all_measures = unique(measures(cellfun(@(e) ischar(e) || ~isnan(e), measures)));  
end
for ichan=1:nb_channels
    if ~isnan(isrcs(ichan))
        if measure_type == measure_types.WAVELENGTH
            measure_hash = find(measures(ichan)==all_measures);
        elseif measure_type == measure_types.HB
            measure_hash = find(strcmp(measures(ichan),all_measures));
        end
        h_idx = isrcs(ichan) * max_idet + idets(ichan);
        mcounts(h_idx) = mcounts(h_idx) + measure_hash;
    end
end

% pairs with too many measures:
i_inconsistant_measures = (mcounts ~= sum(1:length(all_measures)) + 1) & (mcounts ~= 0);

if nnz(i_inconsistant_measures) > 0
    [isrc_incon,idet_incon,counts] = find(i_inconsistant_measures);
    inconsistent_pairs = cell(1, length(isrc_incon));
    for ipair=1:length(isrc_incon)
        inconsistent_pairs{ipair} = sprintf('S%dD%d', isrc_incon(ipair), idet_incon(ipair));
    end 
    warning('Inconsistent measure(s) for pair(s): %s', strjoin(inconsistent_pairs, ', '));
end

end



