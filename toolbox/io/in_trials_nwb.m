function [sFile, nEpochs] = in_trials_nwb(sFile, nwb2)
% IN_TRIALS_NWB Read trials from a Neurodata Without Borders .nwb file.

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
% Authors: Konstantinos Nasiotis, 2019

error('This code is outdated, see: https://neuroimage.usc.edu/forums/t/error-opening-nwb-files/21025');

% Check if there are trials present
if isempty(nwb2.intervals_trials)
    nEpochs = 1;
    sFile.prop.nAvg = 1;
    sFile.format    = 'NWB-CONTINUOUS';
    return
    
else
    % Get trials
    
    % Check if "condition" field exists
    condition_field_exists = ismember(keys(nwb2.intervals_trials.vectordata),'condition');
    if isempty(condition_field_exists) % This return 1x0 empty if no keys is present
        condition_field_exists = false;
    end
    
    if condition_field_exists
    
        all_conditions   = nwb2.intervals_trials.vectordata.get('condition').data;
        uniqueConditions = unique(nwb2.intervals_trials.vectordata.get('condition').data);
    else
        all_conditions = repmat({'Trial'},length(nwb2.intervals_trials.start_time.data.load),1);
        uniqueConditions = {'Trial'};
    end
        
    timeBoundsTrials = double([nwb2.intervals_trials.start_time.data.load nwb2.intervals_trials.stop_time.data.load]);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % THIS FIELD MIGHT NOT BE PRESENT ON ALL DATASETS
    % I'M KEEPING IT HERE FOR REFERENCE
    % % Get error trials
    % badTrials = nwb2.intervals_trials.vectordata.get('error_run').data.load;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    iUniqueConditionsTrials = zeros(length(uniqueConditions),1); % This will hold the index of each trial for each condition

    % Get number of epochs
    nEpochs = length(nwb2.intervals_trials.start_time.data.load);
    
    % === EPOCHS FILE ===
    % Build epochs structure
    for iEpoch = 1:nEpochs

        ii = find(strcmp(uniqueConditions, all_conditions{iEpoch}));
        iUniqueConditionsTrials(ii)      =  iUniqueConditionsTrials(ii)+1;
        sFile.epochs(iEpoch).label       = [all_conditions{iEpoch} ' (#' num2str(iUniqueConditionsTrials(ii)) ')'];
        sFile.epochs(iEpoch).times       = timeBoundsTrials(iEpoch,:);
        sFile.epochs(iEpoch).samples     = round(sFile.epochs(iEpoch).times * sFile.prop.sfreq);
        sFile.epochs(iEpoch).nAvg        = 1;
        sFile.epochs(iEpoch).select      = 1;
        sFile.epochs(iEpoch).bad         = 0;
%         sFile.epochs(iEpoch).bad         = badTrials(iEpoch); 
        sFile.epochs(iEpoch).channelflag = [];
    end

    sFile.format    = 'NWB';
end

end