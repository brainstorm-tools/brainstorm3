function  [sMri, fileTag] = mri_aggregate (MriFile, Method)
% MRI_AGGREGATE: Aggregate values voxel-wise accross frames in a dynamic volume
%
% USAGE:  [MriFile, fileTag] = mri_aggregate(MriFile, Method)
%            [sMri, fileTag] = mri_aggregate(sMri, Method)
%
% EXAMPLE:
%         [MriFile, fileTag] = mri_aggregate('subject01/dynamic_pet.mat', 'median');
%
% INPUTS:
%       - MriFile : Relative path to the Brainstorm Mri file to aggregate
%       - sMri    : Brainstorm MRI structure to agrregate frames (fields Cube, Voxsize, SCS, NCS...)
%       - Method  : Method used for the aggregagation of values across time frames (default is 'mean'):
%                  - 'mean'  : Average across frames
%                  - 'median': Median across frames
%                  - 'sum'   : Sum across frames
%                  - 'max'   : Max across frames
%                  - 'min'   : Min across frames
% OUTPUTS:
%       - MriFile : Relative path to the new Brainstorm MRI file with aggregateed frames (containing the structure sMri)
%       - sMri    : Brainstorm Mri structure with aggregateed frames
%       - fileTag : Tag added to the comment/filename

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
% Authors: Diellor Basha, 2025

% ===== LOAD INPUTS =====
% Parse inputs
if (nargin < 2) || isempty(Method)
    Method = 'mean'; % Average across frames by default
end

validMethods = {'mean','median','sum','max','min', 'first', 'last', 'z-score'};
if ~ismember(lower(Method), validMethods)
    error('Unsupported aggregation method: %s', Method);
end

if isstruct(MriFile) % USAGE: [sMri, fileTag] = mri_aggregate(sMri, Method)
    sMri = MriFile;
elseif ischar(MriFile) % USAGE: [MriFile, fileTag] = mri_aggregate(MriFile, Method)
    % Get volume in bst format
    sMri = in_mri_bst(MriFile);
else
    bst_progress('stop');
    error('Invalid call.');
end
% Initialize returned variables
nFrames = size(sMri.Cube, 4); fileTag   = '';

% Progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'Dynamic Volume Aggregation', sprintf(['Calculating voxel-wise ' Method ' across %d frames'], nFrames));
end

% ====== AGGREGATE FRAMES =======
switch lower(Method)
    case 'mean'
        sMri.Cube = mean(sMri.Cube, 4);
    case 'median'
        sMri.Cube = median(sMri.Cube, 4);
    case 'sum'
        sMri.Cube = sum(sMri.Cube, 4);
    case 'max'
        sMri.Cube = max(sMri.Cube, 4);
    case 'min'
        sMri.Cube = min(sMri.Cube, 4);
    case 'zscore'
        sMri.Cube = zscore(sMri.Cube, 4);
    case 'first'
        sMri.Cube = sMri.Cube(:,:,:,1);
    case 'last'
        sMri.Cube = sMri.Cube(:,:,:,end);
end

sMri.Header.dim.dim(1) = 3;       % Number of dimensions is now 3
sMri.Header.dim.dim(5) = 1;       % Set time/frame dimension to 1
sMri.Header.dim.pixdim(5) = 0;    % Time resolution no longer applicable
sMri.Header.descrip = [sMri.Header.hist.descrip Method ' of 4D volume across time'];  % Add if used downstream

% ===== UPDATE HISTORY ========
fileTag = ['_' Method]; % Output file tag
sMri.Comment = [sMri.Comment, fileTag]; % Add file tag
sMri = bst_history('add', sMri, 'aggregate', sprintf(['Voxel-wise ' Method ' of %d frames'], nFrames));   % Add history entry
% Close progress bar
if ~isProgress
    bst_progress('stop');
end

% ===== SAVE NEW FILE =====
% Save output
if ~isempty(MriFile) && ischar(MriFile) % If input is path to Brainstorm MRI file
    [sSubject, iSubject, ~] = bst_get('MriFile', MriFile);
    % Save new MRI in Brainstorm format
    MriFileFull = file_unique(strrep(file_fullpath(MriFile), '.mat', [fileTag '.mat']));
    out_mri_bst(sMri, MriFileFull);
    % Register new MRI
    iAnatomy = length(sSubject.Anatomy) + 1;
    sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
    sSubject.Anatomy(iAnatomy).FileName = file_short(MriFileFull);
    sSubject.Anatomy(iAnatomy).Comment  = sMri.Comment;
    % Update subject structure
    bst_set('Subject', iSubject, sSubject);
    % Refresh tree
    panel_protocols('UpdateNode', 'Subject', iSubject);
    panel_protocols('SelectNode', [], 'anatomy', iSubject, iAnatomy);
    % Save database
    db_save();
    % Return new MRI file
    sMri = file_short(MriFileFull);
else
    % Return output structure
end

end