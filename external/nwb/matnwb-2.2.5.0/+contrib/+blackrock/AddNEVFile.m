function file = AddNEVFile(file, nev, starting_time)


if ~exist('starting_time', 'var') || isempty(starting_time)
    starting_time = 0.0;
end

if ischar(nev)
    spikes_data = openNEV(nev);
else
    spikes_data = nev;
end

Spikes = spikes_data.Data.Spikes;

elecs = Spikes.Electrode;
times = double(Spikes.TimeStamp + starting_time)

nelecs = length(unique(elecs))

nwb.units = types.core.Units( ...
    'colnames', {'spike_times',}, ...
    'description', 'units table', ...
    'id', types.core.ElementIdentifiers('data', int64(0:nelecs - 1)));

[spike_times_vector, spike_times_index] = util.create_indexed_column( ...
    times, elecs, '/units/spike_times');
nwb.units.spike_times = spike_times_vector;
nwb.units.spike_times_index = spike_times_index;