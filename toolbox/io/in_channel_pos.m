function ChannelMat = in_channel_pos(ChannelFile)
% IN_CHANNEL_POS:  Read 3D positions from a Polhemus .pos CTF-compatible file.

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
% Authors: Francois Tadel, Elizabeth Bock, 2012-2013

% Initialize output structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Polhemus';
ChannelMat.Channel = repmat(db_template('channeldesc'), 0);

% Open file
fid = fopen(ChannelFile, 'r');
% Loop to read all lines
while 1
    % Read next line
    s = fgetl(fid);
    if isempty(s)
        continue;
    end
    % Stop conditions
    if isequal(s, -1)
        break;
    end
    % Split line in blocks, to get the different values/names
    ss = str_split(s, [' ,' 9]);
    % Switch based on the number of elements
    switch length(ss)
        case {0, 1, 2}
            % Ignore
            continue;
        case 3
            % X Y Z => Headpoint
            ChannelMat.HeadPoints.Loc(:,end+1) = cellfun(@str2num, ss(1:3))' ./ 100;
            ChannelMat.HeadPoints.Label{end+1} = 'EXTRA';
            ChannelMat.HeadPoints.Type{end+1}  = 'EXTRA';
        case {4,7}
            % Name X Y Z ... => Headpoint or fiducial
            if ~isnan(str2double(ss{1}))
                ChannelMat.HeadPoints.Label{end+1} = 'EXTRA';
                ChannelMat.HeadPoints.Type{end+1}  = 'EXTRA';
            else
                ChannelMat.HeadPoints.Label{end+1} = ss{1};
                if ~isempty(strfind(ss{1},'HPI')) || ~isempty(strfind(ss{1},'HLC'))
                    ChannelMat.HeadPoints.Type{end+1} = 'HPI';
                else
                    ChannelMat.HeadPoints.Type{end+1} = 'CARDINAL';
                end
            end
            ChannelMat.HeadPoints.Loc(:,end+1) = cellfun(@str2num, ss(2:4))' ./ 100;
        case 5
            % Indice Name X Y Z => EEG
            i = length(ChannelMat.Channel) + 1;
            ChannelMat.Channel(i).Type    = 'EEG';
            ChannelMat.Channel(i).Name    = ss{2};
            ChannelMat.Channel(i).Loc     = cellfun(@str2num, ss(3:5))' ./ 100;
            ChannelMat.Channel(i).Orient  = [];
            ChannelMat.Channel(i).Comment = '';
            ChannelMat.Channel(i).Weight  = 1;
        otherwise
            disp(['IN_CHANNEL> Warning: Line with invalid number of elements: "' s '"']);
            continue;
    end
end
% Close file
fclose(fid);

% Remove the duplicate positions: HPI and Fiducials are also in the head points
iFid   = find(strcmpi(ChannelMat.HeadPoints.Type, 'CARDINAL') | strcmpi(ChannelMat.HeadPoints.Type, 'HPI'));
iExtra = find(strcmpi(ChannelMat.HeadPoints.Type, 'EXTRA'));
if ~isempty(iFid) && ~isempty(iExtra)
    Loc = ChannelMat.HeadPoints.Loc;
    iRemove = [];
    for i = 1:length(iFid)
        iRemove = [iRemove, find((abs(Loc(1,iFid(i))-Loc(1,iExtra))<1e-5) & (abs(Loc(2,iFid(i))-Loc(2,iExtra))<1e-5) & (abs(Loc(2,iFid(i))-Loc(2,iExtra)<1e-5)))];
    end
    if ~isempty(iRemove)
        ChannelMat.HeadPoints.Loc(:,iExtra(iRemove)) = [];
        ChannelMat.HeadPoints.Type(iExtra(iRemove))  = [];
        ChannelMat.HeadPoints.Label(iExtra(iRemove)) = [];
    end
end




