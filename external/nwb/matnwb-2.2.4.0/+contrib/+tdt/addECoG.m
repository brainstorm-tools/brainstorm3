function nwbfile = addECoG(nwbfile, streams, electrode_table_region, ecog_channels, blockpath)

rv = types.untyped.RegionView('/general/extracellular_ephys/electrodes',...
    {[1 sum(elecs)]});

etr = types.core.ElectrodeTableRegion('data', rv);

stream_names = fieldnames(streams);

ecog_stream_names = sort(stream_names(contains(stream_names,'Wav')));

Data = [];
for i = 1:length(ecog_stream_names)
    stream = streams.(ecog_stream_names{i});
    Data = [Data, stream.data'];
end
Data = Data(:,ecog_channels);

es = types.core.ElectricalSeries(...
    'starting_time',stream.startTime,...
    'starting_time_rate',stream.fs,...
    'data',Data',...
    'electrodes', electrode_table_region,...
    'data_unit','V');

file.acquisition.set('ECoG', es);




