function [NoiseCov, SensorsNames] = in_noisecov_fif( fname )
% IN_NOISECOV_FIF: Read a FIF file, and return a NoiseCov matrix [nChannel x nChannel].
%
% USAGE:  [NoiseCov, SensorsNames] = in_noisecov_fif( fname )

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
% Authors: Francois Tadel, 2009
%          (Based on scripts from M.Hamalainen)

% Intialize returned matrix
NoiseCov = [];
% Get fiff constants
global FIFF;
if isempty(FIFF)
    FIFF = fiff_define_constants();
end

%% ===== GET NOISE COV BLOCK =====
% Open FIF file
[ fid, tree ]  = fiff_open(fname);
if (fid < 0)
    error(['Cannot open FIFF file : "' fname '"']);
end
% Look for COV blocks in FIF file
covAllBlocks = fiff_dir_tree_find(tree, FIFF.FIFFB_MNE_COV);
if isempty(covAllBlocks)
    return
end
% If more than one block: look a NOISE cov matrix
covBlock = [];
for i = 1:length(covAllBlocks)
    % Get covariance matrix type
    iCovType = find([covAllBlocks(i).dir.kind] == FIFF.FIFF_MNE_COV_KIND);
    if ~isempty(iCovType)
        tag = fiff_read_tag(fid, covAllBlocks(i).dir(iCovType).pos);
        if (tag.data == FIFF.FIFFV_MNE_NOISE_COV)
            covBlock = covAllBlocks(i);
            break
        end
    end
end

%% ===== READ NOISE COV MATRIX =====
% Get matrix size
iCovSize = find([covBlock.dir.kind] == FIFF.FIFF_MNE_COV_DIM);
if isempty(iCovSize)
    return
end
tag = fiff_read_tag(fid, covBlock.dir(iCovSize).pos);
covSize = tag.data;

% Get cov matrix position
iCovMat = find([covBlock.dir.kind] == FIFF.FIFF_MNE_COV);
if isempty(iCovMat)
    return
end
% Read cov matrix (in packed representation: lower triangle)
tag = fiff_read_tag(fid, covBlock.dir(iCovMat).pos);
NoiseCovPacked = tag.data;

% Rebuild full matrix
NoiseCov = zeros(covSize);
iPos = 1;
for i = 1:covSize
    NoiseCov(1:i, i) = NoiseCovPacked(iPos:iPos+i-1);
    NoiseCov(i, 1:i) = NoiseCovPacked(iPos:iPos+i-1);
    iPos = iPos + i;
end

%     % Read covariance using mne tools
%     cov = mne_read_cov(fid, covtree, FIFF.FIFFV_MNE_NOISE_COV);
    

%% ===== READ SENSORS NAMES =====
% Get row names position
iRowNames = find([covBlock.dir.kind] == FIFF.FIFF_MNE_ROW_NAMES);
if ~isempty(iRowNames)
    % Read row names
    tag = fiff_read_tag(fid, covBlock.dir(iRowNames).pos);
    % Split string
    SensorsNames = str_split(tag.data,':');
else
    SensorsNames = [];
end


