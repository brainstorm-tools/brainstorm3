# demo_python.py
""" Examples of MATLAB-Python integration.
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
"""

import numpy as np
import mne
from mne.datasets.brainstorm import bst_raw

def test():
    """Running the analysis of the Brainstorm tutorial in MNE-Python"""
    print(__doc__)

    # Get test dataset
    data_path = bst_raw.data_path()

    # Read CTF dataset
    raw_fname = bst_raw.data_path() + '/MEG/bst_raw/' + 'subj001_somatosensory_20111109_01_AUX-f.ds'
    raw = mne.io.read_raw_ctf(raw_fname, preload=True)
    # Plot raw data
    raw.plot()

    # Set EOG channel
    raw.set_channel_types({'EEG058': 'eog'})

    # Show power line interference
    raw.plot_psd()
    # Notch filter: 60Hz
    # raw.notch_filter(np.arange(60, 181, 60))

    # Read events
    events = mne.find_events(raw, stim_channel='UPPT001')
    event_id = 2  # take right-hand somato

    # Pick MEG channels
    picks = mne.pick_types(raw.info, meg=True, eeg=False, stim=False, eog=True, exclude='bads')

    # Compute epochs: [-100, +300]ms
    epochs = mne.Epochs(raw, events, event_id, -0.1, 0.3, 
        picks=picks,
        baseline=(None, 0),
        reject=dict(mag=4e-12, eog=250e-6), 
        preload=False)

    # Compute evoked
    evoked = epochs.average()

    # Fix stim artifact
    mne.preprocessing.fix_stim_artifact(evoked)

    # Correct delays due to hardware (stim artifact is at 4 ms)
    evoked.shift_time(-0.004)

    # Plot the result
    evoked.plot()
    evoked.plot_topomap(times=np.array([0.016, 0.030, 0.060, 0.070]))


