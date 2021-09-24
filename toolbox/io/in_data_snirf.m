function  [DataMat, ChannelMat] = in_data_snirf(DataFile)
% IN_FOPEN_SNIRF Open a fNIRS file based on the SNIRF format
%
% DESCRIPTION:
%     This function is based on the SNIRF specification v.1 
%     https://github.com/fNIRS/snirf

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
% Authors: Edouard Delaire, Francois Tadel, 2020

% Load file header with the JSNIRF Toolbox (https://github.com/fangq/jsnirfy)
jnirs = loadsnirf(DataFile);


%% ===== CHANNEL FILE ====
% Get scaling units
switch strtrim(str_remove_spec_chars(jnirs.nirs.metaDataTags.LengthUnit(:)'))
    case 'mm'
        scale = 0.001;
    case 'cm'
        scale = 0.01;
    case 'm'
        scale = 1;
    otherwise
        scale = 1;
end
% Get 3D positions
if all(isfield(jnirs.nirs.probe, {'sourcePos3D', 'detectorPos3D'})) && ~isempty(jnirs.nirs.probe.sourcePos3D) && ~isempty(jnirs.nirs.probe.detectorPos3D)
    
    src_pos = jnirs.nirs.probe.sourcePos3D;
    det_pos = jnirs.nirs.probe.detectorPos3D;

elseif all(isfield(jnirs.nirs.probe, {'sourcePos', 'detectorPos'})) && ~isempty(jnirs.nirs.probe.sourcePos) && ~isempty(jnirs.nirs.probe.detectorPos)
    
    src_pos = jnirs.nirs.probe.sourcePos;
    det_pos = jnirs.nirs.probe.detectorPos;
    % If src and det are 2D pos, then set z to 1 to avoid issue at (x=0,y=0,z=0)
    if ~isempty(src_pos) && all(src_pos(:,3)==0) && all(det_pos(:,3)==0)
        src_pos(:,3) = 1;
        det_pos(:,3) = 1;
    end
elseif all(isfield(jnirs.nirs.probe, {'sourcePos2D', 'detectorPos2D'})) && ~isempty(jnirs.nirs.probe.sourcePos2D) && ~isempty(jnirs.nirs.probe.detectorPos2D)
    
    src_pos = jnirs.nirs.probe.sourcePos2D;
    det_pos = jnirs.nirs.probe.detectorPos2D;
    
    if size(src_pos,2) ~= 3
        src_pos = src_pos';
        det_pos = det_pos';
    end
    
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
nAux = length(jnirs.nirs.aux);

% Create channel file structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'NIRS-BRS channels';
ChannelMat.Nirs.Wavelengths = jnirs.nirs.probe.wavelengths;
% NIRS channels
for iChan = 1:nChannels
    % This assume measure are raw; need to change for Hbo,HbR,HbT
    channel = jnirs.nirs.data.measurementList(iChan);
    [ChannelMat.Channel(iChan).Name, ChannelMat.Channel(iChan).Group] = nst_format_channel(channel.sourceIndex, channel.detectorIndex, jnirs.nirs.probe.wavelengths(channel.wavelengthIndex)); 
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
aux_index = false(1,nAux);
for iAux = 1:nAux
    
     if ~isempty(jnirs.nirs.data.dataTimeSeries) && ~isempty(jnirs.nirs.aux(iAux).dataTimeSeries) ...
        && ( size(jnirs.nirs.data.time,1) ~= size(jnirs.nirs.aux(iAux).time,1) || jnirs.nirs.aux(iAux).timeOffset ~= 0 )
    
        warning(sprintf('Time vector for auxilary measure %s is not compatible with nirs measurement',jnirs.nirs.aux(iAux).name));
        continue;

        % If needed, following code should work :) 
        % interp1(jnirs.nirs.aux(iAux).time, jnirs.nirs.aux(iAux).dataTimeSeries, jnirs.nirs.data.time); 
        
     end
     
    aux_index(iAux)=1;
    channel = jnirs.nirs.aux(iAux);
    ChannelMat.Channel(nChannels+iAux).Type = 'NIRS_AUX';
    ChannelMat.Channel(nChannels+iAux).Name = strtrim(str_remove_spec_chars(channel.name(:)'));
end

nAux = sum(aux_index);
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
    for iLandmark = 1:size(jnirs.nirs.probe.landmarkPos, 1)
        name = strtrim(str_remove_spec_chars(reshape(jnirs.nirs.probe.landmarkLabels(:,:,iLandmark),1,[])));
        coord = scale .* jnirs.nirs.probe.landmarkPos(iLandmark,:);
        % Fiducials NAS/LPA/RPA
        switch name
            case 'Nasion'
                ChannelMat.SCS.NAS = coord;
                ltype = 'CARDINAL';
            case 'LeftEar'
                ChannelMat.SCS.LPA = coord;
                ltype = 'CARDINAL';
            case 'RightEar'    
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
    DataMat.F           = jnirs.nirs.data.dataTimeSeries;
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
DataMat.Events = repmat(db_template('event'), 1, length(jnirs.nirs.stim));

for iEvt = 1:length(jnirs.nirs.stim)
    
    DataMat.Events(iEvt).label      = strtrim(str_remove_spec_chars(jnirs.nirs.stim(iEvt).name(:)'));
    if ~isfield(jnirs.nirs.stim(iEvt), 'data')
            % Events structure
        warning(sprintf('No data found for event: %s',jnirs.nirs.stim(iEvt).name))
        continue
    end    
    % Get timing
    
    if size(jnirs.nirs.stim(iEvt).data,1) >  size(jnirs.nirs.stim(iEvt).data,1)
        jnirs.nirs.stim(iEvt).data = jnirs.nirs.stim(iEvt).data';
    end    
    
    isExtended = (size(jnirs.nirs.stim(iEvt).data,1) >= 2) && ~all(jnirs.nirs.stim(iEvt).data(2,:) == 0);
    if isExtended
        evtTime = [jnirs.nirs.stim(iEvt).data(1,:); ...
                   jnirs.nirs.stim(iEvt).data(1,:) + jnirs.nirs.stim(iEvt).data(2,:)];
    else
        evtTime = jnirs.nirs.stim(iEvt).data(1,:)';
    end

    DataMat.Events(iEvt).times      = evtTime;
    DataMat.Events(iEvt).epochs     = ones(1, size(evtTime,2));
    DataMat.Events(iEvt).channels   = cell(1, size(evtTime,2));
    DataMat.Events(iEvt).notes      = cell(1, size(evtTime,2));
    DataMat.Events(iEvt).reactTimes = [];
end   


