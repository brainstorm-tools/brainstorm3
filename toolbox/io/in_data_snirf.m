function  [DataMat, ChannelMat] = in_data_snirf(DataFile)
% IN_FOPEN_SNIRF Open a fNIRS file based on the SNIRF format
%
% DESCRIPTION:
%     This function is based on the SNIRF specification v.1.1
%     https://github.com/fNIRS/snirf
%
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
% Authors: Edouard Delaire, Francois Tadel, 2020 - 2025

% Install/load JSNIRF Toolbox (https://github.com/NeuroJSON/jsnirfy) as plugin
if ~exist('loadsnirf', 'file')
    [isInstalled, errMsg] = bst_plugin('Install', 'jsnirfy');
    if ~isInstalled
        error(errMsg);
    end
end


% Load file
jnirs = loadjsnirf(DataFile);

% Detect and fix common error
jnirs = detectAndFixError(jnirs);

%% ===== CHANNEL FILE ====

% Get length scaling units
lenght_scale = bst_units_ui(toLine(jnirs.nirs.metaDataTags.LengthUnit));

% Read optodes positions
[src_pos, det_pos, has3Dposition] = getOptodesPosition(jnirs, lenght_scale);

% Create channel file structure
[ChannelMat, good_channel,channel_type, data_scale] = channelMat_from_measurementList(jnirs,src_pos,det_pos);


if ~any(good_channel) 
    error('No supported channel found in the file')
elseif length(unique(channel_type(good_channel))) >= 2  
    error('Multiple data type detected in the same file (%s)', strjoin(unique(channel_type(good_channel)), ', '))
else
    channel_type = unique(channel_type(good_channel));
end

% Determine the number of time sample
if(size(jnirs.nirs.data.dataTimeSeries,1) == length(good_channel))
    nSample = size(jnirs.nirs.data.dataTimeSeries,2);
else
    nSample = size(jnirs.nirs.data.dataTimeSeries,1);
end   

% Read auxilary channels
[ChannelAux, good_aux]  = readAuxChannels(jnirs, nSample);
ChannelMat.Channel      = [ChannelMat.Channel(good_channel) ,  ChannelAux(good_aux) ];

% Fix channels names: remove channel with empty names
ChannelMat              = fixChannelNames(ChannelMat);

% Add fiducials and head point to ChannelMat
[ChannelMat, hasLandmark] = updateLandmark(jnirs, lenght_scale, ChannelMat);

% Read coordinate system
hasCoordinateSystem = isfield(jnirs.nirs.probe, 'coordinateSystem') && ~isempty(jnirs.nirs.probe.coordinateSystem);
if hasCoordinateSystem
    warning('Todo: apply coordinate system');
end

if has3Dposition && ~( hasLandmark || hasCoordinateSystem)
    warning('The file doesnt contains fiducial or information about the coordinate system used. Expect the localization of the montage to be wrong');
end


% Initialize returned file structure                    
DataMat             = db_template('DataMat');

% Add information read from header
[fPath, fBase, fExt] = bst_fileparts(DataFile);
DataMat.Comment     = fBase;
DataMat.DataType    = 'recordings';
DataMat.Device      = readDeviceName(jnirs.nirs.metaDataTags);
[DataMat.acq_date, TimeOfStudy] = readDateOfStudy(jnirs.nirs.metaDataTags);
DataMat.F           = readData(jnirs, data_scale, good_channel, good_aux);
DataMat.Time        = expendTime(jnirs.nirs.data.time, nSample);
DataMat.ChannelFlag = ones(size(DataMat.F,1), 1);
DataMat.Events      = readEvents(jnirs);
DataMat.DisplayUnits = getDisplayUnits(channel_type);

end

function jnirs = detectAndFixError(jnirs)
% Attempt to detect and correct the classical missformating of the snirf
% data and correct them 


    if isempty(jnirs) 
        error('The file doesnt seems to be a valid SNIRF file');
    end

    if ~isfield(jnirs, 'nirs') 
        if isfield(jnirs,'SNIRFData') && ~isempty(jnirs.SNIRFData)
            jnirs.nirs = jnirs.SNIRFData;
        else
            error('The file doesnt seems to be a valid SNIRF file');
        end
    end
    
    if length(jnirs.nirs) > 1 ||  length(jnirs.nirs.data) > 1
        error('Brainstorm doesnt support SNIRF file with multiple data block');
    end
    
    if ~isfield(jnirs.nirs.probe,'sourceLabels') || ~isfield(jnirs.nirs.probe,'detectorLabels')
        warning('SNIRF format doesnt contains source or detector name. Name of the channels might be wrong');
        jnirs.nirs.probe.sourceLabels = {};
        jnirs.nirs.probe.detectorLabels = {};
    end

    % Convert cell array to string array 
    if iscell(jnirs.nirs.probe.sourceLabels)
        jnirs.nirs.probe.sourceLabels = convertCharsToStrings(jnirs.nirs.probe.sourceLabels);
    end
    if iscell(jnirs.nirs.probe.detectorLabels)
        jnirs.nirs.probe.detectorLabels = convertCharsToStrings(jnirs.nirs.probe.detectorLabels);
    end

    % Events. Convert cell array to struct array
    if iscell(jnirs.nirs.stim)
       jnirs.nirs.stim =  cell2mat(jnirs.nirs.stim);
    end

    % Convert all measurementList to be array-of-struct
    if isfield(jnirs.nirs.data , 'measurementList' ) 
        if length(jnirs.nirs.data.measurementList) == 1  && length(jnirs.nirs.data.measurementList.sourceIndex) > 1
            jnirs.nirs.data.measurementList = soa2aos(jnirs.nirs.data.measurementList);
        end
    elseif isfield(jnirs.nirs.data , 'measurementLists' )
        jnirs.nirs.data.measurementList = soa2aos(jnirs.nirs.data.measurementList);
    else 
        error('The file doesnt seems to be a valid SNIRF file (missing measurementList or measurementLists)')
    end
    

end


function Device      = readDeviceName(metaDataTags)
    
    if isfield(metaDataTags, 'Model') && isfield(metaDataTags, 'ManufacturerName') 
        Device = sprintf('%s (%s)',metaDataTags.Model, metaDataTags.ManufacturerName);
    elseif isfield(metaDataTags, 'Model') 
        Device = sprintf('%s',metaDataTags.Model);
    else
        Device = 'Unknown';
    end
end

function [DateOfStudy, TimeOfStudy] = readDateOfStudy(metaDataTags)
    
    DateOfStudy = [];
    TimeOfStudy = [];

    if isfield(metaDataTags,'MeasurementDate') && ~isempty(metaDataTags.MeasurementDate)
        try
            DateOfStudy = datetime(toLine(metaDataTags.MeasurementDate),'InputFormat','yyyy-MM-dd');
        catch
            warning('Unable to read the Measurement Date')
        end
    end

    if isfield(metaDataTags,'MeasurementTime') && ~isempty(metaDataTags.MeasurementTime)
        try
            TimeOfStudy = duration(toLine(metaDataTags.MeasurementTime));
        catch
            warning('Unable to read the Measurement Time')
        end
        
    end

end 
function [ChannelMat, good_channel, channel_type, factor] = channelMat_from_measurementList(jnirs,src_pos,det_pos)
    
    % Create channel file structure
    ChannelMat = db_template('channelmat');
    ChannelMat.Comment = 'NIRS-BRS channels';

    if isfield(jnirs.nirs.probe, 'wavelengths') && ~isempty(jnirs.nirs.probe.wavelengths)
        ChannelMat.Nirs.Wavelengths = round(jnirs.nirs.probe.wavelengths);
    end

    % Get number of channels
    nChannels    = size(jnirs.nirs.data.measurementList, 2);
    good_channel = true(1,nChannels);
    channel_type = cell(1,nChannels);
    factor       = ones(1, nChannels);

    % NIRS channels
    for iChan = 1:nChannels
        % This assume measure are raw; need to change for Hbo,HbR,HbT
        channel = jnirs.nirs.data.measurementList(iChan);

        % Check data type for the channel 
        if channel.dataType == 1
            measure = round(jnirs.nirs.probe.wavelengths(channel.wavelengthIndex));
            measure_label = sprintf('WL%d', measure);
            channel_type{iChan} = 'raw'; 

        elseif channel.dataType > 1 &&  channel.dataType < 99999
            warning('Unsuported channel %d (channel type %d)', iChan,channel.dataType)
            good_channel(iChan) = false;
            continue;
        elseif channel.dataType  == 99999
            if ~isfield(channel,'dataTypeLabel')
                warning('Missing dataTypeLabel for channel %d')
                good_channel(iChan) = false;
                continue;
            elseif ~any(strcmp(clean_str(channel.dataTypeLabel), {'dOD','HbO','HbR','HbT','HRF dOD', 'HRF HbO','HRF HbR','HRF HbT',}))
                warning('%s is not yet supported by NIRSTORM.', clean_str(channel.dataTypeLabel))
                good_channel(iChan) = false;
                continue;
            else
                switch(clean_str(channel.dataTypeLabel))
                    case {'dOD','HRF dOD'}
                        measure = round(jnirs.nirs.probe.wavelengths(channel.wavelengthIndex));
                        measure_label = sprintf('WL%d', measure);
                        channel_type{iChan} = 'dOD'; 
                    case {'HbO','HRF HbO'}
                        measure = 'HbO';
                        measure_label = measure;
                        channel_type{iChan} = 'dHb'; 
                    case {'HbR','HRF HbR'}
                        measure = 'HbR';
                        measure_label  = measure;
                        channel_type{iChan} = 'dHb'; 
                    case {'HbT','HRF HbT'}
                        measure = 'HbT';
                        measure_label  = measure;
                        channel_type{iChan} = 'dHb'; 
                end
            end
        end


        if isempty(jnirs.nirs.probe.sourceLabels) || isempty(jnirs.nirs.probe.detectorLabels)
            [ChannelMat.Channel(iChan).Name, ChannelMat.Channel(iChan).Group] = nst_format_channel(channel.sourceIndex, channel.detectorIndex, measure); 
        else
    
            ChannelMat.Channel(iChan).Name = sprintf('%s%s%s', jnirs.nirs.probe.sourceLabels(channel.sourceIndex), ...
                                                               jnirs.nirs.probe.detectorLabels(channel.detectorIndex), ...
                                                               measure_label);
            ChannelMat.Channel(iChan).Name = TxRxtoSD(ChannelMat.Channel(iChan).Name);
            ChannelMat.Channel(iChan).Group = measure_label;
    
        end

        ChannelMat.Channel(iChan).Type = 'NIRS';
        ChannelMat.Channel(iChan).Weight = 1;

        if ~isempty(src_pos) && ~isempty(det_pos)
            ChannelMat.Channel(iChan).Loc(:,1) = src_pos(channel.sourceIndex, :);
            ChannelMat.Channel(iChan).Loc(:,2) = det_pos(channel.detectorIndex, :);
            ChannelMat.Channel(iChan).Orient  = [];
            ChannelMat.Channel(iChan).Comment = [];
        end

        if isfield(channel, 'dataUnit') && ~isempty(channel.dataUnit)
            factor(iChan) = findFactorFromUnit(channel.dataUnit,channel_type{iChan});
        end
       
    end

end

function vect = toColumn(vect, exp_size)
    if ~isempty(exp_size)
        if size(vect,1) ~= length(exp_size)
            vect = vect';
        end
    else
        if size(vect,2) >= size(vect,1)
            vect = vect';
        end
    end
end

function vect = toLine(vect)
    if size(vect,1) >= size(vect,2)
        vect = vect';
    end
end

function channel_name = TxRxtoSD(channel_name)
% Convert channel names from Tx1Rx1WL760 to S1D1WL760
    channel_name = strrep(channel_name, 'Tx','S');
    channel_name = strrep(channel_name, 'Rx','D');
end


function timeVect = expendTime(time, nSample)
% Expand the time vector. 
% If length(time) == 2, time contains the start and step size
% Otherwise, it contains the full time definition
% The case where nSample = 2 is a bit weird and is considererd to be 
% start + step size

    if length(time) == 2
        timeVect = time(1):time(2):(nSample-1)*time(2);
    else
        timeVect = time;
    end

end

function Events = readEvents(jnirs)
%% Read events from the nirs structure
% Read events (SNIRF created by Homer3)

    if ~isfield(jnirs.nirs,'stim')
        if any(contains(fieldnames(jnirs.nirs),'stim'))
            nirs_fields = fieldnames(jnirs.nirs);
            sim_key = nirs_fields(contains(fieldnames(jnirs.nirs),'stim'));
            jnirs.nirs.stim  = jnirs.nirs.( sim_key{1});
            for iStim = 2:length(sim_key)
                jnirs.nirs.stim(iStim)  = jnirs.nirs.( sim_key{iStim});
            end
        else
            Events = repmat(db_template('event'), 1, 0);
            return
        end
    end

    Events = repmat(db_template('event'), 1, length(jnirs.nirs.stim));
    for iEvt = 1:length(jnirs.nirs.stim)
        
        if iscell(jnirs.nirs.stim(iEvt))
            Events(iEvt).label      = clean_str(jnirs.nirs.stim{iEvt}.name);
        else
            Events(iEvt).label      = clean_str(jnirs.nirs.stim(iEvt).name);
        end

        if ~isfield(jnirs.nirs.stim(iEvt), 'data') || isempty(jnirs.nirs.stim(iEvt).data) 
            % Events structure
            warning(sprintf('No data found for event: %s',Events(iEvt).label))
            continue
        end    

        % Get timing
        nStimDataCols = 3; % [starttime duration value]
        if isfield(jnirs.nirs.stim(iEvt), 'dataLabels')
            nStimDataCols = length(jnirs.nirs.stim(iEvt).dataLabels);
        end
        % Transpose to match number of columns
        if size(jnirs.nirs.stim(iEvt).data, 1) == nStimDataCols && diff(size(jnirs.nirs.stim(iEvt).data)) ~= 0
            jnirs.nirs.stim(iEvt).data = jnirs.nirs.stim(iEvt).data';
        end    

        isExtended = ~all(jnirs.nirs.stim(iEvt).data(:,2) == 0);
        if isExtended
            evtTime = [jnirs.nirs.stim(iEvt).data(:,1) ,  ...
                       jnirs.nirs.stim(iEvt).data(:,1) + jnirs.nirs.stim(iEvt).data(:,2)]';
        else
            evtTime = jnirs.nirs.stim(iEvt).data(:,1)';
        end
        
        Events(iEvt).times      = evtTime;
        Events(iEvt).epochs     = ones(1, size(evtTime,2));
        Events(iEvt).channels   = [];
        Events(iEvt).notes      = [];
        Events(iEvt).reactTimes = [];
    end   
end

function factor = findFactorFromUnit(dataUnit,channel_type)
    factor = 1;

    if strcmp(channel_type,'dHb')
       switch lower(dataUnit)
           case {'mol.l-1', 'mol/l', 'mole/l'}
                factor = 1;
           case {'mmol.l-1', 'mmol/l', 'mmole/l'}
                factor = 1e-3;
           case {'\mumol.l-1', '\mumol/l', '\mumole/l'}
                factor = 1e-6;
           otherwise
                warning('Unknown unit %s for data type %s. The scaling of your data might be wrong', dataUnit, channel_type)
       end
    else
        warning('Unknown unit %s for data type %s. The scaling of your data might be wrong', dataUnit, channel_type)
    end
end

function str = clean_str(str)
    str = strtrim(str_remove_spec_chars(toLine(str)));
end

function [ChannelMat, hasLandmark] = updateLandmark(jnirs, scale, ChannelMat)
    
    hasLandmark = false;

    % Anatomical landmarks
    if isfield(jnirs.nirs.probe, 'landmarkLabels')
        if isfield(jnirs.nirs.probe, 'landmarkPos') && ~isfield(jnirs.nirs.probe, 'landmarkPos3D')
            jnirs.nirs.probe.landmarkPos3D = jnirs.nirs.probe.landmarkPos;
        end
        
        jnirs.nirs.probe.landmarkPos3D = toColumn(jnirs.nirs.probe.landmarkPos3D, jnirs.nirs.probe.landmarkLabels);
        
        for iLandmark = 1:size(jnirs.nirs.probe.landmarkPos3D, 1)
            name = clean_str(jnirs.nirs.probe.landmarkLabels{iLandmark});
            coord = scale .* jnirs.nirs.probe.landmarkPos3D(iLandmark, 1:3);
            
            % Fiducials NAS/LPA/RPA
            switch lower(name)
                case {'nasion','nas','nz'}
                    ChannelMat.SCS.NAS = coord;
                    ltype = 'CARDINAL';
                case {'leftear', 'lpa'}
                    ChannelMat.SCS.LPA = coord;
                    ltype = 'CARDINAL';
                case {'rightear','rpa'}
                    ChannelMat.SCS.RPA = coord;
                    ltype = 'CARDINAL';
                otherwise
                    ltype = 'EXTRA';
            end

            % Add head point
            ChannelMat.HeadPoints.Loc(:, end+1) = coord';
            ChannelMat.HeadPoints.Label{end+1}  = name;
            ChannelMat.HeadPoints.Type{end+1}   = ltype;
        end   

        hasLandmark = true;
    end  
end

function [src_pos, det_pos, has3Dposition] = getOptodesPosition(jnirs, scale)

    has3Dposition = false;
    % Get 3D positions
    if all(isfield(jnirs.nirs.probe, {'sourcePos3D', 'detectorPos3D'})) && ~isempty(jnirs.nirs.probe.sourcePos3D) && ~isempty(jnirs.nirs.probe.detectorPos3D)
        
        src_pos = toColumn(jnirs.nirs.probe.sourcePos3D, jnirs.nirs.probe.sourceLabels);
        det_pos = toColumn(jnirs.nirs.probe.detectorPos3D, jnirs.nirs.probe.detectorLabels);
        has3Dposition = true;
    elseif all(isfield(jnirs.nirs.probe, {'sourcePos', 'detectorPos'})) && ~isempty(jnirs.nirs.probe.sourcePos) && ~isempty(jnirs.nirs.probe.detectorPos)
        
        src_pos = toColumn(jnirs.nirs.probe.sourcePos, jnirs.nirs.probe.sourceLabels);  
        det_pos = toColumn(jnirs.nirs.probe.detectorPos, jnirs.nirs.probe.detectorLabels);
        
        % If src and det are 2D pos, then set z to 1 to avoid issue at (x=0,y=0,z=0)
        if ~isempty(src_pos) && all(src_pos(:,3)==0) && all(det_pos(:,3)==0)
            src_pos(:,3) = 1;
            det_pos(:,3) = 1;
        else
            has3Dposition = true;
        end
    elseif all(isfield(jnirs.nirs.probe, {'sourcePos2D', 'detectorPos2D'})) && ~isempty(jnirs.nirs.probe.sourcePos2D) && ~isempty(jnirs.nirs.probe.detectorPos2D)
        
        src_pos = toColumn(jnirs.nirs.probe.sourcePos2D, jnirs.nirs.probe.sourceLabels); 
        det_pos = toColumn(jnirs.nirs.probe.detectorPos2D, jnirs.nirs.probe.detectorLabels);
        
        src_pos(:,3) = 1;
        det_pos(:,3) = 1;
    else
        src_pos = [];
        det_pos = [];
    end
    
    % Apply units
    src_pos = scale .* src_pos;
    det_pos = scale .* det_pos;
end

function [Channel, good_aux] = readAuxChannels(jnirs, nSample)
    
    if isfield(jnirs.nirs,'aux')
        nAux = length(jnirs.nirs.aux);
    else
        nAux = 0;
    end
   
    Channel     = repmat( struct('Name','','Group','', 'Type' ,'','Weight',1, 'Loc',[], 'Orient', [],'Comment',[]), 1, nAux);
    good_aux    = false(1,nAux);

    for iAux = 1:nAux
        
        if ~isempty(jnirs.nirs.data.dataTimeSeries) && ~isempty(jnirs.nirs.aux(iAux).dataTimeSeries) ...
                && length(jnirs.nirs.data.time) == length(jnirs.nirs.aux(iAux).time) ...
                && isequal(expendTime(jnirs.nirs.data.time, nSample), expendTime(jnirs.nirs.aux(iAux).time,nSample)) ...
                && ( ~isfield(jnirs.nirs.aux(iAux), 'timeOffset') ||  jnirs.nirs.aux(iAux).timeOffset == 0)
            
            aux = jnirs.nirs.aux(iAux);

            Channel(iAux).Type  = 'NIRS_AUX';
            Channel(iAux).Name  = clean_str(aux.name);
            good_aux(iAux)      = true;            
        else 
            
            warning(sprintf('Time vector for auxilary measure %s is not compatible with nirs measurement',jnirs.nirs.aux(iAux).name));
            continue;
        end
    end
end

function ChannelMat = fixChannelNames(ChannelMat)
    % Check channel names
    for iChan = 1:length(ChannelMat.Channel)
        % If empty channel name: fill with index
        if isempty(ChannelMat.Channel(iChan).Name)
            ChannelMat.Channel(iChan).Name = sprintf('N%d', iChan);
        end
        iOther = setdiff(1:length(ChannelMat.Channel), iChan);
        ChannelMat.Channel(iChan).Name = file_unique(ChannelMat.Channel(iChan).Name, {ChannelMat.Channel(iOther).Name});
    end
end

function data = readData(jnirs, data_scale, good_channel, good_aux)

    if(size(jnirs.nirs.data.dataTimeSeries,1) == length(good_channel))
        data = jnirs.nirs.data.dataTimeSeries;
    else
        data  = jnirs.nirs.data.dataTimeSeries'; 
    end   
    
    % Add offset to the data 
    if isfield(jnirs.nirs.data,'dataOffset') && ~isempty(jnirs.nirs.data.dataOffset) && length(jnirs.nirs.data.dataOffset) ==  length(good_channel)
        for iChan = 1:length(good_channel)
            data(iChan,:) = data(iChan,:) + jnirs.nirs.data.dataOffset(iChan);
        end
    end
    
    % Apply data unit
    for iChan = 1:length(good_channel)
        data(iChan,:) = data_scale(iChan) * data(iChan,:);
    end
    
    % Select supported channels
    data   = data(good_channel, :);
    
    % Add auxilary data
    for i_aux = 1:length(good_aux)
        if ~good_aux(i_aux)
            continue;
        end
        
        if size(jnirs.nirs.aux(i_aux).dataTimeSeries,1) == 1
            data = [data ; jnirs.nirs.aux(i_aux).dataTimeSeries]; 
        else
            data = [data ; jnirs.nirs.aux(i_aux).dataTimeSeries']; 
        end    
    end

end

function DisplayUnits = getDisplayUnits(channel_type)
    if strcmp(channel_type,'dOD')
        DisplayUnits = 'delta OD';
    elseif strcmp(channel_type,'dHb')
        DisplayUnits = 'mol.l-1';
    else
        DisplayUnits = '';
    end
end

