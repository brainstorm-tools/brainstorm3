function DataMats = in_bst_data_multi(DataFiles)
% IN_BST_DATA_MULTI:  Read the Time and nAvg fields from multiple data files
% Read only once these information for each datalist

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
% Authors: Francois Tadel, 2010-2019


%% ===== DETECT TRIAL FILES =====
% Remove similar files (if lots of trials for same condition: keep only one file)
% => In order not to have to load all the files to get the Time fields
% Get filenames without "_trial" tag
removedTrialsFiles = cellfun(@str_remove_trial, DataFiles, 'UniformOutput', 0);
% Get all the data that do not have '_trial' tag (averaged data)
isTrial = ~cellfun(@isempty, removedTrialsFiles);
iDataTrial = find(isTrial);
iDataNoTrial = find(~isTrial);
% If more than one "trial" in the study: just keep the first one
[uniqueDataFiles, iUniqueDataFiles, iFull2Unique] = unique(removedTrialsFiles(iDataTrial));
% Build list of files to read the Time vectors
iTimeData = sort([iDataNoTrial, iDataTrial(iUniqueDataFiles)]);
timeDataFiles = DataFiles(iTimeData);

% Build array with number of trials for each file in timeDataFiles
nTrials = ones(1,length(timeDataFiles));
iFull2Unique = iDataTrial(iUniqueDataFiles(iFull2Unique));
for i = 1:length(timeDataFiles)
    nTrials(i) = nnz(iTimeData(i) == iFull2Unique);
end
nTrials(nTrials == 0) = 1;



%% ===== READ DATA TIME VECTORS =====
DataMats = repmat(struct('Time',[], 'nAvg', 1, 'Leff', 1, 'SamplingRate', 0), 0);
% Progress bar
bst_progress('start', 'Read recordings information', 'Analysing input files...', 0, length(timeDataFiles));
% Loop on all the files
for iFile = 1:length(timeDataFiles)
    bst_progress('inc',1);
    % Load time vector
    DataMat = in_bst_data(timeDataFiles{iFile}, 'Time', 'nAvg', 'Leff');
    % Compute duration of each sample
    if (length(DataMat.Time) > 2)
        DataMat.SamplingRate = DataMat.Time(2) - DataMat.Time(1);
    else
        DataMat.SamplingRate = 0;
    end
    % Replicate this structure for all the trials
    DataMats = [DataMats, repmat(DataMat, [1,nTrials(iFile)])];
end
bst_progress('stop');





