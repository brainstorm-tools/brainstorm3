function file = AddNSFile(file, ns, starting_time)
% ns can be filepath or data structure

if ~exist('starting_time','var') || isempty(starting_time)
    starting_time = 0.0;
end

if ischar(ns)
    lfp_data = openNSx(ns);
else
    lfp_data = ns;
end

labels = {lfp_data.ElectrodesInfo.Label};

elecs = [];%zeros(length(labels), 1);
for i = 1:length(labels)
    elecs(i) = strcmp(labels{i}(1:4), 'elec');
end

%% Electrode Table

dev = types.core.Device();
file.general_devices.set('dev1', dev);

eg = types.core.ElectrodeGroup(...
    'description', 'a test ElectrodeGroup', ...
    'location', 'unknown', ...
    'device', types.untyped.SoftLink('/general/devices/dev1'));
file.general_extracellular_ephys.set('electrode_group', eg);
ov = types.untyped.ObjectView('/general/extracellular_ephys/electrode_group');

variables = {'x', 'y', 'z', 'imp', 'location', 'filtering', ...
    'description', 'group'};
tbl = table(NaN, NaN, NaN, NaN, {'unknown'}, {'unknown'}, labels(1), ov,...
    'VariableNames', variables);
for i = 2:sum(elecs)
    tbl = [tbl; {NaN, NaN, NaN, NaN, 'unknown', 'unknown', labels(i), ov}];
end

electrode_table = util.table2nwb(tbl, 'all electrodes');
file.general_extracellular_ephys_electrodes = electrode_table;

%% Electrode Table Region

electrodes_object_view = types.untyped.ObjectView( ...
    '/general/extracellular_ephys/electrodes');

electrode_table_region = types.core.DynamicTableRegion( ...
    'table', electrodes_object_view, ...
    'description', 'all electrodes', ...
    'data', [0 height(tbl)-1]');

%% write LFP
elec_info = lfp_data.ElectrodesInfo(find(elecs, 1));

[unit, conversion] = util.blackrock.get_channel_info(elec_info);

es = types.core.ElectricalSeries( ...
    'data', single(lfp_data.Data(logical(elecs),1:100))', ...
    'starting_time_rate', lfp_data.MetaTags.TimeRes, ...
    'starting_time', starting_time, ...
    'electrodes', electrode_table_region, ...
    'data_unit', unit, ...
    'data_conversion', conversion);

file.acquisition.set('lfp', es);

%% write other acquisition

non_elecs = find(1-elecs);

for i = 1:length(non_elecs)

    channel = non_elecs(i);
    
    label = labels{channel};
    label = label(logical(label));
    
    elec_info = lfp_data.ElectrodesInfo(channel);
    
    [unit, conversion] = util.blackrock.get_channel_info(elec_info);

    ts = types.core.TimeSeries( ...
        'data', single(lfp_data.Data(channel,:))', ...
        'starting_time_rate', lfp_data.MetaTags.TimeRes, ...
        'starting_time', starting_time, ...
        'data_unit', unit, ...
        'data_conversion', conversion);
    
    file.acquisition.set(label, ts);
    
end