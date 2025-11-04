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
    ChannelMat = db_template('channelmat');
    ChannelMat.Comment = 'BIDS channels';
    ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChan]);
    [ChannelMat.Channel.Loc] = deal([0;0;0]);
    
    for iChannel = 1:nChan
        ChannelMat.Channel(iChannel).Name  = sprintf('%s%sWL%d',tsvValues{iChannel,3}, tsvValues{iChannel,4}, str2double(tsvValues{iChannel,5}));
        ChannelMat.Channel(iChannel).Type  = 'NIRS';
        ChannelMat.Channel(iChannel).Group = sprintf('WL%d', str2double(tsvValues{iChannel,5}));
        ChannelMat.Channel(iChannel).Weight = 1;
    end

end





