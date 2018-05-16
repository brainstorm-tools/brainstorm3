function ChannelMat = in_channel_neuroscan_dat(ChannelFile)
% IN_CHANNEL_NEUROSCAN_DAT:  Read 3D cartesian positions for a set of electrodes from an Neuroscan.dat file.
%
% USAGE:  ChannelMat = in_channel_neuroscan_dat(ChannelFile)
%
% INPUTS: 
%     - ChannelFile : Full path to the file
%
% FORMAT:
%     - One line per point, with format:  "NAME TYPE X Y Z"+ orientation(optional)
%     - Different sensor types: 
%          - 78, 76, 82: Nasion, Left ear, Right ear
%          - 69: Electrode
%          - 32: Extra head point
%          - 50/51/52: MEG/MEG MAG/MEG GRAD
%          - 53/54/55/56/57: ECOG/SEEG/ECG/EOG/EMG
%          - 58/59/60/61:    MEG REF/EEG REF/Stim/Misc
%
%
% EXAMPLE FILE:
%     Nasion	78	-0.183773	11.974301	0.000000 + Orientation for GRAD
%       Left	76	-7.754063	0.000000	-0.000000
%      Right	82	7.754063	-0.000000	0.000000
%        Fp1	69	-2.036996	12.059780	8.107069
%        Fpz	69	1.092457	12.650412	7.939869
%        Fp2	69	4.119890	11.584386	7.605166
%           	32	0.684059	12.889748	4.561315
%           	32	0.703555	12.913220	4.336210
            
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2015
%          Brahim Belaoucha, 2015

% Open file
fid = fopen(ChannelFile, 'r');
if (fid == -1)
    error('Cannot open file.');
end
% Initialize indices structure
iChannel = 1;
iHeadPoint = 1;
% Initialize returned structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Neuroscan channels';

% Read file line by line
while 1
    % Read line
    read_line = fgetl(fid);
    % Empty line: go to next line
    if isempty(read_line)
        continue
    end
    % End of file: stop reading
    if (read_line(1) == -1)
        break
    end
    
    % Scan values
    read_val = textscan(read_line, '%s %s %s %s %s %s %s %s');
    
    % If the name is missing
    if (numel(read_val{5}) == 0) || ~ischar(read_val{5}{1})
        read_val = cat(2, {{''}}, read_val);
    end
    % Get xyz position, and convert from cm to meters
    xyz = [str2double(read_val{3}{1}); str2double(read_val{4}{1}); str2double(read_val{5}{1})] .* 0.01;
    if (length(read_val) >= 8) && ~isempty(read_val{6}) && ~isempty(read_val{7}) && ~isempty(read_val{8})
        Orient = [str2double(read_val{6}{1}); str2double(read_val{7}{1}); str2double(read_val{8}{1})];
    else
        Orient = [];
    end
    % Get the sensor type and name
    chType = read_val{2}{1};
    chName = read_val{1}{1};
    
    % Switch according to the sensor type:
    % Nasion: 78
    if strcmpi(chType, '78') || strcmpi(chName, 'Nasion')
        ChannelMat.SCS.NAS = xyz(:)';
    % Left: 76
    elseif strcmpi(chType, '76') || strcmpi(chName, 'Left')
        ChannelMat.SCS.LPA = xyz(:)';
    % Right: 82
    elseif strcmpi(chType, '82') || strcmpi(chName, 'Right')
        ChannelMat.SCS.RPA = xyz(:)';
    % Electrodes: 69
    elseif any(strcmpi(chType, {'69', '78', '76', '82','50','51','52','53','54','55','56','57','58','59','60'}))
        if any(strcmpi(chType, {'69', '78', '76', '82'}))
            ChannelMat.Channel(iChannel).Type  = 'EEG';
        elseif strcmpi(chType, '50')
            ChannelMat.Channel(iChannel).Type  = 'MEG';
        elseif strcmpi(chType, '51')
            ChannelMat.Channel(iChannel).Type  = 'MEG MAG';
        elseif strcmpi(chType, '52')
            ChannelMat.Channel(iChannel).Type  = 'MEG GRAD';
        elseif strcmpi(chType, '53')
            ChannelMat.Channel(iChannel).Type  = 'ECOG';
        elseif strcmpi(chType, '54')
            ChannelMat.Channel(iChannel).Type  = 'SEEG';
        elseif strcmpi(chType, '55')
            ChannelMat.Channel(iChannel).Type  = 'ECG';
        elseif strcmpi(chType, '56')
            ChannelMat.Channel(iChannel).Type  = 'EOG';
        elseif strcmpi(chType, '57')
            ChannelMat.Channel(iChannel).Type  = 'EMG';
        elseif strcmpi(chType, '58')
            ChannelMat.Channel(iChannel).Type  = 'MEG REF';
        elseif strcmpi(chType, '59')
            ChannelMat.Channel(iChannel).Type  = 'EEG REF';
        elseif strcmpi(chType, '60')
            ChannelMat.Channel(iChannel).Type  = 'Stim';
        elseif strcmpi(chType, '61')
            ChannelMat.Channel(iChannel).Type  = 'Misc';
        end
        ChannelMat.Channel(iChannel).Name    = read_val{1}{1};
        ChannelMat.Channel(iChannel).Loc     = xyz;
        ChannelMat.Channel(iChannel).Orient  = Orient;
        ChannelMat.Channel(iChannel).Comment = '';
        ChannelMat.Channel(iChannel).Weight  = 1;
        iChannel = iChannel + 1;
    
    % Head points: 32
    elseif strcmpi(chType, '32')
        ChannelMat.HeadPoints.Loc(:,iHeadPoint) = xyz;
        ChannelMat.HeadPoints.Type{iHeadPoint}  = 'EXTRA';
        ChannelMat.HeadPoints.Label{iHeadPoint} = iHeadPoint;
        iHeadPoint = iHeadPoint + 1;
    end
end
% Close file
fclose(fid);





