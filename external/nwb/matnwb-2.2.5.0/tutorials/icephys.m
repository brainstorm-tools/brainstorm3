%% Neurodata Without Borders: Neurophysiology (NWB:N), Intracellular Electrophysiology Tutorial
% How to write intracellular ephys data to an NWB file using matnwb.
% 
%  author: Ben Dichter
%  contact: ben.dichter@lbl.gov
%  last edited: May 6, 2019

%% NWB file
% All contents get added to the NWB file, which is created with the
% following command

session_start_time = datetime(2018, 3, 1, 12, 0, 0,'TimeZone', 'local');

nwb = NwbFile( ...
    'session_description', 'a test NWB File', ...
    'identifier', 'mouse004_day4', ...
    'session_start_time', session_start_time);

%%
% You can check the contents by displaying the NwbFile object
disp(nwb);

%% Subject
% Subject-specific information goes in type |Subject| in location 
% |general_subject|.

nwb.general_subject = types.core.Subject( ...
    'description', 'mouse 5', 'age', '9 months', ...
    'sex', 'M', 'species', 'Mus musculus');

%% Recording Meta-data

device_name = 'device name here';
ic_elec_name = 'ic_elec';

nwb.general_devices.set(device_name, types.core.Device());
device_link = types.untyped.SoftLink(['/general/devices/' device_name]);

ic_elec = types.core.IntracellularElectrode( ...
    'device', device_link, ...
    'description', 'my description');

nwb.general_intracellular_ephys.set(ic_elec_name, ic_elec);
ic_elec_link = types.untyped.SoftLink(['/general/intracellular_ephys/' ic_elec_name]);

%% Stimulus
% Intracellular stimulus and response data are represented with subclasses 
% of PatchClampSeries. There are two classes for representing stimulus 
% data: VoltageClampStimulusSeries and CurrentClampStimulusSeries. They
% have similar syntax.

data = ones(1,100);
timestamps = linspace(0,1,100);
description = 'description here';
stimulus_name = 'voltage_stimulus';

nwb.stimulus_presentation.set(stimulus_name, ...
    types.core.CurrentClampStimulusSeries( ...
        'electrode', ic_elec_link, ...
        'gain', NaN, ...
        'stimulus_description', description, ...
        'data_unit', 'mA', ...
        'data', data, ...
        'timestamps', timestamps));

%% Response
% There are three classes for representing response data: VoltageClampSeries, 
% VoltageClampSeries, CurrentClampSeries, and IZeroClampSeries. They all
% have similar syntax.

data = ones(1,100) * 2;
response_name = 'response_name_here';

nwb.acquisition.set(response_name, ...
    types.core.CurrentClampSeries( ...
        'bias_current', [], ... % Unit: Amp
        'bridge_balance', [], ... % Unit: Ohm
        'capacitance_compensation', [], ... % Unit: Farad
        'timestamps', timestamps, ... % seconds
        'data', data, ...
        'data_unit', 'V', ...
        'electrode', ic_elec_link, ...
        'stimulus_description', 'description of stimulus'));        

%% Write

nwbExport(nwb, 'test_icephys_out.nwb');

%% Read

nwb_in = nwbRead('test_icephys_out.nwb');

mem_pot_1 = nwb_in.acquisition.get('response_name_here');

mem_pot_1.data.load
