function  [DataMat, ChannelMat] = in_fopen_snirf(DataFile)
% in_fopen_snirf: Open a fNIRS file based on the SNIRF format
% This function is based on the SNIRF specitication v.1 
% (see https://github.com/fNIRS/snirf for more information) 
% 
%
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
% Authors: Edouard Delaire (2020)
    jnirs       = loadsnirf(DataFile);
    
        
    
    
    time=jnirs.nirs.data.time;
    nb_time=length(time);
    wavelengths=jnirs.nirs.probe.wavelengths;
    % Read probe setting 
    
    n_det=size(jnirs.nirs.probe.detectorPos,1);
    n_source=size(jnirs.nirs.probe.sourcePos,1);
    
    src_pos=jnirs.nirs.probe.sourcePos;
    det_pos=jnirs.nirs.probe.detectorPos;
    
    % Read measurment list 
    nb_channels = size(jnirs.nirs.data.measurementList,2);
    nb_aux      = length(jnirs.nirs.aux);
    ChannelMat = db_template('channelmat');
    ChannelMat.Comment = 'NIRS-BRS channels';
    
    Channels(nb_channels+nb_aux)=struct('Type','NIRS','Name','','Loc',[], ...
                                         'Orient',[],'Weight',1,'Comment',[],...
                                         'Group','');
                                        
    for i_chan=1:nb_channels
        % this assume measure are raw; need to change for Hbo,HbR,HbT
        channel=jnirs.nirs.data.measurementList(i_chan);
        
        measure_tag = sprintf('WL%d', round(wavelengths(channel.wavelengthIndex)));
        
        
        Channels(i_chan).Name       = sprintf('S%dD%d%s', channel.sourceIndex, ...
                                         channel.detectorIndex, measure_tag);
        Channels(i_chan).Type       = 'NIRS';
        Channels(i_chan).Weight     = 1;
        Channels(i_chan).Loc(:,1)   = src_pos(channel.sourceIndex  ,:);
        Channels(i_chan).Loc(:,2)   = det_pos(channel.detectorIndex,:);
        Channels(i_chan).Group      = measure_tag;
    end
    
    for i_aux=1:nb_aux
        channel=jnirs.nirs.aux(i_aux);
        Channels(nb_channels+i_aux).Type='NIRS_AUX';
        Channels(nb_channels+i_aux).Name=channel.name;
        
        % Sanity check : make sure that time course are consistent with
        % nirs one (compare channel.time with nirs timecourse)
    end    
    
    % Check uniqueness
    chan_names = {Channels.Name};
    [~, i_unique] = unique(chan_names);
    duplicates = chan_names;
    duplicates(i_unique) = [];
    duplicates(strcmp(duplicates, '')) = []; %remove unrecognized channels
    i_duplicates = ismember(chan_names, unique(duplicates));
    if ~isempty(duplicates)
        msg = sprintf('Non-unique channels: "%s".', strjoin(sort(chan_names(i_duplicates)), ', '));
        throw(MException('NIRSTORM:NonUniqueChannels', msg));
    end
    
    ChannelMat.Channel = Channels;
    ChannelMat.HeadPoints.Loc = [];
    
    % Read fiducials
    if isfield( jnirs.nirs.probe, 'landmarkLabels')
        n_landmark=size(jnirs.nirs.probe.landmarkPos,1);
        
        for i_landmark=1:n_landmark
            name=strrep(jnirs.nirs.probe.landmarkLabels(:,:,i_landmark),' ','');
            coord=jnirs.nirs.probe.landmarkPos(i_landmark,:);
            switch name
                case 'Nasion'
                    ChannelMat.SCS.NAS = coord;
                    ChannelMat.HeadPoints.Loc(:, end+1) = coord';
                    ChannelMat.HeadPoints.Label{end+1} = name;
                    ChannelMat.HeadPoints.Type{end+1}  = 'CARDINAL';
                case 'LeftEar'
                    ChannelMat.SCS.LPA = coord;
                    ChannelMat.HeadPoints.Loc(:, end+1) = coord';
                    ChannelMat.HeadPoints.Label{end+1} = name;
                    ChannelMat.HeadPoints.Type{end+1}  = 'CARDINAL';
                    
                case 'RightEar'    
                    ChannelMat.SCS.RPA = coord;
                    ChannelMat.HeadPoints.Loc(:, end+1) = coord';
                    ChannelMat.HeadPoints.Label{end+1} = name;
                    ChannelMat.HeadPoints.Type{end+1}  = 'CARDINAL';
                otherwise
                    ChannelMat.HeadPoints.Loc(:, end+1) = coord';
                    ChannelMat.HeadPoints.Label{end+1} = name;
                    ChannelMat.HeadPoints.Type{end+1}  = 'EXTRA';
            end    
        end           
    end    
    
    ChannelMat.Nirs.Wavelengths = wavelengths;
    
    % Read Data 
    data = zeros(nb_channels+nb_aux,nb_time);
    data(1:nb_channels,:)=jnirs.nirs.data.dataTimeSeries';
    for i_aux=1:nb_aux % add auxilary data
        data(nb_channels+i_aux,:)=jnirs.nirs.aux(i_aux).dataTimeSeries';
    end    
    
    %% ===== FILL STRUCTURE =====
    % Initialize returned file structure                    
    DataMat =  db_template('DataMat');                    

    % Add information read from header
    [fPath, fBase, fExt] = bst_fileparts(DataFile);
    DataMat.Comment     = fBase;
    DataMat.filename    = DataFile;
    
    
    DataMat.format      = 'NIRS-BRS';
    DataMat.DataType    = 'recordings';
    DataMat.device      = 'Unknown';
    DataMat.F           = data; 
    DataMat.Time        = time;

    DataMat.channelflag = ones(nb_channels + nb_aux, 1); % GOOD=1; BAD=-1;

end

