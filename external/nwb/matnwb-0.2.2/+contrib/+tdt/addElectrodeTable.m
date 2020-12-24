function file = addElectrodeTable(file, tdt)

% get streams that are of the form "Wav#"
stream_names = fields(tdt.streams);
stream_names = regexp(stream_names(:),'Wav.','match');
wav_names = {};
for i = stream_names'
    if ~isempty(i{1})
        wav_names{end+1} = i{1}{1};
    end
end
wav_names = sort(wav_names);

labels = {};
for wav_name = wav_names
    stream = tdt.streams.(wav_name{1});
    for i = 1:size(stream.data,1)
        chan_num_str = sprintf('%02d',i);
        labels{end+1} = [wav_name{1} '-' chan_num_str];
    end
end
    

dev = types.core.Device();
file.general_devices.set('dev1', dev);

eg = types.core.ElectrodeGroup(...
    'description', 'a test ElectrodeGroup', ...
    'location', 'unknown', ...
    'device', types.untyped.SoftLink('/general/devices/dev1'));
file.general_extracellular_ephys.set('electrode_group', eg);
ov = types.untyped.ObjectView('/general/extracellular_ephys/electrode_group');

variables = {'id', 'x', 'y', 'z', 'imp', 'location', 'filtering', ...
    'description', 'group', 'group_name'};
tbl = table(int64(1), NaN, NaN, NaN, NaN, {'location'}, {'filtering'}, ...
    labels(1), ov, {'electrode_group'},...
    'VariableNames', variables);
for i = 2:sum(elecs)
    tbl = [tbl; {int64(i), NaN, NaN, NaN, NaN, 'location', 'filtering', ...
        labels(i), ov, 'electrode_group'}];
end

et = types.core.ElectrodeTable('data', tbl);

file.general_extracellular_ephys.set('electrodes', et);