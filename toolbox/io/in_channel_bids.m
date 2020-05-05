function ChannelMat = in_channel_bids(ChannelFile, factor)
% IN_CHANNEL_BIDS:  Read 3D cartesian positions from a BIDS _electrodes.tsv file.
%
% USAGE:  ChannelMat = in_channel_bids(ChannelFile, posUnits)
%
% INPUTS: 
%     - ChannelFile : Full path to the .tsv file
%     - factor      : Scaling factor to apply to the electrode positions
            
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
% Authors: Francois Tadel, 2018

% Read the TSV file
tsvValues = in_tsv(ChannelFile, {'name', 'x', 'y', 'z', 'group', 'type'});
if isempty(tsvValues) || isempty(tsvValues{1,1})
    disp('BIDS> Error: Invalid _electrodes.tsv file.');
    ChannelMat = [];
    return;
end
nChan = size(tsvValues,1);

% Initialize returned structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'BIDS channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChan]);
[ChannelMat.Channel.Loc] = deal([0;0;0]);
% Loop on all the channels
for iChan = 1:nChan
    % Name
    if ~isempty(tsvValues{iChan,1})
        ChannelMat.Channel(iChan).Name = tsvValues{iChan,1};
    else
        ChannelMat.Channel(iChan).Name = sprintf('E%03d', iChan);
    end
    % Loc
    if ~isempty(tsvValues{iChan,2}) && ~isempty(tsvValues{iChan,3}) && ~isempty(tsvValues{iChan,4}) && ~isempty(str2num(tsvValues{iChan,2})) && ~isempty(str2num(tsvValues{iChan,3})) && ~isempty(str2num(tsvValues{iChan,4}))
        ChannelMat.Channel(iChan).Loc = [str2num(tsvValues{iChan,2}); str2num(tsvValues{iChan,3}); str2num(tsvValues{iChan,4})] .* factor;
    end
    % Group
    if ~isempty(tsvValues{iChan,5})
        ChannelMat.Channel(iChan).Group = tsvValues{iChan,5};
    end
    % Type
    chType = tsvValues{iChan,6};
    if isequal(chType, 'depth')
        ChannelMat.Channel(iChan).Type = 'SEEG';
    elseif isequal(chType, 'grid') || isequal(chType, 'strip')
        ChannelMat.Channel(iChan).Type = 'ECOG';
    elseif isequal(chType, 'grid')
        ChannelMat.Channel(iChan).Type = 'ECOG';
    elseif ~isempty(strfind(ChannelFile, '/ieeg/')) || ~isempty(strfind(ChannelFile, '\\ieeg\\'))
        ChannelMat.Channel(iChan).Type = 'SEEG';
    else 
        ChannelMat.Channel(iChan).Type = 'EEG';
    end
end




