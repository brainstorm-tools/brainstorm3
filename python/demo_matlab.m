% DEMO_MATLAB: Examples of MATLAB-Python integration.
%
% FUNCTIONS:
%    - demo_matlab.py : Original Python example 
%    - demo_matlab.m  : Call demo_matlab.py from Matlab
%    - demo_matlab.m  : Reproduce demo_matlab.py with Matlab calls
% 
% REFERENCES
%    - Installation: https://neuroimage.usc.edu/brainstorm/MnePython
%    - Dataset: https://neuroimage.usc.edu/brainstorm/Tutorials/MedianNerveCtf
%
% AUTHORS:
%    - Python version: Mainak Jas <mainak.jas@telecom-paristech.fr>
%    - Matlab version: Francois Tadel, 2018-2020

% Initialize Brainstorm-Python
bst_python_init('Initialize', 1);

% Get test dataset
try
    data_path = py.mne.datasets.brainstorm.bst_raw.data_path();
catch
    disp([10 'MATLAB does not support the use of Python function input().' 10 ...
        'You must download the dataset manually from a Python terminal:' 10 ...
        '>>> import mne' 10 ...
        '>>> mne.datasets.brainstorm.bst_raw.data_path()' 10 10]);
end

% Read CTF dataset
raw_fname = fullfile(char(data_path), 'MEG', 'bst_raw', 'subj001_somatosensory_20111109_01_AUX-f.ds');
raw = py.mne.io.read_raw_ctf(raw_fname, pyargs('preload', true));
% Plot raw data
pyFig = raw.plot();
% Change the color of the first axes of the figure
pyAxes = pyFig.get_axes();
pyAxes{1}.set_facecolor({0,1,0});

% Set EOG channel
raw.set_channel_types(py.dict(pyargs('EEG058', 'eog')));
% Alternative syntax using the automatic conversion struct<=>dict
raw.set_channel_types(struct('EEG058', 'eog'));

% Show power line interference
raw.plot_psd();
% Notch filter: 60Hz
% raw.notch_filter(py.numpy.arange(60, 181, 60));

% Read events
events = py.mne.find_events(raw, pyargs('stim_channel', 'UPPT001'));
event_id = uint8(2);    % Right-hand somato

% Pick MEG channels
picks = py.mne.pick_types(raw.info, pyargs('meg', true, 'eeg', false, 'stim', false, 'eog', true, 'exclude', 'bads'));

% Compute epochs: [-100, +300]ms
epochs = py.mne.Epochs(raw, events, event_id, -0.1, 0.3, pyargs(... 
    'picks',     picks, ...
    'baseline',  py.tuple({py.None, 0}), ...
    'reject',    py.dict(pyargs('mag', 4e-12, 'eog', 250e-6)), ...
    'preload',   false));

% Compute evoked
evoked = epochs.average();

% Fix stim artifact
py.mne.preprocessing.fix_stim_artifact(evoked);

% Correct delays due to hardware (stim artifact is at 4 ms)
evoked.shift_time(-0.004);

% Plot the result
evoked.plot();
evoked.plot_topomap(pyargs('times', py.numpy.array({0.016, 0.030, 0.060, 0.070})));



