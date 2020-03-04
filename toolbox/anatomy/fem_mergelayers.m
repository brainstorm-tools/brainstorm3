function NewFemFile = fem_mergelayers(FemFile, MergeLayers, MergedLabel)
% FEM_MERGELAYERS: Merge multiple layers from a FEM model
%
% USAGE: NewFemFile = fem_mergelayers(FemFile, MergeLayers=[ask], MergedLabel=[ask])

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
% Authors: Francois Tadel, 2020


% ===== PARSE INPUTS =====
if (nargin < 3) || isempty(MergedLabel)
    MergedLabel = [];
end
if (nargin < 2) || isempty(MergeLayers)
    MergeLayers = [];
end
NewFemFile = [];

% ===== INPUTS =====
% Load input file
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'Merge layers', 'Loading FEM mesh...');
end
FemMat = load(FemFile);
% Get subject
[sSubject, iSubject] = bst_get('SurfaceFile', FemFile);

% Check input layers
if (length(FemMat.TissueLabels) == 1)
    error('There is only one layer in the input file.');
elseif ~isempty(MergeLayers) && any(~ismember(MergeLayers, FemMat.TissueLabels))
    error('The requested layers are not available in the file.');
end
% Ask layers to merge
if isempty(MergeLayers)
    isSelect = ismember(FemMat.TissueLabels, {'white', 'gray', 'csf'});
    isSelect = java_dialog('checkbox', 'Select layers to merge:', 'Merge layers', [], FemMat.TissueLabels, isSelect);
    if isempty(isSelect)
        if ~isProgress
            bst_progress('stop');
        end
        return;
    end
    MergeLayers = FemMat.TissueLabels(isSelect == 1);
end
% Check number of layers selected
if (length(MergeLayers) < 2)
    error('You must select at least two layers.');
end
% Get merged tissue indices
iMerged = cellfun(@(c)find(strcmpi(c, FemMat.TissueLabels)), MergeLayers);

% Ask new layer name
if isempty(MergedLabel)
    MergedLabel = java_dialog('input', 'Please enter a name for the new merged layer:', 'Merge layers', [], 'brain');
    if isempty(MergedLabel)
        if ~isProgress
            bst_progress('stop');
        end
        return;
    end
end
% Check that new layer name doesn't exist
nTissueOld = length(FemMat.TissueLabels);
nTissueNew = nTissueOld - length(iMerged) + 1;
if ismember(MergedLabel, FemMat.TissueLabels(setdiff(nTissueOld, iMerged)))
    error(['Label "' MergedLabel '" already exists in file.']);
end

% ===== RELABEL TISSUES =====
% Update tissue labels
FemMat.TissueLabels{iMerged(1)} = MergedLabel;
FemMat.TissueLabels(iMerged(2:end)) = [];
% Relabel all elements
iRelabel = 1:nTissueNew;
iRelabel(iMerged) = iMerged(1);
iKept = setdiff(1:nTissueOld, iMerged(2:end));
iRelabel(iKept) = 1:length(iKept);
FemMat.Tissue = reshape(iRelabel(FemMat.Tissue), [], 1);

% ===== SAVE NEW FILE =====
if ~isProgress
    bst_progress('start', 'Merge layers', 'Saving new FEM mesh...');
end
% Update comment
FemMat.Comment = strrep(FemMat.Comment, sprintf('%d lay', nTissueOld), sprintf('%d lay', nTissueNew));
% Add history
FemMat = bst_history('add', FemMat, 'merge', ['Merged layers:', sprintf(' %s', MergeLayers{:})]);
% Add file tag
NewFemFile = file_unique(strrep(FemFile, '.mat', '_merge.mat'));
% Save new file
bst_save(NewFemFile, FemMat, 'v7');
% Reference file in database
db_add_surface(iSubject, NewFemFile, FemMat.Comment);

if ~isProgress
    bst_progress('stop');
end

