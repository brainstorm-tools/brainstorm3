function idxTrials = bst_trial_idx(idx, nTimes, nTrials)
% BST_TRIAL_IDX         Given the indices of desired time points for one trial,
%                       form a list of indices that pulls those time points
%                       from each trial in a concatenated set of trials.
%
% INPUTS:
%  idx        - Desired time samples in each trial
%               1 <= min(idx) and max(idx) <= nTimes
%  nTimes     - Length of each trial
%  nTrials    - Number of trials
%
% OUTPUT:
%  idxTrials 	- Indices to pull time samples from all trials.
%
% Given a matrix of concatenated trials
%   y = [y_1(1) ... y_1(nTimes) y_2(1) ... y_nTrials(1) ... y_nTrials(nTimes)]
% we want to pull out y_i(idx) for each trial i. We do that by calling
%   desired = y(bst_trial_idx(idx, nTimes, nTrials))
% to get
%   [y_1(idx) y_2(idx) ... y_nTrials(idx)]
%
% Call:
%   idxTrials = bst_trial_idx(idx, nTimes, nTrials)

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
% Authors: Syed Ashrafulla, 2012

idx = idx(:); % Force column vector of indices

idxTrials = idx * ones(1, nTrials) + ... % Repeat per trial, accounting for ...
  ones(length(idx), 1) * (0:(nTrials-1))*nTimes; % ... trial offset in indices

idxTrials = idxTrials(:); % Convert to one vector of indices

end

