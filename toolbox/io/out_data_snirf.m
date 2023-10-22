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

% Set Probe; maybe can be simplified with the export of the measurment list
[isrcs, idets, chan_measures, measure_type] = nst_unformat_channels({ChannelMatOut.Channel(nirs_channels).Name});

src_pos= zeros(length(unique(isrcs)),3); 
src_label = cell(1,length(unique(isrcs)));
det_pos= zeros(length(unique(idets)),3); 
det_label= cell(1,length(unique(idets)));

% Set landmark position (eg fiducials) 
n_landmark=length(ChannelMatOut.HeadPoints.Label);
snirfdata.SNIRFData.probe.landmarkPos=zeros(n_landmark,3);
for i_landmark=1:n_landmark
    snirfdata.SNIRFData.probe.landmarkPos(i_landmark,:)=ChannelMatOut.HeadPoints.Loc(:,i_landmark)';
    snirfdata.SNIRFData.probe.landmarkLabels(i_landmark)=string(ChannelMatOut.HeadPoints.Label{i_landmark}); 
end    

% Set Measurment list
for ichan=1:n_channel
    measurement=struct('sourceIndex',[],'detectorIndex',[],...
              'wavelengthIndex',[],'dataType',1,'dataTypeIndex',1); 
    [isrc, idet, chan_measures, measure_type] = nst_unformat_channels({ChannelMatOut.Channel(ichan).Name});

    src_pos(isrc,:)=ChannelMatOut.Channel(ichan).Loc(:,1)';
    src_label{isrc} = sprintf('S%d',isrc);
    det_pos(idet,:)=ChannelMatOut.Channel(ichan).Loc(:,2)';
    det_label{idet} = sprintf('D%d',idet);

    measurement.sourceIndex=isrc;
    measurement.detectorIndex=idet;
    measurement.wavelengthIndex=find(ChannelMatOut.Nirs.Wavelengths==chan_measures);

    snirfdata.SNIRFData.data.measurementList(ichan)=measurement;      

end 

snirfdata.SNIRFData.probe.wavelengths=ChannelMatOut.Nirs.Wavelengths;

snirfdata.SNIRFData.probe.sourcePos=src_pos;
snirfdata.SNIRFData.probe.sourcePos(:,3)=0; % set z to 0
snirfdata.SNIRFData.probe.sourcePos3D=src_pos;
snirfdata.SNIRFData.probe.sourceLabels = src_label';

snirfdata.SNIRFData.probe.detectorPos=det_pos; 
snirfdata.SNIRFData.probe.detectorPos(:,3)=0; % set z to 0 
snirfdata.SNIRFData.probe.detectorPos3D=det_pos;
snirfdata.SNIRFData.probe.detectorLabels=det_label';


% Set Stim 
nEvt = length(DataMat.Events);
for iEvt = 1:nEvt
    % Skip empty events
    if isempty(DataMat.Events(iEvt).times)
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

% Save snirf file. 
savesnirf(snirfdata, ExportFile);







