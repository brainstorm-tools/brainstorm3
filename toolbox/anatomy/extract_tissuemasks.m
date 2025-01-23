function TissueMasks = extract_tissuemasks(TissueFile, TissueLabels)
% EXTRACT_TISSUEMASKS: Extract tissue segmentation masks
%
% USAGE:  TissueMasks = extract_tissuemasks(TissueFile, TissueLabels)

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
% Authors: Chinmay Chinara, 2025

%% ===== PARSE INPUTS =====
% Initialize returned variables
TissueMasks = {};

%% ===== LOAD TISSUE SEGMENTATION =====
% Load MRI 
bst_progress('start', 'Extract tissue', 'Loading tissues...');
sMri = bst_memory('LoadMri', TissueFile);
bst_progress('stop');
% Check that this is a tissue segmentation
if ~isfield(sMri, 'Labels') || isempty(sMri.Labels)
    bst_error('Invalid tissue segmentation: missing labels.', 'Extract tissue', 0);
    return;
end


%% ===== GET TISSUE LABELS =====
if (nargin < 2) || isempty(TissueLabels)
    listLayers = sMri.Labels(fliplr(find([sMri.Labels{:,1}] > 0)), 2)';
    TissueLabels = listLayers;
elseif ischar(TissueLabels)
    TissueLabels = {TissueLabels};
end

%% ===== EXTARCT TISSUE MASK =====
% Progress bar
bst_progress('start', 'Extract tissue', 'Initializing...');
for iTissue = 1:length(TissueLabels)
    bst_progress('text', 'Extract tissue', ['Layer name: ' lower(TissueLabels{iTissue}) ': Extracting...']);
    % Get layer
    iLayer = find(strcmpi(sMri.Labels(:,2), TissueLabels{iTissue}));
    if isempty(iLayer)
        bst_error(['Layer not found: ' TissueLabels{iTissue}], 'Extract tissue', 0);
        return;
    end
    sTissueMask = sMri;
    sTissueMask.Cube = (sMri.Cube == sMri.Labels{iLayer,1});
    sTissueMask.Comment = lower(TissueLabels{iTissue});
    % Return new files
    TissueMasks{end+1} = sTissueMask;
end

% Close, success
bst_progress('stop');