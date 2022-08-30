function ChannelMats = channel_apply_transf(ChannelFiles, Transf, iChannels, isHeadPoints)
% CHANNEL_APPLY_TRANSF: Apply a transformation matrix to a list of channel files.
% 
% USAGE:  ChannelMats = channel_apply_transf(ChannelFiles, Transf, iChannels=[all], isHeadPoints=1)
%         ChannelMats = channel_apply_transf(ChannelMats,  Transf, iChannels=[all], isHeadPoints=1)
%
% INPUT:
%     - ChannelFiles : List of channel files to process (string or cell array of strings)
%     - Transf       : [4x4] transformation matrix to apply to the sensors
%                      or function handle that converts a set of coordinates [Nx3]
%     - iChannels    : List of sensor indices to update
%     - isHeadPoints : Update the digitized head points

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
% Authors: Francois Tadel, 2017-2020

% Parse inputs
if (nargin < 4) || isempty(isHeadPoints)
    isHeadPoints = 1;
end
if (nargin < 3) || isempty(iChannels)
    iChannels = [];
end
if ~iscell(ChannelFiles)
    ChannelFiles = {ChannelFiles};
end
% Output variable
ChannelMats = {};
% Get the transformation rotation and translation
if isnumeric(Transf)
    R = Transf(1:3,1:3);
    T = Transf(1:3,4);
    Transf = @(Loc)(R * Loc + T * ones(1, size(Loc,2)));
else
    R = [];
end

% Loop on input files
for iFile = 1:length(ChannelFiles)
    % Load channel file
    if ischar(ChannelFiles{iFile})
        ChannelMat = in_bst_channel(ChannelFiles{iFile});
        isSave = 1;
    else
        ChannelMat = ChannelFiles{iFile};
        isSave = 0;
    end
    % Get sensor types
    iMeg  = sort([good_channel(ChannelMat.Channel, [], 'MEG'), good_channel(ChannelMat.Channel, [], 'MEG REF')]);
    iNirs = good_channel(ChannelMat.Channel, [], 'NIRS');
    iEeg  = sort([good_channel(ChannelMat.Channel, [], 'EEG'), good_channel(ChannelMat.Channel, [], 'SEEG'), good_channel(ChannelMat.Channel, [], 'ECOG')]);
    % Default list of channels: all
    if ~isempty(iChannels)
        iChan = iChannels;
        iMeg  = intersect(iMeg,  iChannels);
        iNirs = intersect(iNirs, iChannels);
        iEeg  = intersect(iEeg,  iChannels);
    else
        iChan = sort([iMeg, iNirs, iEeg]);
    end
    
    % Apply the rotation and translation to selected sensors
    for i = 1:length(iChan)
        Loc = ChannelMat.Channel(iChan(i)).Loc;
        Orient = ChannelMat.Channel(iChan(i)).Orient;
        % Update location
        if ~isempty(Loc) && ~isequal(Loc, [0;0;0])
            ChannelMat.Channel(iChan(i)).Loc = Transf(Loc);
        end
        % Update orientation
        if ~isempty(Orient) && ~isequal(Orient, [0;0;0])
            if ~isempty(R)
                ChannelMat.Channel(iChan(i)).Orient = R * Orient;
            else
                error('Cannot apply a non-linear transformation to the orientation of MEG sensors.');
            end
        end
    end
    % If needed: transform the digitized head points
    if isHeadPoints && ~isempty(ChannelMat.HeadPoints.Loc)
        ChannelMat.HeadPoints.Loc = Transf(ChannelMat.HeadPoints.Loc);
    end

    % If a TransfMeg field with translations/rotations available
    if ~isempty(iMeg) && ~isempty(R)
        if ~isfield(ChannelMat, 'TransfMeg') || ~iscell(ChannelMat.TransfMeg)
            ChannelMat.TransfMeg = {};
        end
        if ~isfield(ChannelMat, 'TransfMegLabels') || ~iscell(ChannelMat.TransfMegLabels) || (length(ChannelMat.TransfMeg) ~= length(ChannelMat.TransfMegLabels))
            ChannelMat.TransfMegLabels = cell(size(ChannelMat.TransfMeg));
        end
        % Add a new transform to the list
        ChannelMat.TransfMeg{end+1} = Transf;
        ChannelMat.TransfMegLabels{end+1} = 'manual correction';
    end
    % If also need to apply it to the EEG
    if ~isempty(iEeg) && ~isempty(R)
        if ~isfield(ChannelMat, 'TransfEeg') || ~iscell(ChannelMat.TransfEeg)
            ChannelMat.TransfEeg = {};
        end
        if ~isfield(ChannelMat, 'TransfEegLabels') || ~iscell(ChannelMat.TransfEegLabels) || (length(ChannelMat.TransfEeg) ~= length(ChannelMat.TransfEegLabels))
            ChannelMat.TransfEegLabels = cell(size(ChannelMat.TransfEeg));
        end
        ChannelMat.TransfEeg{end+1} = Transf;
        ChannelMat.TransfEegLabels{end+1} = 'manual correction';
    end

    % History: Rotation + translation
    if ~isempty(R)
        ChannelMat = bst_history('add', ChannelMat, 'align', 'Align channels manually:');
        ChannelMat = bst_history('add', ChannelMat, 'transform', sprintf('Rotation: [%1.3f,%1.3f,%1.3f; %1.3f,%1.3f,%1.3f; %1.3f,%1.3f,%1.3f]', R'));
        ChannelMat = bst_history('add', ChannelMat, 'transform', sprintf('Translation: [%1.3f,%1.3f,%1.3f]', T));
    else
        ChannelMat = bst_history('add', ChannelMat, 'align', 'Non-linear transformation');
    end
    % Save new positions
    if isSave
        bst_save(file_fullpath(ChannelFiles{iFile}), ChannelMat, 'v7');
    end
    % Return output variable
    if (nargout >= 1)
        ChannelMats{iFile} = ChannelMat;
    end
end


