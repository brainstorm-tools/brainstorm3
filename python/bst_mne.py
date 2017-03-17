# bst_mne.py
"""Testing Matlab capabilities to call MNE-Python"""

import numpy as np
import mne
from mne.datasets.brainstorm import bst_raw

def test():
    """Running the analysis of the Brainstorm tutorial in MNE-Python"""
    print(__doc__)

    tmin, tmax, event_id = -0.1, 0.3, 2  # take right-hand somato
    reject = dict(mag=4e-12, eog=250e-6)

    data_path = bst_raw.data_path()

    raw_fname = data_path + '/MEG/bst_raw/' + 'subj001_somatosensory_20111109_01_AUX-f_raw.fif'
    raw = mne.io.read_raw_fif(raw_fname, preload=True, add_eeg_ref=False)
    raw.plot()

    return raw

    """
    # set EOG channel
    raw.set_channel_types({'EEG058': 'eog'})
    raw.add_eeg_average_proj()

    # show power line interference and remove it
    raw.plot_psd()
    raw.notch_filter(np.arange(60, 181, 60))

    events = mne.find_events(raw, stim_channel='UPPT001')

    # pick MEG channels
    picks = mne.pick_types(raw.info, meg=True, eeg=False, stim=False, eog=True,
                           exclude='bads')

    # Compute epochs
    epochs = mne.Epochs(raw, events, event_id, tmin, tmax, picks=picks,
                        baseline=(None, 0), reject=reject, preload=False)

    # compute evoked
    evoked = epochs.average()

    # remove physiological artifacts (eyeblinks, heartbeats) using SSP on baseline
    evoked.add_proj(mne.compute_proj_evoked(evoked.copy().crop(tmax=0)))
    evoked.apply_proj()

    # fix stim artifact
    mne.preprocessing.fix_stim_artifact(evoked)

    # correct delays due to hardware (stim artifact is at 4 ms)
    evoked.shift_time(-0.004)

    # plot the result
    evoked.plot()

    # show topomaps
    evoked.plot_topomap(times=np.array([0.016, 0.030, 0.060, 0.070]))
    """

def search(words):
    """Return list of words containing 'o'"""
    newlist = [w for w in words if 'o' in w]
    return newlist

def theend(words):
    """Append 'The End' to list of words"""
    words.append('The End')
    return words

