function ChannelMat = in_channel_bids_nirs(ChannelFile)
% IN_CHANNEL_BIDS_nirs:  Read NIRS channels file from a BIDS _channels.tsv file.
%
% USAGE:  ChannelMat = in_channel_bids(ChannelFile)
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
    tsvValues = in_tsv(ChannelFile, {'name','type','source','detector','wavelength_nominal', 'status'});
    if isempty(tsvValues) || isempty(tsvValues{1,1})
        disp('BIDS> Error: Invalid _channels.tsv file.');
        ChannelMat = [];
        return;
    end
    nChan = size(tsvValues,1);
    
    % Initialize returned structure
    ChannelMat          = db_template('channelmat');
    ChannelMat.Comment  = 'BIDS channels';
    ChannelMat.Channel  = repmat(db_template('channeldesc'), [1, nChan]);
    [ChannelMat.Channel.Loc] = deal([0;0;0]);
    
    isValidChannel = true(1, nChan);

    for iChannel = 1:nChan

        channel_name = parse_name(tsvValues{iChannel,1});
        channel_type = upper(tsvValues{iChannel,2});

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
            otherwise
                isValidChannel(iChannel) = false;
                warning('Unsoprted channel %s with type %s', tsvValues{iChannel,1}, tsvValues{iChannel,2} )
                continue;
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


