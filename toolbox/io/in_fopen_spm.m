function [sFile, ChannelMat] = in_fopen_spm(DataFile)
% IN_FOPEN_SPM: Open a SPM .mat/.dat file.

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
        

%% ===== READ HEADER =====
% Check if SPM is in the path
if ~exist('file_array', 'file')
    error('SPM must be in the Matlab path to use this feature.');
end
% Get the two input file names: .mat and .dat
[fPath, fBase, fExt] = bst_fileparts(DataFile);
MatFile = bst_fullfile(fPath, [fBase, '.mat']);
DatFile = bst_fullfile(fPath, [fBase, '.dat']);
% If one is missing: error
if ~file_exist(MatFile) || ~file_exist(DatFile)
    error('The two files .dat and .mat must be available in the same folder.');
end
% Read header
sMat = load(MatFile, 'D');
D = sMat.D;
nChannels = length(D.channels);

% Warning: Supporting only files with one epoch
if (length(D.trials) > 1)
    error(['Only continuous SPM files are currently supported. Files with multiple trials cannot be imported.' 10 ...
           'Please contact us through the Brainstorm user forum to request this feature.']);
end


%% ===== FILL STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder    = 'l';
sFile.filename     = MatFile;
sFile.format       = 'SPM-DAT';
sFile.prop.sfreq   = double(D.Fsample);
sFile.prop.nAvg    = 1;
sFile.prop.samples = round(D.timeOnset(1) .* sFile.prop.sfreq) + [0, (D.Nsamples - 1)];
sFile.prop.times   = sFile.prop.samples ./ sFile.prop.sfreq;
sFile.channelflag  = ones(nChannels,1);
sFile.device       = 'SPM';
sFile.comment      = fBase;
sFile.channelflag  = zeros(nChannels,1);
sFile.header.file_array = D.data;
sFile.header.nChannels  = nChannels;



%% ===== CHANNEL FILE =====
% Initialize structure
ChannelMat = db_template('ChannelMat');
ChannelMat.Comment = [sFile.device ' channels'];
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels]);
% Loop on each channel
for i = 1:nChannels
    sFile.channelflag(i) = D.channels(i).bad;
    ChannelMat.Channel(i).Name = D.channels(i).label{1};
    ChannelMat.Channel(i).Type = upper(D.channels(i).type);
    % Check if more details are available
    if isfield(D, 'sensors') && isfield(D.sensors, 'eeg') && isfield(D.sensors.eeg, 'label')
        % Look for sensor name
        iSens = find(strcmpi(ChannelMat.Channel(i).Name, D.sensors.eeg.label));
        if ~isempty(iSens)
            % 3D position
            if ~any(isnan(D.sensors.eeg.elecpos(i,:))) && ~any(isinf(D.sensors.eeg.elecpos(i,:))) && ~all(D.sensors.eeg.elecpos(i,:) == 0)
                ChannelMat.Channel(iEeg(i)).Loc(:,1) = D.sensors.eeg.elecpos(i,:);
            end
            % Sensor type
            ChannelMat.Channel(i).Type = upper(D.channels(i).type);
        end
    end
end


%% ===== EVENTS =====
% Get all the event types
evtList = {D.trials.events.type};
% Events list
[uniqueEvt, iUnique] = unique(evtList);
uniqueEvt = evtList(sort(iUnique));
% Initialize events list
sFile.events = repmat(db_template('event'), 1, length(uniqueEvt));
% Build events list
for iEvt = 1:length(uniqueEvt)
    % Find all the occurrences of this event
    iOcc = find(strcmpi(uniqueEvt{iEvt}, evtList));
    % Concatenate all times
    t = [D.trials.events(iOcc).time];
    % If there is a duration: add it
    occDuration = [D.trials.events(iOcc).duration];
    if (length(occDuration) == length(t))
        t(2,:) = t(1,:) + occDuration;
    end
    % Set event
    sFile.events(iEvt).label   = strtrim(uniqueEvt{iEvt});
    sFile.events(iEvt).times   = t;
    sFile.events(iEvt).samples = round(t .* sFile.prop.sfreq);
    sFile.events(iEvt).epochs  = 1 + 0*t(1,:);
    sFile.events(iEvt).select  = 1;
end





