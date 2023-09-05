function ChannelMat = in_channel_eeglab_set(ChannelFile, isFixUnits)
% IN_CHANNEL_EEGLAB_SET:  Read 3D cartesian positions from an .SET EEGLAB file.
%
% USAGE:  ChannelMat = in_channel_eeglab_set(ChannelFile, isFixUnits=[ask])
%         ChannelMat = in_channel_eeglab_set(SetFileMat,  isFixUnits=[ask])
%
% INPUTS: 
%     - ChannelFile  : Full path to the file (either .ela or .eps file)
%     - SetFileMat   : Structure contained in an EEGLAB .set file 
%     - isFixUnit    : If 1: If the positions of the electrodes are normalized, try to convert them to something acceptable by brainstorm
%                            Otherwise, tries to convert the distance units to meters automatically
%                      If 0, does not apply  any correction
%                      If [], ask for use input

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
% Authors: Francois Tadel, 2009-2017

% Parse inputs
if (nargin < 2) || isempty(isFixUnits)
    isFixUnits = [];
end
% Load initial file (Matlab .mat format)
if ischar(ChannelFile)
    SetFileMat = load(ChannelFile, '-mat');
else
    SetFileMat = ChannelFile;
    ChannelFile = '';
end
% Convert Channel locations to Brainstorm format
if isfield(SetFileMat.EEG, 'chanlocs') && ~isempty(SetFileMat.EEG.chanlocs)
    % Check coordinates sytem
    isLoc = isfield(SetFileMat.EEG.chanlocs(1), 'X');
    if isLoc
        isNormalizedCs = (max([SetFileMat.EEG.chanlocs.X]) <= 1);
        if isempty(isNormalizedCs)
            isNormalizedCs = 0;
        elseif isNormalizedCs && isempty(isFixUnits)
            isFixUnits = java_dialog('confirm', ['The EEGLAB file you selected contains 3D electrodes positions, but they' 10 ...
                                               'seem to be spherical projections in a normalized coordinates system.' 10 ...
                                               'Brainstorm needs real 3D positions, you may need to import them separately.' 10 10 ...
                                               'Would you like Brainstorm to try to convert these positions ?'], 'EEGLAB electrodes positions');
        end
    end
    % Initialize returned structure
    nbChannels = SetFileMat.EEG.nbchan;
    ChannelMat = db_template('channelmat');
    ChannelMat.Comment = 'EEGLAB channels';

    % Copy channel data
    for iChan = 1:nbChannels
        % Electrode type and name
        if isfield(SetFileMat.EEG.chanlocs(iChan), 'type') && ~isempty(SetFileMat.EEG.chanlocs(iChan).type) && ischar(SetFileMat.EEG.chanlocs(iChan).type) && ismember(SetFileMat.EEG.chanlocs(iChan).type(1), 'abcdefghijklmnopqrstuvwyzABCDEFGHIJKLMNOPQRSTUVWXYZ')
            ChannelMat.Channel(iChan).Type = upper(SetFileMat.EEG.chanlocs(iChan).type);
        else
            ChannelMat.Channel(iChan).Type = 'EEG';
        end
        ChannelMat.Channel(iChan).Name = SetFileMat.EEG.chanlocs(iChan).labels;
        % Electrode location
        if isLoc
            if isempty(SetFileMat.EEG.chanlocs(iChan).X) || isempty(SetFileMat.EEG.chanlocs(iChan).Y) || isempty(SetFileMat.EEG.chanlocs(iChan).Z)
                ChannelMat.Channel(iChan).Loc = [];
                if strcmpi(ChannelMat.Channel(iChan).Type, 'EEG') && ~isempty([SetFileMat.EEG.chanlocs.X])
                    ChannelMat.Channel(iChan).Type = 'Misc';
                end
            elseif ~isNormalizedCs
                ChannelMat.Channel(iChan).Loc = [SetFileMat.EEG.chanlocs(iChan).X; ...
                                                 SetFileMat.EEG.chanlocs(iChan).Y; ...
                                                 SetFileMat.EEG.chanlocs(iChan).Z] ./ 1000;
            elseif isFixUnits
                ChannelMat.Channel(iChan).Loc = [SetFileMat.EEG.chanlocs(iChan).X / 9.4 + 0.007; ...
                                                 SetFileMat.EEG.chanlocs(iChan).Y / 11.5; ...
                                                 SetFileMat.EEG.chanlocs(iChan).Z / 8.7 + 0.042];
            else
                ChannelMat.Channel(iChan).Loc = [SetFileMat.EEG.chanlocs(iChan).X; ...
                                                 SetFileMat.EEG.chanlocs(iChan).Y; ...
                                                 SetFileMat.EEG.chanlocs(iChan).Z] / 10;
            end
        else
            ChannelMat.Channel(iChan).Loc = [];
        end
        ChannelMat.Channel(iChan).Orient  = [];
        ChannelMat.Channel(iChan).Comment = '';
        ChannelMat.Channel(iChan).Weight  = 1;
    end
    
    % Check distance units
    if isLoc && ~isNormalizedCs && ~isequal(isFixUnits, 0)
        if isempty(isFixUnits)
            isConfirmFix = 1;
        else
            isConfirmFix = 0;
        end
        ChannelMat = channel_fixunits(ChannelMat, 'mm', isConfirmFix);
    end
else
    ChannelMat = [];
end





