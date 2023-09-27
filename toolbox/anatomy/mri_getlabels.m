function [Labels, AtlasName] = mri_getlabels(MriFile, sMri, isForced)
% MRI_GETLABELS: Get labels associated with a volume atlas (based on the MRI or the atlas name)
% 
% USAGE:  Labels = mri_getlabels(MriFile)                   : Get labels based on filename (look for .txt file next to it, or use standard filenames)
%         Labels = mri_getlabels(MriFile, sMri, isForced=0) : Keep only the labels available in the sMRI structure
%         Labels = mri_getlabels(AtlasName)                 : Get labels based on atlas name {'aseg', 'marsatlas'}
%
% INPUT:
%    - MriFile   : Full path to the volume atlas (eg. '/path/to/aseg.mgz')
%    - sMri      : Braistorm MRI structure
%    - AtlasName : Name of the atlas: {'aseg', 'marsatlas'}
%    - isForced  : Create labels based on the numeric labels if text labels are missing
% 
% OUTPUT:
%    - Labels : Cell-array {nLabels x 3}
%               Labels{i,1} = integer, label in the atlas volume (eg. 18)
%               Labels{i,2} = string, human-readable label (eg. 'Amygdala L')
%               Labels{i,3} = color, as a [1x3] double
%
% REFERECES:
%    - https://www.lead-dbs.org/helpsupport/knowledge-base/atlasesresources/cortical-atlas-parcellations-mni-space/
%    - https://www.lead-dbs.org/helpsupport/knowledge-base/atlasesresources/atlases/

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
% Authors: Francois Tadel, 2020-2021

% Parse inputs
if (nargin < 3) || isempty(isForced)
    isForced = 0;
end
if (nargin < 2) || isempty(sMri)
    sMri = [];
end
% Initialize returned values
Labels = [];
AtlasName = [];
maxNameLength = 16;

% If the input is a filename
if (any(MriFile == '.') || (length(MriFile) > maxNameLength)) && file_exist(MriFile)
    % Get file name
    [fPath, fBase, fExt] = bst_fileparts(MriFile);
    % LABELS MRIcron: Try to get a side .txt with the labels
    LabelsFile = bst_fullfile(fPath, [fBase, '.txt']);
    if file_exist(LabelsFile)
        Labels = in_label_mricron(LabelsFile);
    end
    fBase = strrep(fBase, '.nii', '');
    % LABELS CAT12: Try to get a side .csv with the labels
    LabelsFile = bst_fullfile(fPath, [fBase, '.csv']);
    if file_exist(LabelsFile)
        Labels = in_label_cat12(LabelsFile);
    end
    % LABELS SimNIBS4: Try to get a side _LUT.txt with the labels
    LabelsFile = bst_fullfile(fPath, [fBase, '_LUT.txt']);
    if file_exist(LabelsFile)
        Labels = in_label_simnibs(LabelsFile);
    end

    % If labels were read: use the filename as the atlas name
    fBase = lower(fBase);
    if ~isempty(Labels)
        AtlasName = fBase;
    % Standard atlases (FreeSurfer/ASEG, BrainSuite/SVREG)
    elseif ~isempty(strfind(fBase, 'aseg')) || ~isempty(strfind(fBase, 'aparc')) % *aseg*.mgz
        AtlasName = 'freesurfer';
    elseif ~isempty(strfind(fBase, '.svreg.label'))   % *.svreg.label.nii.gz
        AtlasName = 'svreg';
    elseif ~isempty(strfind(fBase, '_final_contr')) || ~isempty(strfind(fBase, 'final_tissues'))  % SimNIBS3/headreco  &  SimnNIBS4/charm
        AtlasName = 'simnibs';
    end
end
% If the name of the altas is in the file comment
if isempty(AtlasName) && ~isempty(sMri) && ~isempty(sMri.Comment)
    if ~isempty(strfind(sMri.Comment, 'aseg'))
        AtlasName = 'freesurfer';
    elseif ~isempty(strfind(sMri.Comment, 'svreg'))
        AtlasName = 'svreg';
    elseif ~isempty(strfind(sMri.Comment, 'tissues'))
        AtlasName = 'tissues5';
    end
