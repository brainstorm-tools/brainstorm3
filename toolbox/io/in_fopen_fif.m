function [sFile, ChannelMat] = in_fopen_fif(DataFile, ImportOptions)
% IN_FOPEN_FIF: Open a FIF file, and get all the data and channel information.
%
% USAGE:  [sFile, ChannelMat] = in_fopen_fif(DataFile, ImportOptions)
%         [sFile, ChannelMat] = in_fopen_fif(DataFile)
%
% INPUT: 
%     - ImportOptions : Structure that describes how to import the recordings. Fields directly used:
%       => Fields used: ChannelAlign, ChannelReplace, EventsMode, DisplayMessages

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2018

%% ===== PARSE INPUTS =====
if (nargin < 2) || isempty(ImportOptions)
    ImportOptions = db_template('ImportOptions');
end

%% ===== CHECK FILE TYPE =====
% Check if file is an event file
[fPath, fBase, fExt] = bst_fileparts(DataFile);
if ~strcmpi(fExt, '.fif')
    error(['File is not in FIF format: ' 10 '"' DataFile '"']);
elseif (length(fBase) > 4) && strcmpi(fBase(end-3:end), '-eve')
    % Event file => try to find the regular file
    DataFile = bst_fullfile(fPath, [fBase(1:end-4), fExt]);
    if ~file_exist(DataFile)
        error('You are trying to import an event file.');
    else
        warning(['Selected file was an event file. Now reading file:' 10 DataFile]); 
    end
end

%% ===== OPEN FIF FILE =====
% Open file
[ fid, tree ] = fiff_open(DataFile);
if (fid < 0)
    error(['Cannot open FIFF file : "' DataFile '"']);
end
% Read info structure
try
    [ info, meas ] = fiff_read_meas_info(fid, tree);
catch
    err = lasterror;
    disp([10 'BST> Error: Could not find measurement data: ' 10 err.message 10]);
    info.chs = [];
    info.dig = fif_read_headpoints(fid, tree);
    meas = [];
end

% Check if file was opened successfully
isNoData = ~isfield(info, 'sfreq');
if isNoData && isempty(info.chs) && isempty(info.dig)
    sFile = [];
    ChannelMat = [];
    fclose(fid);
    return
end

% Initialize file structure
sFile = db_template('sfile');
% Fill this structure
sFile.filename = DataFile;
sFile.format   = 'FIF';

% Part reserved to FIF files with recordings
if ~isNoData
    sFile.prop.sfreq  = double(info.sfreq);
end
% Header of the FIF file
sFile.header.tree = tree;
sFile.header.info = info;
sFile.header.meas = meas;

    
%% ===== READ CHANNEL FILE =====
% Read channel file from FIF and default coils file
[ChannelMat, Device] = in_channel_fif(sFile, ImportOptions);
% Get bad channels
ChannelFlag = ones(length(ChannelMat.Channel),1);
if isfield(info, 'bads') && ~isempty(info.bads)
    % For each bad channel (referenced by channel name): find its indice
    for iBad = 1:length(info.bads)
        iChan = find(strcmpi(info.bads(iBad), info.ch_names));
        ChannelFlag(iChan) = -1;
    end
end
% Find if results are already compensated
if ~isempty(ChannelMat.MegRefCoef)
    % Get current level of compensation
    iMeg = good_channel(ChannelMat.Channel, [], 'MEG');
    currentComp = bitshift(double([info.chs(iMeg).coil_type]), -16);
    % If not all the same value: error
    if ~all(currentComp == currentComp(1))
        error('CTF compensation is not set equally on all MEG channels');
    end
    % Current compensation order
    sFile.prop.currCtfComp = currentComp(1);
    % Destination compensation order (keep compensation order, unless it is 0)
    if (currentComp(1) == 0)
        sFile.prop.destCtfComp = 3;
    else
        sFile.prop.destCtfComp = currentComp(1);
    end
end

% Store results in sFile structure
sFile.device      = Device;
sFile.channelflag = ChannelFlag;
sFile.byteorder = 'b';
% Acquisition date (saved in POSIX format in FIF file)
sFile.acq_date = str_date(info.meas_date(1), 'posix');


%% ===== READ DATA DESCRIPTION =====
% Get number of epochs
[epochs, sFile.header.epochData] = fif_get_epochs(sFile, fid);
nEpochs = length(epochs);

% === CHANNELS ONLY ===
% No recordings in FIF file, only channels => Nothing to read
if isempty(meas)
    sFile.format = 'channels';
% === RAW FILE ===
elseif (nEpochs == 0)
    % Read RAW file information
    raw = fif_setup_raw(sFile, fid, 1);
    % Fill sFile structure   
    sFile.prop.times = double([raw.first_samp, raw.last_samp]) ./ sFile.prop.sfreq;
    sFile.header.raw = raw;
    % Read events information
    if iscell(ImportOptions.EventsMode) || ~strcmpi(ImportOptions.EventsMode, 'ignore')
        sFile.events = fif_read_events(sFile, ChannelMat, ImportOptions);
        % Operation cancelled by user
        if isequal(sFile.events, -1)
            sFile = [];
            fclose(fid);
            return;
        end
    end
% === EVOKED/EPOCHED FILE ===
else
    % Build epochs structure
    for i = 1:length(epochs)
        sFile.epochs(i).label   = epochs(i).label;
        sFile.epochs(i).times   = epochs(i).times;
        sFile.epochs(i).nAvg    = epochs(i).nAvg;
        sFile.epochs(i).select  = isempty(strfind(epochs(i).label, 'std err'));
        sFile.epochs(i).bad         = 0;
        sFile.epochs(i).channelflag = [];
    end
    % Extract global min/max for time and samples indices
    sFile.prop.times = [min([sFile.epochs.times]),   max([sFile.epochs.times])];
%     % Read events
%     [fifEvt, mappings] = fiff_read_events(fid,tree);
%     if ~isempty(fifEvt) && ~isempty(mappings)
%         % Initialize returned structure
%         uniqueEvt = unique(fifEvt(:,3)');
%         events = repmat(db_template('event'), [1, length(uniqueEvt)]);
%         % Parse event names
%         mappings = str_split(mappings, ';');
%         mappings = cellfun(@(c)str_split(c,':'), mappings, 'UniformOutput', 0);
%         if (length(mappings) >= 2)
%             mappings = reshape([mappings{:}], 2, [])';
%         else
%             mappings = [];
%         end
%         % Create events list
%         for iEvt = 1:length(uniqueEvt)
%             % Find all the occurrences of event #iEvt
%             iMrk = find(fifEvt(:,3) == uniqueEvt(iEvt));
%             % Event label
%             if ~isempty(mappings) && ismember(num2str(uniqueEvt(iEvt)), mappings(:,2))
%                 iMap = find(strcmpi(mappings(:,2), num2str(uniqueEvt(iEvt))));
%                 events(iEvt).label = mappings{iMap, 1};
%             else
%                 events(iEvt).label = num2str(uniqueEvt{iEvt});
%             end
%             % 
%             epochSmp = round((sFile.prop.times(2) - sFile.prop.times(1)) .* sFile.prop.sfreq);
%             samples = double(fifEvt(iMrk,1))';
%             events(iEvt).epochs     = floor(samples ./ epochSmp) + 1;
%             events(iEvt).times      = mod(samples, epochSmp) ./ sFile.prop.sfreq + sFile.prop.times(1);
%             events(iEvt).reactTimes = [];
%             events(iEvt).select     = 1;
%             events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
%             events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
%         end
%         sFile.events = events;
%     end
end

% Close file
if ~isempty(fopen(fid))
    fclose(fid);
end


