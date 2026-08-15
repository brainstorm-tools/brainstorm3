function [ChannelMat, ChannelStatus] = in_channel_bids_nirs(ChannelFile, OptodeFile)
% IN_CHANNEL_BIDS_NIRS:  Read NIRS channels file from a BIDS _channels.tsv file.
%
% USAGE:  ChannelMat = in_channel_bids_nirs(ChannelFile)
%
% INPUTS: 
%     - ChannelFile : Full path to the _channels.tsv file
%     - OptodeFile : Full path to the _optodes.tsv file
% OUTPUTS:
%    - ChannelMat: Brainstorm matrix file structure
%    - ChannelStatus : Vector (1xnChannel): 
%       ChannelStatus(i) == 1 if the channel i is good, -1 otherwise.

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
% Authors: Edouard Delaire, 2025-2026

    if nargin < 2 || isempty(OptodeFile)
        OptodeFile = find_optodes_file(ChannelFile);
    end

    % Read the TSV file
    [channelValue, ~, channelIndex] = in_tsv(ChannelFile, {'name', 'type', 'source', 'detector', 'wavelength_nominal', 'status', 'component'}, 0);
    if isempty(channelValue) || isempty(channelValue{1, channelIndex.name})
        disp('BIDS> Error: Invalid _channels.tsv file.');
        ChannelMat = []; ChannelStatus = [];
        return;
    end
    
    if ~isempty(OptodeFile) && exist(OptodeFile, 'file')
        [tsvOptodes, ~, OptodesIndex] = in_tsv(OptodeFile, {'name', 'type', 'x', 'y', 'z', 'template_x', 'template_y', 'template_z'});
    else
        tsvOptodes = {};
    end

    nChan = size(channelValue,1);
    ChannelStatus = ones(1, nChan);

    % Initialize returned structure
    ChannelMat          = db_template('channelmat');
    ChannelMat.Comment  = 'BIDS channels';
    ChannelMat.Channel  = repmat(db_template('channeldesc'), [1, nChan]);
    [ChannelMat.Channel.Loc] = deal([0;0;0]);
    
    isValidChannel = true(1, nChan);

    for iChannel = 1:nChan
        
        channel_type = upper(channelValue{iChannel, channelIndex.type});
        if any(strcmp(channel_type, {'NIRSCWAMPLITUDE', 'NIRSCWOPTICALDENSITY', 'NIRSCWHBO', 'NIRSCWHBR'}))
            channel_name = parse_name(channelValue{iChannel, channelIndex.name});
        else
            channel_name = channelValue{iChannel, channelIndex.name};
        end

        switch(channel_type)
            case {'NIRSCWAMPLITUDE', 'NIRSCWOPTICALDENSITY'}
                wl = round(str2double(channelValue{iChannel, channelIndex.wavelength_nominal}));
                ChannelMat.Channel(iChannel).Name   = sprintf('%sWL%d', channel_name, wl);
                ChannelMat.Channel(iChannel).Type   = 'NIRS';
                ChannelMat.Channel(iChannel).Group  = sprintf('WL%d', wl);
                ChannelMat.Channel(iChannel).Weight = 1;
            case {'NIRSCWHBO', 'NIRSCWHBR'}
                ChannelMat.Channel(iChannel).Name   = sprintf('%sHb%s', channel_name, channel_type(end));
                ChannelMat.Channel(iChannel).Type   = 'NIRS';
                ChannelMat.Channel(iChannel).Group  = sprintf('Hb%s', channel_type(end));
                ChannelMat.Channel(iChannel).Weight = 1;
            case {'ACCEL', 'GYRO', 'MAGN'}
                if isempty(channelValue{iChannel,7})
                    error('Componnent for channel %s is not defnied', channel_name)
                end

                ChannelMat.Channel(iChannel).Name   = sprintf('%s_%s', channel_name, channelValue{iChannel, channelIndex.component});
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
                warning('Unsoprted channel %s with type %s', channelValue{iChannel, channelIndex.name}, channelValue{iChannel, channelIndex.type} )
                continue;
        end

        if ~isempty(channelValue{iChannel, channelIndex.status}) && strcmpi(channelValue{iChannel, channelIndex.status}, 'bad')
            ChannelStatus(iChannel) = -1;
        end


        if ~isempty(tsvOptodes)
            ChannelMat.Channel(iChannel).Loc = getOptodesCoordinate(OptodesIndex, tsvOptodes, channelValue{iChannel, channelIndex.source}, channelValue{iChannel, channelIndex.detector});
        end 
    end

    % Only keep supported channels
    ChannelMat.Channel  = ChannelMat.Channel(isValidChannel);
    ChannelStatus       = ChannelStatus(isValidChannel);

