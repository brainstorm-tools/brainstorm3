function  out_snirf(ExportFile,DataMat,ChannelMatOut)

% Create an empty snirf data structure
snirfdata=jsnirfcreate();


nirs_channels = strcmpi({ChannelMatOut.Channel.Type}, 'NIRS')';
nirs_aux = ~nirs_channels;

n_channel=sum(nirs_channels);
n_aux=sum(nirs_aux);

% Set data
snirfdata.SNIRFData.data.dataTimeSeries=DataMat.F(nirs_channels,:)'; % Time*Channels
snirfdata.SNIRFData.data.time=DataMat.Time'; % Time*1

% Set auxiliary data
aux_channel=find(nirs_aux);
for i_aux=1:n_aux
    snirfdata.SNIRFData.aux(i_aux).name=ChannelMatOut.Channel(aux_channel(i_aux)).Name;
    snirfdata.SNIRFData.aux(i_aux).dataTimeSeries=DataMat.F(aux_channel(i_aux),:)';
    snirfdata.SNIRFData.aux(i_aux).time=DataMat.Time';
end    

% Set Probe; maybe can be simplified with the export of the measurment list
[isrcs, idets, chan_measures, measure_type] = nst_unformat_channels({ChannelMatOut.Channel(nirs_channels).Name});

src_pos=[];
for i_src=unique(isrcs) % iterate over the source index
    src_pos(end+1,:)=ChannelMatOut.Channel(i_src).Loc(:,1)';
end    
det_pos=[];
for i_det=unique(idets) % iterate over the detector index
    det_pos(end+1,:)=ChannelMatOut.Channel(i_det).Loc(:,2)';
end    

% Todo : export detectorLabels and sourceLabels (string array)
snirfdata.SNIRFData.probe.wavelengths=ChannelMatOut.Nirs.Wavelengths;
snirfdata.SNIRFData.probe.sourcePos=src_pos;
snirfdata.SNIRFData.probe.detectorPos=det_pos;

% Set landmark position (eg fiducials) 
% Todo : make sure those landmark are defined ? Add AC,PC,IH
snirfdata.SNIRFData.probe.landmarkPos =  [ ChannelMatOut.SCS.NAS ; ...
                                           ChannelMatOut.SCS.LPA ; ...
                                           ChannelMatOut.SCS.RPA ] ;
                                           
snirfdata.SNIRFData.probe.landmarkLabels(1)="Nasion";
snirfdata.SNIRFData.probe.landmarkLabels(2)="LeftEar";
snirfdata.SNIRFData.probe.landmarkLabels(3)="RightEar";

% Set Measurment list
for ichan=1:n_channel
    measurement=struct('sourceIndex',[],'detectorIndex',[],...
              'wavelengthIndex',[],'dataType',1,'dataTypeIndex',1); 
          
    measurement.sourceIndex=isrcs(ichan);
    measurement.detectorIndex=idets(ichan);
    measurement.wavelengthIndex=find(ChannelMatOut.Nirs.Wavelengths==chan_measures(ichan));

    snirfdata.SNIRFData.data.measurementList(ichan)=measurement;      

end   

% Set Stim 
n_event=length(DataMat.Events);
for i_event=1:n_event
    stim=struct('name','','data',[]);
    stim.name=DataMat.Events(i_event).label;
    
    % Fill stimulus time course; each line correspond to [starttime duration value]
    n_stimuli=size(DataMat.Events(i_event).times,2);
    is_extended=size(DataMat.Events(i_event).times,1)==2;
    data=zeros(n_stimuli,3);
    for i_stim=1:n_stimuli
        starttime=DataMat.Events(i_event).times(1,i_stim);
        
        if is_extended 
            duration=DataMat.Events(i_event).times(2,i_stim) - starttime;
        else
            duration=0;
        end    
        value=1;
        data(i_stim,:)=[starttime duration value];
    end    
    stim.data=data;
    snirfdata.SNIRFData.stim(i_event)=stim;   
end    


% Save snirf file. 
savesnirf(snirfdata, ExportFile);
end

