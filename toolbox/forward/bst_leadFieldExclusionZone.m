function hmwExclusion = bst_leadFieldExclusionZone(HeadmodelFile, mod)
% BST_LEADFIELDEXCLUSIONZONE: Remove the LFs and the sources within the ExclusionZone.
%
% USAGE:  hmwExclusion = bst_leadFieldExclusionZone(HeadmodelFiles, mod)
% INPUTS:
%    - HeadmodelFiles : Absolute path to the headmodel file
%    - mod : Modality [EEG, sEEG, Ecog, MEG]

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
% Authors: Takfarinas Medani, Yash Shashank Vakilna, 2024


%% ===== Leadfield exclusion zone =====
% Ask user the distance of the exclusion zone
exclusionDistance = java_dialog('input', ['Define the exclusion zone around the ' mod ' sensors.' 10 10 ...
    'Warning: Applying this approach will remove the leadfield vectors located near the sensors.' 10 ...
    'This method also remove the sources located in the exlusion' 10 ...
    'The exclusion zone is defined by the distance from the sensors to the sources.' 10 ...
    'Do not apply to surface grid: This approach is working only for volum sources.' 10 10 ...
    'Exclusion distance(mm):'], ...
    'Leadfield Exclusion Zone', [], num2str(0));
% Read user input
exclusionDistance = str2double(exclusionDistance);
% Conversion to mm
exclusionDistance = exclusionDistance/1e3;
if exclusionDistance == 0
    bst_error('You must define a value greater than zero.', 'Leadfield Exclusion Zone', 0);
    return;
end

% Start the progress bar
bst_progress('start', 'Leadfield Exclusion Zone', 'Loading Leadfield...');
% Get study description
[sStudy, iStudy, ~] = bst_get('HeadModelFile', HeadmodelFile{1});
% Load lead field matrix
HeadmodelMat = in_bst_headmodel(HeadmodelFile{1});
% Load channel file
ChannelMat = in_bst_channel(sStudy.Channel.FileName, 'Channel');
% Apply the exclusion zone
hmwExclusion = create_exclusion_zone(HeadmodelMat, ChannelMat, exclusionDistance, mod);
if isempty(hmwExclusion)
    bst_progress('stop');
    bst_error('There is nothing to remove within this zone.', 'Leadfield Exclusion Zone', 0);
    return;
end
hmwExclusion.Comment = char(hmwExclusion.Comment);
% Add history
hmwExclusion = bst_history('add', hmwExclusion, 'apply exclusion zone', [num2str(1e3*exclusionDistance) 'mm']);
% Add to database
db_add(iStudy, hmwExclusion);
% Close progress bar
bst_progress('stop');
end

function leadstructwExclusion = create_exclusion_zone(head_model, ch_struct, exclusion_radius_m, mod)
% Computes the exclusion zone in the head_model for volumetric grid, based on the coordinates
% in ch_struct and exclusion_radius_m
chtbl = struct2table(ch_struct.Channel); 
isChannel = chtbl.Type; isChannel = strcmpi(isChannel, mod);
seeg_pos = cell2mat(chtbl.Loc(isChannel)')'; 
grid = head_model.GridLoc;
all_bad = identify_bad(grid, seeg_pos, exclusion_radius_m);

if isempty(all_bad)
    leadstructwExclusion = [];
    return;
end

all_bad_xyz = sort([3*all_bad;3*all_bad-1;3*all_bad-2]);

leadstructwExclusion=head_model;
leadstructwExclusion.GridLoc(all_bad,:)=[];
leadstructwExclusion.Gain(:,all_bad_xyz)=[];
leadstructwExclusion.Comment = char(head_model.Comment + " | exclusion zone "+ exclusion_radius_m*1e3+" mm");
end

function all_bad = identify_bad(grid, seeg_pos, exclusion_dist)
all_bad = [];
for i = 1:length(seeg_pos)
    Distance = grid - seeg_pos(i,:);
    Distance = sqrt(sum(Distance.^2,2)); % euclidean distance
    BAD = find((Distance - exclusion_dist) <=0);
    if ~isempty(BAD), all_bad = [all_bad; BAD]; end
end
end