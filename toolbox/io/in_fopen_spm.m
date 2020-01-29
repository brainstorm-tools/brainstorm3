function [sFile, ChannelMat] = in_fopen_spm(DataFile)
% IN_FOPEN_SPM: Open a SPM .mat/.dat file.

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
sFile.prop.times   = (round(D.timeOnset(1) .* sFile.prop.sfreq) + [0, (D.Nsamples - 1)]) ./ sFile.prop.sfreq;
sFile.channelflag  = ones(nChannels,1);
sFile.device       = 'SPM';
sFile.comment      = fBase;
if isa(D.data, 'file_array')
    sFile.header.file_array = D.data;
elseif isstruct(D.data) && isfield(D.data, 'y') && isa(D.data.y, 'file_array')
    sFile.header.file_array = D.data.y;
else
    error('Could not find the file_array object in the SPM structure.');
end
sFile.header.nChannels  = nChannels;
sFile.header.gain       = ones(nChannels,1);


%% ===== CHANNEL FILE =====
% Initialize structure
ChannelMat = db_template('ChannelMat');
ChannelMat.Comment = [sFile.device ' channels'];
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels]);
% Loop on each channel
for i = 1:nChannels
    if (D.channels(i).bad)
        sFile.channelflag(i) = -1;
    end
    if iscell(D.channels(i).label) && ~isempty(D.channels(i).label)
        ChannelMat.Channel(i).Name = D.channels(i).label{1};
    elseif ischar(D.channels(i).label) && ~isempty(D.channels(i).label)
        ChannelMat.Channel(i).Name = D.channels(i).label;
    else
        disp(sprintf('BST> Warning: No information avaible for channel #%d.', i));
    end
    % Convert channel types
    switch upper(D.channels(i).type)
        case 'MEGPLANAR',   ChannelMat.Channel(i).Type = 'MEG GRAD';
        case 'MEGMAG',      ChannelMat.Channel(i).Type = 'MEG MAG';
        otherwise,          ChannelMat.Channel(i).Type = upper(D.channels(i).type);
    end
    % Channel gains
    if isfield(D.channels(i), 'units') && ~isempty(D.channels(i).units)
        switch (D.channels(i).units)
            case 'fT',        sFile.header.gain(i) = 1e-15;
            case 'fT/mm',     sFile.header.gain(i) = 1e-12;
            case 'mV',        sFile.header.gain(i) = 1e-3;
            case {'uV','?V'}, sFile.header.gain(i) = 1e-6;
            otherwise,        sFile.header.gain(i) = 1;
        end
    end
end
% Read detailed information from .meg and .eeg fields
ChannelMat = read_fieldtrip_chaninfo(ChannelMat, D.sensors);

% Convert head points
if isfield(D, 'fiducials') && isfield(D.fiducials, 'pnt') && isfield(D.fiducials, 'label')
    for i = 1:length(D.fiducials.label)
        ChannelMat.HeadPoints.Label = D.fiducials.label(:)';
        ChannelMat.HeadPoints.Type  = repmat({'EXTRA'}, size(ChannelMat.HeadPoints.Label));
        ChannelMat.HeadPoints.Loc   = scale_unit(D.fiducials.pnt', D.fiducials.unit);
    end
end
% Convert fiducials
if isfield(D, 'fiducials') && isfield(D.fiducials, 'fid') && isfield(D.fiducials.fid, 'label') && isfield(D.fiducials.fid, 'pnt')
    for i = 1:length(D.fiducials.fid.label)
        switch lower(D.fiducials.fid.label{i})
            case {'nas', 'nasion', 'nz', 'fidnas', 'fidnz'}  % NASION
                ChannelMat.SCS.NAS = scale_unit(D.fiducials.fid.pnt(i,:), D.fiducials.unit);
            case {'lpa', 'pal', 'og', 'left', 'fidt9', 'leftear'} % LEFT EAR
                ChannelMat.SCS.LPA = scale_unit(D.fiducials.fid.pnt(i,:), D.fiducials.unit);
            case {'rpa', 'par', 'od', 'right', 'fidt10', 'rightear'} % RIGHT EAR
                ChannelMat.SCS.RPA = scale_unit(D.fiducials.fid.pnt(i,:), D.fiducials.unit);
        end
    end
    % Force re-alignment on the new set of NAS/LPA/RPA
    if ~isempty(ChannelMat.SCS) && ~isempty(ChannelMat.SCS.NAS) && ~isempty(ChannelMat.SCS.LPA) && ~isempty(ChannelMat.SCS.RPA)
        ChannelMat = channel_detect_type(ChannelMat, 1, 0);
    end
end


%% ===== EVENTS =====
if isfield(D, 'trials') && isfield(D.trials, 'events') && isfield(D.trials.events, 'type')
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
        sFile.events(iEvt).epochs  = 1 + 0*t(1,:);
        sFile.events(iEvt).select  = 1;
        sFile.events(iEvt).channels = cell(1, size(sFile.events(iEvt).times, 2));
        sFile.events(iEvt).notes    = cell(1, size(sFile.events(iEvt).times, 2));
    end
end

end



%% ===== HELPER FUNCTIONS =====
function pt = scale_unit(pt, unit)
    if isequal(unit, 'cm')
        pt = pt ./ 100;
    elseif isequal(unit, 'mm')
        pt = pt ./ 1000;
    end
end

