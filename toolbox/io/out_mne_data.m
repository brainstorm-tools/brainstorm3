function [mneObj, DataMat, ChannelMat, iChannels] = out_mne_data(DataFiles, ObjType, ChannelFile, SensorTypes)
% OUT_MNE_DATA: Converts a data file or a set of data files into a MNE-Python object (Raw, Epoched or Evoked)
% 
% USAGE:  [mneObj, DataMat, ChannelMat, iChannels] = out_mne_data( DataFiles, ObjType, ChannelFile=[], SensorTypes/iChannels=[]);
%         [mneObj, DataMat, ChannelMat, iChannels] = out_mne_data( DataMat,   ObjType, ChannelMat=[],  SensorTypes/iChannels=[]);
%
% INPUTS:
%    - DataFiles    : String or cell-array of strings, relative path(s) to data file(s) available in the database
%    - DataMat      : Brainstorm data file structure (if multiple files, the F matrix matrix must be [nEpochs, nChans, nTime])
%    - ObjType      : Class of the returned MNE-Python object {'Raw', 'Epoched', 'Evoked'}
%    - ChannelFile  : Relative path to a channel file available in the database (if not provided: look for it based on the DataFile)
%    - ChannelMat   : Brainstorm channel file structure
%    - iChannels    : Vector of selected channel indices
%    - SensorTypes  : Names or types of channels, separated with commas

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
% Authors: Francois Tadel, 2019-2020


%% ===== PARSE INPUTS =====
if (nargin < 4) || isempty(SensorTypes)
    SensorTypes = [];
end
if (nargin < 3) || isempty(ChannelFile)
    ChannelMat  = [];
    ChannelFile = [];
elseif isstruct(ChannelFile)
    ChannelMat   = ChannelFile;
    ChannelFile = [];
else
    ChannelMat = [];
end
if isempty(DataFiles)
    error('No input data files.');
elseif ischar(DataFiles)
    DataFiles = {DataFiles};
    DataMat = [];
elseif isstruct(DataFiles)
    DataMat = DataFiles;
    DataFiles = [];
end
% Only 'Epoched' objects can have multiple data files in input
if (length(DataFiles) > 1) && ~strcmpi(ObjType, 'Epoched')
    error('Only "Epoched" objects accept multiple input files.');
end
% Check that data files are available in the database
if ~isempty(DataFiles)
    sStudy = bst_get('DataFile', DataFiles{1});
    if isempty(sStudy)
        error(['File not found: ' DataFiles{1}]);
    end
    % Get study date
    MeasDate = sStudy.DateOfStudy;
else
    MeasDate = [];
end


%% ===== LOAD CHANNEL FILE =====
% Get ChannelFile if not provided
if isempty(ChannelFile) && isempty(ChannelMat)
    if ~isempty(DataFiles)
        ChannelFile = bst_get('ChannelFileForStudy', DataFiles{1});
    else
        error('Missing ChannelMat or ChannelFile in input.');
    end
end
% Load channel file
if ~isempty(ChannelFile) && isempty(ChannelMat)
    ChannelMat = in_bst_channel(ChannelFile);
end
% Make sure that the channel file is defined
if isempty(ChannelMat)
    error('No channel file available for the input files.');
end
% Find sensors by names/types
if ~isempty(SensorTypes)
    if ischar(SensorTypes)
        iChannels = channel_find(ChannelMat.Channel, SensorTypes);
        if isempty(iChannels)
            error(['Channels not found: ' SensorTypes]);
        end
    elseif isnumeric(SensorTypes)
        iChannels = SensorTypes;
    else
        error('Invalid input type for parameter "SensorTypes".');
    end
% Default channel selection: all
else
    iChannels = 1:length(ChannelMat.Channel);
end


%% ===== LOAD DATA =====
% Load data file
if ~isempty(DataFiles)
    epochsComment = cell(1,length(DataFiles));
    % Loop on input files
    for iFile = 1:length(DataFiles)
        % Load .mat files
        tmpData = in_bst_data(DataFiles{iFile});
        % Raw files: Read entire recordings
        if isstruct(tmpData.F)
            sFile = tmpData.F;
            RemoveBaseline = 'no';
            UseSsp = 1;
            [tmpData.F, tmpData.Time] = panel_record('ReadRawBlock', sFile, ChannelMat, 1, tmpData.Time([1 end]), 0, 1, RemoveBaseline, UseSsp, iChannels);
            tmpData.Events = sFile.events;
            % Get date
            if isfield(sFile, 'acq_date') && ~isempty(sFile.acq_date)
                MeasDate = sFile.acq_date;
            end
        % Imported data: Keep only selected 
        else
            tmpData.F = tmpData.F(iChannels,:);
        end
        tmpData.ChannelFlag = tmpData.ChannelFlag(iChannels);
        % Concatenate all data in the same structure (F = [nEpoch x nChan x nTime])
        if strcmpi(ObjType, 'Epoched')
            tmpData.F = reshape(tmpData.F, 1, size(tmpData.F,1), size(tmpData.F,2));
            if (iFile == 1)
                DataMat = tmpData;
            else
                if ~isequal(size(DataMat.F(1,:,:)), size(tmpData.F))
                    error('All input data must have the same dimensions.');
                end
                DataMat.F = cat(1, DataMat.F, tmpData.F);
                DataMat.ChannelFlag(tmpData.ChannelFlag ~= 1) = -1;
            end
            epochsComment{iFile} = str_remove_parenth(tmpData.Comment, '(');
            epochsComment{iFile} = str_remove_parenth(epochsComment{iFile}, '[');
        else
            DataMat = tmpData;
        end
    end
