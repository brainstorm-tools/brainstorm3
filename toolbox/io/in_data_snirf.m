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
% Authors: Edouard Delaire, Francois Tadel, 2020

% Install/load JSNIRF Toolbox (https://github.com/NeuroJSON/jsnirfy) as plugin
if ~exist('loadsnirf', 'file')
    [isInstalled, errMsg] = bst_plugin('Install', 'jsnirfy');
    if ~isInstalled
        error(errMsg);
    end
end

% Load file header
jnirs = loadsnirf(DataFile);

if isempty(jnirs) || ~isfield(jnirs, 'nirs')
    error('The file doesnt seems to be a valid SNIRF file')
end

if ~isfield(jnirs.nirs.probe,'sourceLabels') || ~isfield(jnirs.nirs.probe,'detectorLabels')
    warning('SNIRF format doesnt contains source or detector name. Name of the channels might be wrong');
    jnirs.nirs.probe.sourceLabels = {};
    jnirs.nirs.probe.detectorLabels = {};
end

%% ===== CHANNEL FILE ====
% Get scaling units
scale = bst_units_ui(toLine(jnirs.nirs.metaDataTags.LengthUnit));
% Get 3D positions
if all(isfield(jnirs.nirs.probe, {'sourcePos3D', 'detectorPos3D'})) && ~isempty(jnirs.nirs.probe.sourcePos3D) && ~isempty(jnirs.nirs.probe.detectorPos3D)
    
    src_pos = toColumn(jnirs.nirs.probe.sourcePos3D, jnirs.nirs.probe.sourceLabels);
    det_pos = toColumn(jnirs.nirs.probe.detectorPos3D, jnirs.nirs.probe.detectorLabels);

elseif all(isfield(jnirs.nirs.probe, {'sourcePos', 'detectorPos'})) && ~isempty(jnirs.nirs.probe.sourcePos) && ~isempty(jnirs.nirs.probe.detectorPos)
    
    src_pos = toColumn(jnirs.nirs.probe.sourcePos, jnirs.nirs.probe.sourceLabels);  
    det_pos = toColumn(jnirs.nirs.probe.detectorPos, jnirs.nirs.probe.detectorLabels);

    % If src and det are 2D pos, then set z to 1 to avoid issue at (x=0,y=0,z=0)
    if ~isempty(src_pos) && all(src_pos(:,3)==0) && all(det_pos(:,3)==0)
        src_pos(:,3) = 1;
        det_pos(:,3) = 1;
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

% Get number of channels
nChannels = size(jnirs.nirs.data.measurementList, 2);

if isfield(jnirs.nirs,'aux')
    nAux = length(jnirs.nirs.aux);
else
    nAux = 0;
end

% Create channel file structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'NIRS-BRS channels';
ChannelMat.Nirs.Wavelengths = round(jnirs.nirs.probe.wavelengths);

% NIRS channels
for iChan = 1:nChannels
    % This assume measure are raw; need to change for Hbo,HbR,HbT
    channel = jnirs.nirs.data.measurementList(iChan);
    if isempty(jnirs.nirs.probe.sourceLabels) || isempty(jnirs.nirs.probe.detectorLabels)
        [ChannelMat.Channel(iChan).Name, ChannelMat.Channel(iChan).Group] = nst_format_channel(channel.sourceIndex, channel.detectorIndex, jnirs.nirs.probe.wavelengths(channel.wavelengthIndex)); 
    else

        ChannelMat.Channel(iChan).Name = sprintf('%s%sWL%d', jnirs.nirs.probe.sourceLabels(channel.sourceIndex), ...
                                                             jnirs.nirs.probe.detectorLabels(channel.detectorIndex), ...
                                                       round(jnirs.nirs.probe.wavelengths(channel.wavelengthIndex)));
        ChannelMat.Channel(iChan).Name = TxRxtoSD(ChannelMat.Channel(iChan).Name);
        ChannelMat.Channel(iChan).Group = sprintf('WL%d', round(jnirs.nirs.probe.wavelengths(channel.wavelengthIndex)));

    end
    ChannelMat.Channel(iChan).Type = 'NIRS';
    ChannelMat.Channel(iChan).Weight = 1;
    if ~isempty(src_pos) && ~isempty(det_pos)
        ChannelMat.Channel(iChan).Loc(:,1) = src_pos(channel.sourceIndex, :);
        ChannelMat.Channel(iChan).Loc(:,2) = det_pos(channel.detectorIndex, :);
        ChannelMat.Channel(iChan).Orient  = [];
        ChannelMat.Channel(iChan).Comment = [];
    end
end

% AUX channels
k_aux =  1;
aux_index = false(1,nAux);
for iAux = 1:nAux
    
     if ~isempty(jnirs.nirs.data.dataTimeSeries) && ~isempty(jnirs.nirs.aux(iAux).dataTimeSeries) ...
        && ( size(jnirs.nirs.data.time,1) ~= size(jnirs.nirs.aux(iAux).time,1) || ( isfield(jnirs.nirs.aux(iAux), 'timeOffset') && jnirs.nirs.aux(iAux).timeOffset ~= 0 ))
    
        warning(sprintf('Time vector for auxilary measure %s is not compatible with nirs measurement',jnirs.nirs.aux(iAux).name));
        continue;

        % If needed, following code should work :) 
        % interp1(jnirs.nirs.aux(iAux).time, jnirs.nirs.aux(iAux).dataTimeSeries, jnirs.nirs.data.time); 
        
     end
     
    channel = jnirs.nirs.aux(iAux);
    ChannelMat.Channel(nChannels+k_aux).Type = 'NIRS_AUX';
    ChannelMat.Channel(nChannels+k_aux).Name = strtrim(str_remove_spec_chars(toLine(channel.name)));
    
    aux_index(iAux) = true;
    k_aux = k_aux + 1;
