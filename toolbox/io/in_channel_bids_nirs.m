function ChannelMat = in_channel_bids_nirs(ChannelFile)
% IN_CHANNEL_BIDS_NIRS:  Read NIRS channels file from a BIDS _channels.tsv file.
%
% USAGE:  ChannelMat = in_channel_bids_nirs(ChannelFile)
%
% INPUTS: 
%     - ChannelFile : Full path to the .tsv file
            
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
% Authors: Edouard Delaire, 2025

    % Read the TSV file
    tsvValues = in_tsv(ChannelFile, {'name', 'type', 'source', 'detector', 'wavelength_nominal', 'status', 'component'}, 0);
    if isempty(tsvValues) || isempty(tsvValues{1,1})
        disp('BIDS> Error: Invalid _channels.tsv file.');
        ChannelMat = [];
        return;
    end
    
    OptodeFile = strrep(ChannelFile, '_channels.tsv', '_optodes.tsv');
    if exist(OptodeFile, 'file')
        tsvOptodes = in_tsv(OptodeFile, {'name','type', 'x', 'y',	'z', 'template_x', 'template_y', 'template_z'}, 0);
    else
        tsvOptodes = {};
    end

    nChan = size(tsvValues,1);
    
    % Initialize returned structure
    ChannelMat          = db_template('channelmat');
    ChannelMat.Comment  = 'BIDS channels';
    ChannelMat.Channel  = repmat(db_template('channeldesc'), [1, nChan]);
    [ChannelMat.Channel.Loc] = deal([0;0;0]);
    
    isValidChannel = true(1, nChan);

    for iChannel = 1:nChan
        
        channel_type = upper(tsvValues{iChannel,2});
        if any(strcmp(channel_type, {'NIRSCWAMPLITUDE', 'NIRSCWOPTICALDENSITY', 'NIRSCWHBO', 'NIRSCWHBR'}))
            channel_name = parse_name(tsvValues{iChannel,1});
        else
            channel_name = tsvValues{iChannel,1};
        end


        switch(channel_type)
            case {'NIRSCWAMPLITUDE', 'NIRSCWOPTICALDENSITY'}
                ChannelMat.Channel(iChannel).Name   = sprintf('%sWL%d', channel_name, str2double(tsvValues{iChannel,5}));
                ChannelMat.Channel(iChannel).Type   = 'NIRS';
                ChannelMat.Channel(iChannel).Group  = sprintf('WL%d', str2double(tsvValues{iChannel,5}));
                ChannelMat.Channel(iChannel).Weight = 1;
            case {'NIRSCWHBO', 'NIRSCWHBR'}
                ChannelMat.Channel(iChannel).Name   = sprintf('%sHb%s', channel_name, channel_type(end));
                ChannelMat.Channel(iChannel).Type   = 'NIRS';
                ChannelMat.Channel(iChannel).Group  = sprintf('Hb%s', channel_type(end));
                ChannelMat.Channel(iChannel).Weight = 1;
            case {'ACCEL', 'GYRO', 'MAGN'}
                if isempty(tsvValues{iChannel,7})
                    error('Componnent for channel %s is not defnied', channel_name)
                end

                ChannelMat.Channel(iChannel).Name   = sprintf('%s_%s', channel_name, tsvValues{iChannel,7});
                ChannelMat.Channel(iChannel).Type   = 'Misc'; % Is there a better type ?
                ChannelMat.Channel(iChannel).Group  =  [];
                ChannelMat.Channel(iChannel).Weight = 1;
            case {'MISC'}
                ChannelMat.Channel(iChannel).Name   = channel_name;
                ChannelMat.Channel(iChannel).Type   = 'Misc';
                ChannelMat.Channel(iChannel).Group  =  [];
                ChannelMat.Channel(iChannel).Weight = 1;
            otherwise
                isValidChannel(iChannel) = false;
                warning('Unsoprted channel %s with type %s', tsvValues{iChannel,1}, tsvValues{iChannel,2} )
                continue;
        end

        if ~isempty(tsvOptodes)
            ChannelMat.Channel(iChannel).Loc = getOptodesCoordinate(tsvOptodes, tsvValues{iChannel,3}, tsvValues{iChannel,4});
        end 
    end

    ChannelMat.Channel = ChannelMat.Channel(isValidChannel);

end



function chann_name = parse_name(name)

    name                = TxRxtoSD(name);
    tokens_source       = regexp(name,'S([0-9]+)','tokens');
    tokens_detectors    = regexp(name,'D([0-9]+)','tokens');

    if isempty(tokens_source) || isempty(tokens_detectors)
        error('Umable to parse %s', name)
    end

    chann_name = sprintf('S%sD%s', tokens_source{1}{1}, tokens_detectors{1}{1});

end


function channel_name = TxRxtoSD(channel_name)
% Convert channel names from Tx1Rx1WL760 to S1D1WL760
    channel_name = strrep(channel_name, 'Tx','S');
    channel_name = strrep(channel_name, 'Rx','D');
end

function coordinates = getOptodesCoordinate(tsvOptodes, sourceName, detectorName)
    coordinates = [];

    if strcmp(detectorName, 'n/a') || strcmp(sourceName, 'n/a') 
        return;
    end

    % Read optodes coordinate
    iSource = find(strcmp(tsvOptodes(:,1),   sourceName));
    if isempty(iSource) 
        warning('Unable to find source %s in optodes.tsv', sourceName)
        return;
    elseif ~strcmp(tsvOptodes{iSource,2}, 'source')
        warning('%s should be a source but is labelled as a %s in optodes.tsv', sourceName, tsvOptodes{iSource,2});
        return;
    end

    if ~isempty(tsvOptodes{iSource,4}) && ~isempty(tsvOptodes{iSource,5})  && ~isempty(tsvOptodes{iSource,6})
        source_coord = [str2double(tsvOptodes{iSource,4}); str2double(tsvOptodes{iSource,5}); str2double(tsvOptodes{iSource,6})];
    elseif ~isempty(tsvOptodes{iSource,7}) && ~isempty(tsvOptodes{iSource,8})  && ~isempty(tsvOptodes{iSource,9})
        source_coord = [str2double(tsvOptodes{iSource,7}); str2double(tsvOptodes{iSource,8}); str2double(tsvOptodes{iSource,9})];
    else
        warning('No coordinate available for %s in optodes.tsv', sourceName)
        return;
    end

    iDetector = find(strcmp(tsvOptodes(:,1), detectorName));
    if isempty(iDetector) 
        warning('Unable to find detector %s in optodes.tsv', detectorName)
        return;
    elseif ~strcmp(tsvOptodes{iDetector,2}, 'detector')
        warning('%s should be a detector but is labelled as a %s in optodes.tsv', detectorName, tsvOptodes{iSource,2});
        return;
    end

    if ~isempty(tsvOptodes{iDetector,4}) && ~isempty(tsvOptodes{iDetector,5})  && ~isempty(tsvOptodes{iDetector,6})
        detector_coord = [str2double(tsvOptodes{iDetector,4}) ; str2double(tsvOptodes{iDetector,5}); str2double(tsvOptodes{iDetector,6})];
    elseif ~isempty(tsvOptodes{iDetector,7}) && ~isempty(tsvOptodes{iDetector,8})  && ~isempty(tsvOptodes{iDetector,9})
        detector_coord = [str2double(tsvOptodes{iDetector,7}) ; str2double(tsvOptodes{iDetector,8}); str2double(tsvOptodes{iDetector,9})];
    else
        warning('No coordinate available for %s in optodes.tsv', detectorName)
        return;
    end


    coordinates = [source_coord, detector_coord];

end