function ChannelMat = in_channel_neuroscan_asc(ChannelFile)
% IN_CHANNEL_NEUROSCAN_ASC:  Create a pseudo-channel file from a Neuroscan .asc file (for 2D display only).

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
% Authors: Francois Tadel, 2012

% Open file
fid = fopen(ChannelFile, 'r');
if (fid == -1)
    error('Cannot open file.');
end
% Initialize indices structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Neuroscan 2D plot';
ChannelMat.Channel = repmat(db_template('channeldesc'), 0);
iChanWithLoc = [];

% Read file line by line
while 1
    % Read line
    read_line = fgetl(fid);
    % Empty line
    if isempty(read_line)
        continue
    end
    % End of file: stop reading
    if (read_line(1) == -1)
        break
    end
    
    % First character of the line indicates what to do with it
    switch (read_line(1))
        % Comment
        case ';'
            continue;
        % Channel name
        case '#'
            res = textscan(read_line(2:end), '%d %s');
            iChan = res{1};
            ChannelMat.Channel(iChan).Name = res{2}{1};
            if isempty(ChannelMat.Channel(iChan).Loc)
                ChannelMat.Channel(iChan).Loc = [0; 0; 0];
            end
        % Channel location
        case '0'
            res = textscan(read_line(3:end), '%d %f %f %*f %*f');
            iChan = res{1};
            ChannelMat.Channel(iChan).Loc = [-res{3}; -res{2}; 0] ./ 5;
            iChanWithLoc(end+1) = iChan;
        % Autre: skip
        otherwise
            continue;
    end       
end
% Close file
fclose(fid);
% Set all the channels stypes
[ChannelMat.Channel.Type]   = deal('EEG');
[ChannelMat.Channel.Weight] = deal(1);

% Process channel locations
if ~isempty(iChanWithLoc)
    % Spherize positions of the electrodes
    chLoc = [ChannelMat.Channel(iChanWithLoc).Loc];
    center = mean(chLoc, 2);
    chLoc = bst_bsxfun(@minus, chLoc, center);
    r = sqrt(sum(chLoc.^2));
    chLoc(3,:) = sqrt(max(r).^2 - r.^2) + .05;
    % Scale to 9cm
    % [th, phi, r] = cart2sph(chLoc(1,:), chLoc(2,:), chLoc(3,:));
    % [chLoc(1,:), chLoc(2,:), chLoc(3,:)] = sph2cart(th, phi, .9);
    % Update the channels positions
    for i = 1:length(iChanWithLoc)
        ChannelMat.Channel(iChanWithLoc(i)).Loc = chLoc(:,i);
    end
end