end
nAux = k_aux - 1;

ChannelMat.Channel = ChannelMat.Channel(1:(nChannels+nAux));
% Check channel names
for iChan = 1:length(ChannelMat.Channel)
    % If empty channel name: fill with index
    if isempty(ChannelMat.Channel(iChan).Name)
        ChannelMat.Channel(iChan).Name = sprintf('N%d', iChan);
    end
    iOther = setdiff(1:length(ChannelMat.Channel), iChan);
    ChannelMat.Channel(iChan).Name = file_unique(ChannelMat.Channel(iChan).Name, {ChannelMat.Channel(iOther).Name});
end

% Anatomical landmarks
if isfield(jnirs.nirs.probe, 'landmarkLabels')
    if isfield(jnirs.nirs.probe, 'landmarkPos') && ~isfield(jnirs.nirs.probe, 'landmarkPos3D')
        jnirs.nirs.probe.landmarkPos3D = jnirs.nirs.probe.landmarkPos;
    end

    jnirs.nirs.probe.landmarkPos3D = toColumn(jnirs.nirs.probe.landmarkPos3D, jnirs.nirs.probe.landmarkLabels);

    for iLandmark = 1:size(jnirs.nirs.probe.landmarkPos3D, 1)
        name = strtrim(str_remove_spec_chars(toLine(jnirs.nirs.probe.landmarkLabels{iLandmark})));
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
end    


%% ===== DATA =====
% Initialize returned file structure                    
DataMat = db_template('DataMat');

% Add information read from header
[fPath, fBase, fExt] = bst_fileparts(DataFile);
DataMat.Comment     = fBase;
DataMat.DataType    = 'recordings';
DataMat.Device      = 'Unknown';

if(size(jnirs.nirs.data.dataTimeSeries,1) == nChannels)
    DataMat.F = jnirs.nirs.data.dataTimeSeries;
else
   DataMat.F  = jnirs.nirs.data.dataTimeSeries'; 
end   


for i_aux= 1:length(aux_index)
    if aux_index(i_aux)
        if size(jnirs.nirs.aux(i_aux).dataTimeSeries,1)==1
            DataMat.F = [DataMat.F ; ...
                     jnirs.nirs.aux(i_aux).dataTimeSeries]; 
        else
            DataMat.F = [DataMat.F ; ...
                     jnirs.nirs.aux(i_aux).dataTimeSeries']; 
        end    
    end
end



DataMat.Time        = jnirs.nirs.data.time;
DataMat.ChannelFlag = ones(size(DataMat.F,1), 1);


%% ===== EVENTS =====

% Read events (SNIRF created by Homer3)
if ~isfield(jnirs.nirs,'stim') && any(contains(fieldnames(jnirs.nirs),'stim'))
    nirs_fields = fieldnames(jnirs.nirs);
    sim_key = nirs_fields(contains(fieldnames(jnirs.nirs),'stim'));
    jnirs.nirs.stim  = jnirs.nirs.( sim_key{1});
    for iStim = 2:length(sim_key)
        jnirs.nirs.stim(iStim)  = jnirs.nirs.( sim_key{iStim});
    end
end

DataMat.Events = repmat(db_template('event'), 1, length(jnirs.nirs.stim));
for iEvt = 1:length(jnirs.nirs.stim)
    
    if iscell(jnirs.nirs.stim(iEvt))
        DataMat.Events(iEvt).label      = strtrim(str_remove_spec_chars(toLine(jnirs.nirs.stim{iEvt}.name)));
    else
        DataMat.Events(iEvt).label      = strtrim(str_remove_spec_chars(toLine(jnirs.nirs.stim(iEvt).name)));
    end
    if ~isfield(jnirs.nirs.stim(iEvt), 'data') || isempty(jnirs.nirs.stim(iEvt).data) 
            % Events structure
        warning(sprintf('No data found for event: %s',DataMat.Events(iEvt).label))
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

    DataMat.Events(iEvt).times      = evtTime;
    DataMat.Events(iEvt).epochs     = ones(1, size(evtTime,2));
    DataMat.Events(iEvt).channels   = [];
    DataMat.Events(iEvt).notes      = [];
    DataMat.Events(iEvt).reactTimes = [];
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
