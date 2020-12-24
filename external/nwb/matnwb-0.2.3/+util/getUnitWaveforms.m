function waveforms = getUnitWaveforms(nwb, row, spike_number, units)
%GETUNITWAVEFORMS loads the individual waveform snippets for each spike in
%a Units table
%
%   WAVEFORMS = GETUNITWAVEFORMS(NWB, ROW) loads all waveforms for a ROW
%   (0-indexed) of the units table at /units of the NWB NWBFile.
%
%   WAVEFORMS = GETUNITWAVEFORMS(NWB, ROW, SPIKE_NUMBER) loads only a 
%   single waveform, which is the SPIKE_NUMBERth spike (1-indexed) for that unit
%
%   WAVEFROMS = GETUNITWAVEFORMS(NWB, ROW, SPIKE_NUMBER, UNITS) loads data
%   for another UNITS table.

if ~exist('units', 'var')
    units = nwb.units;
end

% test length of units table
units.id.data(row+1);

ses = units.electrode_group.data(row + 1).refresh(nwb).spike_event_series.deref(nwb);
us = ses.unit_series.deref(nwb);

if ~exist('spike_number', 'var') || isempty(spike_number)
    waveforms = ses.data(us.data == row , :, :);
else
    this_unit = find(us.data == row);
    waveforms = squeeze(ses.data(this_unit(spike_number), :, :));
end

