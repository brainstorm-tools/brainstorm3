function [sFile, ChannelMat] = in_fopen_mne(pyObj, ImportOptions)
% IN_FOPEN_MNE: Open a MNE-Python data structure (objects Raw, Epoched or Evoked).
%
% USAGE:  [sFile, ChannelMat] = in_fopen_mne(pyObj, ImportOptions)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2019

% Parse inputs
if (nargin < 2) || isempty(ImportOptions)
    ImportOptions = db_template('ImportOptions');
end

% Check Python object type
pyModules = py.sys.modules;
if ~py.isinstance(pyObj, pyModules{'mne.io'}.BaseRaw)
    error(['Unsupported class: ' class(pyObj)]);
end

% Initialize file structure
sFile = db_template('sfile');
% Fill this structure
sFile.filename = pyObj;
sFile.format   = 'MNE-PYTHON';
sFile.comment  = bst_py2mat(pyObj.info{'description'});
sFile.prop.sfreq = bst_py2mat(pyObj.info{'sfreq'});
sFile.prop.times = [bst_py2mat(pyObj.first_samp), bst_py2mat(pyObj.last_samp)] ./ sFile.prop.sfreq;
% Acquisition date
meas_date = bst_py2mat(pyObj.info{'meas_date'});
if ~isempty(meas_date)
    sFile.acq_date = str_date(meas_date, 'posix');
end


%% ===== EVENTS =====
disp('TODO: Read info{''events''}');
% Annotations
evtOnset = bst_py2mat(pyObj.annotations.onset);
if ~isempty(evtOnset)
    evtDuration = double(pyObj.annotations.duration);
    evtLabel = cellfun(@(c)char(c), cell(py.list(pyObj.annotations.description)), 'UniformOutput', false);
    % Group by label
    uniqueEvt = unique(evtLabel);
    events = repmat(db_template('event'), [1, length(uniqueEvt)]);
    % Create events list
    for iEvt = 1:length(uniqueEvt)
        % Find all the occurrences of event #iEvt
        iMrk = find(ismember(evtLabel, uniqueEvt{iEvt}));
        % Simple/extended events
        if any(evtDuration(iMrk) ~= 0)
            evtTime = [evtOnset(iMrk); evtOnset(iMrk) + evtDuration(iMrk)];
        else
            evtTime = evtOnset(iMrk);
        end
        % Round to the closest time sample
        evtTime = round(evtTime .* sFile.prop.sfreq) ./ sFile.prop.sfreq;
        % Fill events structure
        events(iEvt).label      = uniqueEvt{iEvt};
        events(iEvt).epochs     = ones(1, length(iMrk));
        events(iEvt).times      = evtTime;
        events(iEvt).reactTimes = [];
        events(iEvt).select     = 1;
        events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
        events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
    end
    sFile.events = events;
end


%% ===== EPOCHS =====
disp('TODO: Read epochs');
%          epochs: [0×0 struct]


%% ===== CHANNEL FILE =====
% Initialize returned structure
[ChannelMat, Device, currentComp] = in_channel_mne(pyObj, ImportOptions);
% Channel flag
nChannels = length(pyObj.info{'ch_names'});
sFile.channelflag = ones(nChannels, 1);
for iBad = 1:length(pyObj.info{'bads'})
    try
        iChan = double(pyObj.info{'ch_names'}.index(pyObj.info{'bads'}{iBad}));
        sFile.channelflag(iChan + 1) = -1;
    catch
    end
end
sFile.device = Device;
    
% Find if results are already compensated
if ~isempty(ChannelMat.MegRefCoef) && ~isempty(currentComp)
    % Current compensation order
    sFile.prop.currCtfComp = currentComp;
    % Destination compensation order (keep compensation order, unless it is 0)
    if (currentComp == 0)
        sFile.prop.destCtfComp = 3;
    else
        sFile.prop.destCtfComp = currentComp;
    end
end



