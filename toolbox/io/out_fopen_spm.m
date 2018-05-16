function sFileOut = out_fopen_spm(OutputFile, sFileIn, ChannelMat)
% OUT_FOPEN_SPM: Saves the header of a new empty SPM .mat/.dat file.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, 2017

% Check if SPM is in the path
if ~exist('file_array', 'file')
    error('SPM must be in the Matlab path to use this feature.');
end

% Get the two output file names: .mat and .dat
[fPath, fBase, fExt] = bst_fileparts(OutputFile);
MatFile = bst_fullfile(fPath, [fBase, '.mat']);
DatFile = bst_fullfile(fPath, [fBase, '.dat']);

% Create .mat structure
D.type      = 'continuous';
D.Nsamples  = sFileIn.prop.samples(2) - sFileIn.prop.samples(1) + 1;
D.Fsample   = sFileIn.prop.sfreq;
D.timeOnset = sFileIn.prop.times(1);
% Trials
D.trials.label  = 'Undefined';
D.trials.events = repmat(struct('type', [], 'time', [], 'value', [], 'offset', [], 'duration', []),0);
D.trials.onset  = sFileIn.prop.times(1);
D.trials.bad    = 0;
D.trials.tag    = [];
D.trials.repl   = 1;
% Events
for iEvt = 1:length(sFileIn.events)
    for iOcc = 1:size(sFileIn.events(iEvt).times,2)
        i = length(D.trials.events) + 1;
        D.trials.events(i).type  = sFileIn.events(iEvt).label;
        D.trials.events(i).time  = sFileIn.events(iEvt).times(1,iOcc);
        D.trials.events(i).value = iEvt;
        D.trials.events(i).offset = 0;
        if (size(sFileIn.events(iEvt).times,1) == 2)
            D.trials.events(i).duration = sFileIn.events(iEvt).times(1,iOcc) - sFileIn.events(iEvt).times(2,iOcc);
        else
            D.trials.events(i).duration = [];
        end
    end
end
% Channels
for i = 1:length(ChannelMat.Channel)
    D.channels(i).bad      = (sFileIn.channelflag(i) == -1);
    D.channels(i).label    = ChannelMat.Channel(i).Name;
    D.channels(i).type     = ChannelMat.Channel(i).Type;
    D.channels(i).X_plot2D = [];
    D.channels(i).Y_plot2D = [];
    D.channels(i).units    = 'm';
end
% Data
D.data = file_array(DatFile, [length(ChannelMat.Channel), D.Nsamples], 'float32-le');
% File name
D.fname = [fBase, '.mat'];
D.path = fPath;

% Get sensor types
iEeg = channel_find(ChannelMat.Channel, 'EEG, SEEG, ECOG, NIRS');
iMeg = channel_find(ChannelMat.Channel, 'MEG, MEG REG');
if ~isempty(iMeg)
    error(['MEG sensors are currently not supported by this function.' 10 ...
           'Please contact us through the Brainstorm user forum to request this feature.']);
end
% If all the channels have other types: consider it's all EEG
if isempty(iEeg) && isempty(iMeg)
    iEeg = 1:length(ChannelMat.Channel);
end
% Sensors
for i = 1:length(iEeg)
    if ~isempty(ChannelMat.Channel(iEeg(i)).Loc) && ~all(ChannelMat.Channel(iEeg(i)).Loc(:) == 0)
        D.sensors.eeg.chanpos(i,:) = ChannelMat.Channel(iEeg(i)).Loc(:,1)';
        D.sensors.eeg.elecpos(i,:) = ChannelMat.Channel(iEeg(i)).Loc(:,1)';
    else
        D.sensors.eeg.chanpos(i,:) = [NaN NaN NaN];
        D.sensors.eeg.elecpos(i,:) = [NaN NaN NaN];
    end
    D.sensors.eeg.chantype{i} = lower(ChannelMat.Channel(iEeg(i)).Type);
    D.sensors.eeg.chanunit{i} = 'V';
    D.sensors.eeg.label{i}    = ChannelMat.Channel(iEeg(i)).Name;
    D.sensors.eeg.type        = 'ctf';
    D.sensors.eeg.unit        = 'm';
    D.sensors.eeg.balance.current = 'none';
end
D.sensors.chantype = 'eeg';
% Rest of the structure
D.fiducials    = repmat(struct(), 0);
D.transform.ID = 'time';
D.condlist     = {};
D.montage.M    = [];
D.montage.Mind = 0;
D.history      = repmat(struct(), 0);
D.other        = repmat(struct(), 0);

% Save file
save(MatFile, 'D');

% Create a new header structure
sFileOut = sFileIn;
sFileOut.filename  = MatFile;
sFileOut.condition = '';
sFileOut.format    = 'SPM-DAT';
sFileOut.byteorder = 'l';
sFileOut.comment   = fBase;
% Force the destination compensation level
sFileOut.prop.currCtfComp = sFileOut.prop.destCtfComp;
sFileOut.header.ctfcomp   = sFileOut.prop.destCtfComp;
% Save pointer to the SPM file in the header
sFileOut.header.file_array = D.data;
sFileOut.header.nchannels  = length(ChannelMat.Channel);