% Data structures passed in input
else
    % No epochs classification
    epochsComment = [];
    % Select data channels
    DataMat.F = DataMat.F(iChannels,:);
    DataMat.ChannelFlag = DataMat.ChannelFlag(iChannels);
end


%% ===== CREATE INFO OBJECT =====
% Create info object
mneInfo = out_mne_channel(ChannelFile, iChannels);
% Sampling frequency
mneInfo{'sfreq'} = 1 ./ (DataMat.Time(2) - DataMat.Time(1));
% Description
mneInfo{'description'} = DataMat.Comment;
% Bad channels
iBad = find(DataMat.ChannelFlag == -1);
if ~isempty(iBad)
    mneInfo{'bads'} = {ChannelMat.Channel(iBad).Name};
end
% Mark projectors as applied (data loaded with UseSSP=1)
for iProj = 1:length(mneInfo{'projs'})
    mneInfo{'projs'}{iProj}{'active'} = py.bool(true);
end
% Measurement date
if ~isempty(MeasDate)
    try
        % Read date string to a py.datetime object
        dt = py.dateutil.parser.parse(MeasDate);
        % Convert to UTC
        tz = py.datetime.datetime.now().astimezone().tzinfo;
        dt = dt.replace(pyargs('tzinfo', tz));
        dt = dt.astimezone(py.datetime.timezone(py.datetime.timedelta(0)));
        mneInfo{'meas_date'} = dt;
    catch
    end
end

% Object: Raw
switch ObjType
    % RAW:  https://www.nmr.mgh.harvard.edu/mne/stable/generated/mne.io.Raw.html
    case 'Raw'
        % Create Raw object
        first_samp = round(DataMat.Time(1) .* mneInfo{'sfreq'});
        mneObj = py.mne.io.RawArray(bst_mat2py(DataMat.F), mneInfo, first_samp);
        
        % Add events
        for iEvt = 1:length(DataMat.Events)
            % No occurrences: skip
            if isempty(DataMat.Events(iEvt).times)
                continue;
            end
            % Get onsets
            annotOnset = DataMat.Events(iEvt).times(1,:);
            % Extended events / simple events
            if (size(DataMat.Events(iEvt).times,1) == 2)
                annotDuration = DataMat.Events(iEvt).times(2,:) - DataMat.Events(iEvt).times(1,:);
            else
                annotDuration = 0 .* annotOnset;
            end
            % Add annotations to MNE objet
            mneObj.annotations.append(annotOnset, annotDuration, repmat({DataMat.Events(iEvt).label}, 1, size(annotOnset,2)));
        end
        
    case 'Epoched'
        % Sort trials by type, based on the comment of the files
        events = uint32([(1:size(DataMat.F, 1))', repmat([0, 1], size(DataMat.F, 1), 1)]);
        event_id = py.dict();
        if ~isempty(epochsComment)
            uniqueTypes = unique(epochsComment);
            for iType = 1:length(uniqueTypes)
                events(strcmpi(epochsComment, uniqueTypes{iType}), 3) = iType;
                event_id{uniqueTypes{iType}} = uint32(iType);
            end
        end
        % Create Epoched object from concatenated trials
%         mneObj = py.mne.EpochsArray(bst_mat2py(DataMat.F), mneInfo, bst_mat2py(events), DataMat.Time(1), event_id);
        mneObj = py.mne.EpochsArray(DataMat.F, mneInfo, bst_mat2py(events), DataMat.Time(1), event_id);
        
    case 'Evoked'
        % Create Evoked object
%         mneObj = py.mne.EvokedArray(bst_mat2py(DataMat.F), mneInfo, DataMat.Time(1), DataMat.Comment, uint32(DataMat.nAvg));
        mneObj = py.mne.EvokedArray(DataMat.F, mneInfo, DataMat.Time(1), DataMat.Comment, uint32(DataMat.nAvg));
end