% Atlas name is given in input
elseif ~any(MriFile == '.') && (length(MriFile) <= maxNameLength)
    AtlasName = MriFile;
end
% No atlas identified
if isempty(AtlasName) && ~isForced
	return;
end

% Switch by atlas name
if isempty(Labels) && ~isempty(AtlasName)
    switch lower(AtlasName)
        case 'freesurfer'    % FreeSurfer ASEG + Desikan-Killiany (2006) + Destrieux (2010)
            Labels = mri_getlabels_freesurfer();
        case 'marsatlas'     % BrainVISA MarsAtlas (Auzias 2006)
            Labels = mri_getlabels_marsatlas();
        case 'svreg'         % BrainSuite SVREG (Brainsuite1, USCBrain)
            Labels = mri_getlabels_svreg();
        case 'tissues5'    % Basic head tissues
            Labels = {...
                    0, 'Background',    [  0,   0,   0]; ...
                    1, 'White',         [220, 220, 220]; ...
                    2, 'Gray',          [130, 130, 130]; ...
                    3, 'CSF',           [ 44, 152, 254]; ...
                    4, 'Skull',         [255, 255, 255]; ...
                    5, 'Scalp',         [255, 205, 184]};
        case 'simnibs'
            Labels = {...
                    0,   'Background',    [  0,   0,   0]; ...
                    1,   'White',         [220, 220, 220]; ...
                    2,   'Gray',          [130, 130, 130]; ...
                    3,   'CSF',           [ 44, 152, 254]; ...
                    4,   'Skull',         [255, 255, 255]; ...
                    5,   'Scalp',         [255, 205, 184]; ...
                    6,   'Eyes',          [255,   0, 255]; ...
                    7,   'Compact_bone',  [255, 239, 179]; ...
                    8,   'Spongy_bone',   [255, 138,  57]; ...
                    9,   'Blood',         [  0,  65, 142]; ...
                    10,  'Muscle',        [  0, 118,  14]; ...
                    100, 'Electrode',     [  37, 79, 255]; ...
                    500, 'Saline_or_gel', [103, 255, 226]};
    end
end


%% ===== FIX LABELS LIST =====
if ~isempty(sMri) && ~isempty(Labels)
    % Add background if missing
    if ~ismember(0, [Labels{:,1}])
        Labels = [{0, 'Background', [0 0 0]}; Labels];
    end
    % Get labels available in the MRI volume
    toKeep = unique(sMri.Cube(:));
    % Find the corresponding indices in the Labels array
    isLabels = ismember([Labels{:,1}], toKeep);
    % Keep only these labels
    Labels = Labels(isLabels, :);
    % Check for undocumented labels: console warning and display in white (255,255,255)
    iMissing = find(~ismember(toKeep, [Labels{:,1}]));
    if ~isempty(iMissing)
        disp(['BST> Warning: Labels missing in atlas:' sprintf(' %d', toKeep(iMissing))]);
        Labels = cat(1, Labels, cat(2, num2cell(toKeep(iMissing)), repmat({'Unknown', [255 255 255]}, length(iMissing), 1)));
    end
end


%% ===== FORCE LABEL CREATION =====
if isempty(Labels) && ~isempty(sMri) && isForced
    % Get labels available in the volume
    allLabels =num2cell(reshape(setdiff(unique(sMri.Cube(:)), 0), [], 1));
    indList = num2cell(reshape(1:length(allLabels), [], 1));
    % Get colormap
    ColorTable = round(panel_scout('GetScoutsColorTable') .* 255);
    ColorTable = repmat(ColorTable, round(length(allLabels)/length(ColorTable)) + 1, 1);
    % Create label entry for each value in the volume
    Labels = [{0, 'Background', [0 0 0]}; ...
        cat(2, allLabels, ...
               cellfun(@num2str, allLabels, 'UniformOutput', 0), ...
               cellfun(@(i)ColorTable(i,:), indList, 'UniformOutput', 0))];
end
