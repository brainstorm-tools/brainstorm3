function ChannelMat = in_channel_brainvision(ChannelFile)
% IN_CHANNEL_BVEF:  Read 3D positions from a BrainVision electrode file .bvef/.bvel/.txt file.

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
% Authors: Francois Tadel, 2015


% ===== GET FILE FORMAT =====
% Open file
fid = fopen(ChannelFile, 'rt');
% Read first characters
magicStr = fread(fid, [1 12], '*char');
% Close file
fclose(fid);
% XML files start with "<?xml"
isXml = ~isempty(strfind(magicStr, '<?xml'));

% ===== XML FILE =====
if isXml
    % Read XML pos file
    xml = in_xml(ChannelFile);
    % BVEF: xml.Electrodes.Electrode[]
    if isfield(xml, 'Electrodes')
        xmlElecList = xml.Electrodes.Electrode;
        Comment = 'BrainVision';
    % BVCT: xml.CapTrakElectrodeList.CapTrakElectrode
    elseif isfield(xml, 'BrainVisionCapTrakFileV1')
        xmlElecList = xml.BrainVisionCapTrakFileV1.CapTrakElectrodeList.CapTrakElectrode;
        Comment = 'CapTrak';
    else
        error('Invalid file format');
    end

    % Get electrodes names
    Names = [xmlElecList.Name];
    Names = {Names.text}';
    % Cartesian coordinates
    if isfield(xmlElecList, 'X') && isfield(xmlElecList, 'Y') && isfield(xmlElecList, 'Z')
        Xpos = [xmlElecList.X];
        Ypos = [xmlElecList.Y];
        Zpos = [xmlElecList.Z];
        XYZ = [cellfun(@str2num, {Xpos.text}); cellfun(@str2num, {Ypos.text}); cellfun(@str2num, {Zpos.text})] ./ 1000;
    % Spherical coordinates
    elseif isfield(xmlElecList, 'Theta') && isfield(xmlElecList, 'Phi')
        Phi    = [xmlElecList.Phi];
        Theta  = [xmlElecList.Theta];
        Radius = [xmlElecList.Radius];
        Phi    = cellfun(@str2num, {Phi.text});
        Theta  = cellfun(@str2num, {Theta.text});
        Radius = cellfun(@str2num, {Radius.text});
        % Spherical radius: Use default radius of the head instead (8.75cm)
        if (Radius == 1)
            Radius = 0.0875 .* ones(size(Theta));
        else
            Radius = Radius ./ 1000;
        end
        % Convert Spherical(degrees) => Spherical(radians) => Cartesian
        Phi   = (180 + Phi) ./ 180 * pi;
        Theta = (90 - Theta) ./ 180 * pi;
        [XYZ(2,:),XYZ(1,:),XYZ(3,:)] = sph2cart(Phi, Theta, Radius);
        XYZ(3,:) = XYZ(3,:) + .05;
        XYZ(1,:) = -XYZ(1,:);
        %XYZ(2,:) = -XYZ(2,:);
    else
        error('Invalid file format.');
    end
    
    % Fill channels structure
    ChannelMat = db_template('channelmat');
    ChannelMat.Comment = Comment;
    ChannelMat.Channel = repmat(db_template('channeldesc'), 1, length(Names));
    for i = 1:length(Names)
        ChannelMat.Channel(i).Type   = 'EEG';
        ChannelMat.Channel(i).Name   = Names{i};
        ChannelMat.Channel(i).Loc    = XYZ(:,i);
        ChannelMat.Channel(i).Weight = 1;
    end

% ===== TEXT FILE =====
else
    % Initialize output structure
    ChannelMat = db_template('channelmat');
    ChannelMat.Comment = 'BrainVision';
    ChannelMat.Channel = repmat(db_template('channeldesc'), 0);

    % Open file
    fid = fopen(ChannelFile, 'r');
    % Loop to read all lines
    isBlockPos = 0;
    while 1
        % Read next line
        s = fgetl(fid);
        if isempty(s)
            continue;
        end
        % Stop conditions: EOF
        if isequal(s, -1)
            break;
        % Is block with electrodes positions
        elseif (length(s) > 20) && strcmp(s(1:9), 'Electrode')
            isBlockPos = 1;
            continue;
        % Not reading the positions: next line
        elseif ~isBlockPos
            continue;
        end
        % Split line in blocks, to get the different values/names
        ss = str_split(s, [' ,' 9]);
        if (length(ss) < 4)
            continue;
        end
        % Name X Y Z => EEG
        i = length(ChannelMat.Channel) + 1;
        ChannelMat.Channel(i).Type    = 'EEG';
        ChannelMat.Channel(i).Name    = ss{1};
        ChannelMat.Channel(i).Loc     = cellfun(@str2num, ss(2:4))' ./ 1000;
        ChannelMat.Channel(i).Orient  = [];
        ChannelMat.Channel(i).Comment = '';
        ChannelMat.Channel(i).Weight  = 1;
    end
    % Close file
    fclose(fid);
end


