function out_data_snirf(ExportFile, DataMat, ChannelMatOut)
% OUT_DATA_SNIRF Export fNIRS recordings to SNIRF format.
%
% DESCRIPTION:
%     This function is based on the SNIRF specification v.1 
%     https://github.com/fNIRS/snirf

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
if ~exist('jsnirfcreate', 'file')
    [isInstalled, errMsg] = bst_plugin('Install', 'jsnirfy');
    if ~isInstalled
        error(errMsg);
    end
end

% Create an empty snirf data structure
snirfdata = jsnirfcreate();

% Set meta data
snirfdata.SNIRFData.metaDataTags.LengthUnit = 'm';

nirs_channels = strcmpi({ChannelMatOut.Channel.Type}, 'NIRS')';
nirs_aux = ~nirs_channels;

n_channel = sum(nirs_channels);
n_aux = sum(nirs_aux);

% Set data
snirfdata.SNIRFData.data.dataTimeSeries = DataMat.F(nirs_channels,:)'; % Time*Channels
snirfdata.SNIRFData.data.time = DataMat.Time'; % Time*1

% Set auxiliary data
aux_channel=find(nirs_aux);
for i_aux=1:n_aux
    snirfdata.SNIRFData.aux(i_aux).name=ChannelMatOut.Channel(aux_channel(i_aux)).Name;
    snirfdata.SNIRFData.aux(i_aux).dataTimeSeries=DataMat.F(aux_channel(i_aux),:)';
    snirfdata.SNIRFData.aux(i_aux).time=DataMat.Time';
    snirfdata.SNIRFData.aux(i_aux).timeOffset = 0;
end    

% Set landmark position (eg fiducials) 
n_landmark=length(ChannelMatOut.HeadPoints.Label);

snirfdata.SNIRFData.probe.landmarkPos3D = zeros(n_landmark,3);
for i_landmark=1:n_landmark
    snirfdata.SNIRFData.probe.landmarkPos3D(i_landmark,:)=ChannelMatOut.HeadPoints.Loc(:,i_landmark)';
    snirfdata.SNIRFData.probe.landmarkLabels(i_landmark)=string(ChannelMatOut.HeadPoints.Label{i_landmark}); 
end    

% Set Probe; maybe can be simplified with the export of the measurment list
[isrcs, idets, chan_measures, measure_type] = nst_unformat_channels({ChannelMatOut.Channel(nirs_channels).Name});

src_pos     = zeros(length(unique(isrcs)),3); 
src_label   = repmat( "", 1,length(unique(isrcs)));
src_Index   = zeros(length(unique(isrcs)),1);
det_pos     = zeros(length(unique(idets)),3); 
det_label   = repmat( "", 1,length(unique(idets)));
det_Index   = zeros(length(unique(isrcs)),1);

% Set Measurment list
nSrc = 1;
nDet = 1;
for ichan=1:n_channel
    [isrc, idet, chan_measures, measure_type] = nst_unformat_channels({ChannelMatOut.Channel(ichan).Name});

    if ~any(cellfun(@(x)strcmp(x, sprintf('S%d',isrc )), src_label))
        src_label(nSrc) = sprintf("S%d", isrc);
        src_Index(nSrc) = isrc;
        src_pos(nSrc,:) = ChannelMatOut.Channel(ichan).Loc(:,1)';

        nSrc = nSrc + 1;
    end

    if ~any(cellfun(@(x)strcmp(x, sprintf('D%d',idet )), det_label))
        det_label(nDet) = sprintf("D%d",idet );
        det_Index(nDet) = idet;
        det_pos(nDet,:) = ChannelMatOut.Channel(ichan).Loc(:,2)';

        nDet = nDet + 1;
    end

end

% Set Measurment list

isProcessed = ~isempty(DataMat.DisplayUnits) && ( contains(DataMat.DisplayUnits, {'OD', 'mol'}) );
if isProcessed
    snirfdata.SNIRFData.data.measurementList.dataTypeLabel = '';