end

function optodes_path = find_optodes_file(channels_path)
    % FIND_OPTODES_FILE Given a BIDS channels.tsv path, find the matching
    % optodes.tsv file.
    %
    % See https://bids-specification.readthedocs.io/en/stable/modality-specific-files/near-infrared-spectroscopy.html#nirs-recording-data

    [folder, name, ~] = fileparts(channels_path); 
    optodes_path = file_find(folder, '*_optodes.tsv', 1, 0);
    
    % If there is no ambiguity, we can return the file
    if length(optodes_path) <= 1
        optodes_path = optodes_path{1};
        return
    end

    error('Todo');

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

function coordinates = getOptodesCoordinate(OptodesIndex, tsvOptodes, sourceName, detectorName)
    coordinates = [];

    if strcmp(detectorName, 'n/a') || strcmp(sourceName, 'n/a') 
        return;
    end

    % Read optodes coordinate
    iSource = find(strcmp(tsvOptodes(:,  OptodesIndex.name),   sourceName));
    if isempty(iSource) 
        warning('Unable to find source %s in optodes.tsv', sourceName)
        return;
    elseif ~strcmp(tsvOptodes{iSource, OptodesIndex.type}, 'source')
        warning('%s should be a source but is labelled as a %s in optodes.tsv', sourceName, tsvOptodes{iSource,2});
        return;
    end

    if ~isempty(tsvOptodes{iSource, OptodesIndex.x}) && ~isempty(tsvOptodes{iSource, OptodesIndex.y})  && ~isempty(tsvOptodes{iSource,OptodesIndex.z})
        source_coord = [str2double(tsvOptodes{iSource, OptodesIndex.x}); str2double(tsvOptodes{iSource, OptodesIndex.y}); str2double(tsvOptodes{iSource, OptodesIndex.z})];
    elseif ~isempty(tsvOptodes{iSource, OptodesIndex.template_x}) && ~isempty(tsvOptodes{iSource, OptodesIndex.template_y})  && ~isempty(tsvOptodes{iSource, OptodesIndex.template_z})
        source_coord = [str2double(tsvOptodes{iSource, OptodesIndex.template_x}); str2double(tsvOptodes{iSource, OptodesIndex.template_y}); str2double(tsvOptodes{iSource, OptodesIndex.template_z})];
    else
        warning('No coordinate available for %s in optodes.tsv', sourceName)
        return;
    end

    iDetector = find(strcmp(tsvOptodes(:, OptodesIndex.name), detectorName));
    if isempty(iDetector) 
        warning('Unable to find detector %s in optodes.tsv', detectorName)
        return;
    elseif ~strcmp(tsvOptodes{iDetector, OptodesIndex.type}, 'detector')
        warning('%s should be a detector but is labelled as a %s in optodes.tsv', detectorName, tsvOptodes{iSource, OptodesIndex.type});
        return;
    end

    if ~isempty(tsvOptodes{iDetector, OptodesIndex.x}) && ~isempty(tsvOptodes{iDetector, OptodesIndex.y})  && ~isempty(tsvOptodes{iDetector, OptodesIndex.z})
        detector_coord = [str2double(tsvOptodes{iDetector, OptodesIndex.x}) ; str2double(tsvOptodes{iDetector, OptodesIndex.y}); str2double(tsvOptodes{iDetector, OptodesIndex.z})];
    elseif ~isempty(tsvOptodes{iDetector,OptodesIndex.template_x}) && ~isempty(tsvOptodes{iDetector, OptodesIndex.template_y})  && ~isempty(tsvOptodes{iDetector, OptodesIndex.template_z})
        detector_coord = [str2double(tsvOptodes{iDetector, OptodesIndex.template_x}) ; str2double(tsvOptodes{iDetector, OptodesIndex.template_y}); str2double(tsvOptodes{iDetector, OptodesIndex.template_z})];
    else
        warning('No coordinate available for %s in optodes.tsv', detectorName)
        return;
    end


    coordinates = [source_coord, detector_coord];

end