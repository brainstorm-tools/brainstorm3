function plot_brainstorm_data()
% ============================
% Brainstorm tutorial datasets
% ============================
% 
% Here we compute the evoked from raw for the Brainstorm
% tutorial dataset. For comparison, see [1]_ and:
% 
%     http://neuroimage.usc.edu/brainstorm/Tutorials/MedianNerveCtf
% 
% References
% ----------
% .. [1] Tadel F, Baillet S, Mosher JC, Pantazis D, Leahy RM.
%        Brainstorm: A User-Friendly Application for MEG/EEG Analysis.
%        Computational Intelligence and Neuroscience, vol. 2011, Article ID
%        879716, 13 pages, 2011. doi:10.1155/2011/879716
%
% Authors: Mainak Jas <mainak.jas@telecom-paristech.fr>
%          Francois Tadel, for the conversion to Matlab 
% 
% License: BSD (3-clause)


% To append the MNE folder to your Python path
% MNE_PATH = 'C:\Work\Dev\Python\mne';
% pyPathContains = py.getattr(py.sys.path(), '__contains__');
% if ~pyPathContains(MNE_PATH)
%     py.sys.path().append(MNE_PATH)
% end

% The syntax below cannot be converted to Matlab: impossible to get the heading comment of this script
% py.print(py.mne.__doc__)

tmin     = -0.1;
tmax     = 0.3;
event_id = uint8(2);  % take right-hand somato
reject = py.dict(pyargs('mag', 4e-12, 'eog', 250e-6));

% Open .fif file
data_path = py.mne.datasets.brainstorm.bst_raw.data_path();
raw_fname = fullfile(char(data_path), 'MEG', 'bst_raw', 'subj001_somatosensory_20111109_01_AUX-f_raw.fif');
raw = py.mne.io.read_raw_fif(raw_fname, pyargs('preload', true, 'add_eeg_ref', false));

% Open mne_browse_raw
pyFig = raw.plot();
% Just for fun: change the color of the first axes of the figure
pyAxes = pyFig.get_axes();
pyAxes{1}.set_axis_bgcolor({0,1,0});

% Set EOG channel
raw.set_channel_types(py.dict(pyargs('EEG058', 'eog')));
% Alternative syntax using the automatic conversion struct<=>dict
raw.set_channel_types(struct('EEG058', 'eog'));

raw.add_eeg_average_proj();
 
% Show power line interference
raw.plot_psd();
% Notch filter: 60Hz
% raw.notch_filter(py.numpy.arange(60, 181, 60));

events = py.mne.find_events(raw, pyargs('stim_channel', 'UPPT001'));

% Pick MEG channels
picks = py.mne.pick_types(raw.info, pyargs('meg', true, 'eeg', false, 'stim', false, 'eog', true, 'exclude', 'bads'));

% Compute epochs
epochs = py.mne.Epochs(raw, events, event_id, tmin, tmax, ...
                       pyargs('picks', picks, 'baseline', py.tuple({py.None, 0}), 'reject', reject, 'preload', false));

% Compute evoked
evoked = epochs.average();

% Remove physiological artifacts (eyeblinks, heartbeats) using SSP on baseline
evoked.add_proj(py.mne.compute_proj_evoked(evoked.copy().crop(pyargs('tmax',0))));
evoked.apply_proj();

% Fix stim artifact
py.mne.preprocessing.fix_stim_artifact(evoked);

% Correct delays due to hardware (stim artifact is at 4 ms)
evoked.shift_time(-0.004);

% Plot the result
evoked.plot();

% Show topomaps
evoked.plot_topomap(pyargs('times', py.numpy.array({0.016, 0.030, 0.060, 0.070})));