end

for ichan=1:n_channel
    measurement=struct('sourceIndex',[],'detectorIndex', [], 'wavelengthIndex', [], 'dataType',1, 'dataTypeIndex', 1); 
    [isrc, idet, chan_measures, measure_type] = nst_unformat_channels({ChannelMatOut.Channel(ichan).Name});

    measurement.sourceIndex     = find(src_Index == isrc);
    measurement.detectorIndex   = find(det_Index == idet);


    [measurement.dataType,  dataTypeLabel] = getDataType(ChannelMatOut.Channel(ichan), DataMat.DisplayUnits);

    if measurement.dataType > 1
        measurement.dataTypeLabel = dataTypeLabel;
    end

    if ~contains(dataTypeLabel, {'HbO', 'HbR', 'HbT'})
        measurement.wavelengthIndex = find(ChannelMatOut.Nirs.Wavelengths==chan_measures);
    end
    
    snirfdata.SNIRFData.data.measurementList(ichan) = measurement;      
end 

if isProcessed && contains(DataMat.DisplayUnits, 'mol')
    [snirfdata.SNIRFData.data.measurementList.dataUnit]  = deal(DataMat.DisplayUnits);
end


if isfield(ChannelMatOut,'Nirs') && isfield(ChannelMatOut.Nirs, 'Wavelengths')
    snirfdata.SNIRFData.probe.wavelengths=ChannelMatOut.Nirs.Wavelengths;
end

snirfdata.SNIRFData.probe.sourcePos2D=src_pos(:,[1,2]);
snirfdata.SNIRFData.probe.sourcePos3D=src_pos;
snirfdata.SNIRFData.probe.sourceLabels = src_label;

snirfdata.SNIRFData.probe.detectorPos2D=det_pos(:,[1,2]);
snirfdata.SNIRFData.probe.detectorPos3D=det_pos;
snirfdata.SNIRFData.probe.detectorLabels=det_label;


% Set Stim 
nEvt = length(DataMat.Events);
evt_include = true(1,length(DataMat.Events));
for iEvt = 1:nEvt
    % Skip empty events
    if isempty(DataMat.Events(iEvt).times)
        evt_include(iEvt) = false;
        continue;
    end
    % Event structure
    stim = struct('name', '', 'data', []);
    stim.name = DataMat.Events(iEvt).label;
    % Fill stimulus time course; each line correspond to [starttime duration value]
    nOcc = size(DataMat.Events(iEvt).times,2);
    isExtended = size(DataMat.Events(iEvt).times,1)==2;
    data = zeros(nOcc,3);
    for iOcc = 1:nOcc
        starttime = DataMat.Events(iEvt).times(1,iOcc);
        if isExtended 
            duration = DataMat.Events(iEvt).times(2,iOcc) - starttime;
        else
            duration = 0;
        end    
        value = 1;
        data(iOcc,:) = [starttime duration value];
    end    
    stim.data = data;
    snirfdata.SNIRFData.stim(iEvt) = stim;   
end    
if any(evt_include)
    snirfdata.SNIRFData.stim = snirfdata.SNIRFData.stim(evt_include);
else
    snirfdata.SNIRFData = rmfield(snirfdata.SNIRFData,'stim');
end
% Save snirf file. 
savesnirf(snirfdata, ExportFile);

end


function [dataType, dataTypeLabel] = getDataType(Channel, Unit)

    [isrc, idet, chan_measures, measure_type] = nst_unformat_channels({Channel.Name});
    
    if isempty(Unit)
        dataType        = 1;
        dataTypeLabel   = '';
    elseif contains(Unit, 'OD')
        dataType        = 99999;
        dataTypeLabel   = 'dOD';
    elseif contains(chan_measures, {'HbO', 'HbR', 'HbT'})
        dataType        = 99999;
        dataTypeLabel   = chan_measures;
    else
        error('Unable to detect the unit of the file')
    end
end



