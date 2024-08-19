function ChannelMat = in_channel_pos(ChannelFile)
% IN_CHANNEL_POS:  Read 3D positions from a Polhemus .pos CTF-compatible file.
%
% Coordinates are transformed to either "Native" CTF head-coil-based coordinates if digitized HPI
% are present, or to SCS if HPI are not found but anatomical fiducials are present.  If neither sets
% of fiducials are found, raw coordinates are kept and Brainstorm assumes they are in "Native"
% coordinates, as was previously done.

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
% Authors: Francois Tadel, Elizabeth Bock, 2012-2013, Marc Lalancette 2024

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
            if ~isnan(str2double(ss{1})) || strcmpi(ss{1}, 'EXTRA')
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
            % Index Name X Y Z => EEG
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
        iRemove = [iRemove, find((abs(Loc(1,iFid(i))-Loc(1,iExtra))<1e-5) & (abs(Loc(2,iFid(i))-Loc(2,iExtra))<1e-5) & (abs(Loc(2,iFid(i))-Loc(2,iExtra))<1e-5))];
    end
    if ~isempty(iRemove)
        ChannelMat.HeadPoints.Loc(:,iExtra(iRemove)) = [];
        ChannelMat.HeadPoints.Type(iExtra(iRemove))  = [];
        ChannelMat.HeadPoints.Label(iExtra(iRemove)) = [];
    end
end

% Transform coordinates to head-coil-based system if possible, or anatomical-based system. This is
% done during digitization if it's done with Brainstorm, but doing it here will make this compatible
% with other files, and importantly allow simple manual fixes (e.g. swapping mislabeled coils)
% before importing.
% Keep backup in case we get an error, so it can still at least work as before.
ChannelBackup = ChannelMat;
try
    if ~isempty(iFid)
        % Are the MEG head coils present?
        % Get the three fiducials in the head points
        iNas = find(strcmpi(ChannelMat.HeadPoints.Label, 'HPI-N'));
        iLpa = find(strcmpi(ChannelMat.HeadPoints.Label, 'HPI-L'));
        iRpa = find(strcmpi(ChannelMat.HeadPoints.Label, 'HPI-R'));
        iCardinal = find(strcmpi(ChannelMat.HeadPoints.Type, 'CARDINAL'));
        if ~isempty(iNas) && ~isempty(iLpa) && ~isempty(iRpa)
            % Hack: rename anat fids, rename HPI to anat fids to reuse ususal realign functions. Then
            % restore names.
            RealPointLabels = ChannelMat.HeadPoints.Label;
            for iP = iCardinal
                ChannelMat.HeadPoints.Label{iP} = ['Tmp-' ChannelMat.HeadPoints.Label(iCardinal)];
            end
            for iP = iNas
                ChannelMat.HeadPoints.Label{iP} = 'NAS';
            end
            for iP = iLpa
                ChannelMat.HeadPoints.Label{iP} = 'LPA';
            end
            for iP = iRpa
                ChannelMat.HeadPoints.Label{iP} = 'RPA';
            end
            % Transform to coil-based "Native" CTF coordinates
            ChannelMat = channel_detect_type(ChannelMat, 1);
            % Restore labels
            if numel(RealPointLabels) ~= numel(ChannelMat.HeadPoints.Label)
                % channel_detect_type did something unexpected and changed number of points.
                error('Unexpected change in number of head points.');
            end
            ChannelMat.HeadPoints.Label = RealPointLabels;
            % Correct misleading transformation name.
            iTrans = find(strcmpi(ChannelMat.TransfMegLabels, 'Native=>Brainstorm/CTF'));
            if numel(iTrans) ~= 1
                error('Unexpected transformation(s).')
            end
            % And for EEG
            ChannelMat.TransfMegLabels{iTrans} = 'RawPoints=>Native';
            iTrans = find(strcmpi(ChannelMat.TransfEegLabels, 'Native=>Brainstorm/CTF'));
            if numel(iTrans) ~= 1
                error('Unexpected transformation(s).')
            end
            ChannelMat.TransfEegLabels{iTrans} = 'RawPoints=>Native';
        elseif numel(iCardinal) >= 3
            % Transform to SCS coordinates
            ChannelMat = channel_detect_type(ChannelMat, 1);
            % Native=>Brainstorm/CTF already added.
        end
    end
catch ME
    disp('BST> Warning: Unable to ensure head points are in "native" coordinates.');
    %     rethrow(ME);
    disp(['  ' ME.message]);
    ChannelMat = ChannelBackup;
end

