function [sFile, nEpochs] = in_epochs_nwb(sFile, nwb2)
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
% Authors: Konstantinos Nasiotis, 2019,2020

% Check if there are trials present
if isempty(nwb2.intervals_epochs)
    nEpochs = 1;
    sFile.prop.nAvg = 1;
    sFile.format    = 'NWB-CONTINUOUS';
    return
    
else
    % Get epochs
    timeBoundsTrials = double([nwb2.intervals_epochs.start_time.data.load nwb2.intervals_epochs.stop_time.data.load]);

    % Get number of epochs
    nEpochs = length(nwb2.intervals_epochs.start_time.data.load);
    
    % === EPOCHS FILE ===
    % Build epochs structure
    for iEpoch = 1:nEpochs
        try
            epochLabel = nwb2.intervals_epochs.tags.data.load(iEpoch);
            sFile.epochs(iEpoch).label       = ['Epoch #(' num2str(iEpoch) ') - ' epochLabel{1}];
        catch
            sFile.epochs(iEpoch).label       = ['Epoch #(' num2str(iEpoch) ')'];
        end
        sFile.epochs(iEpoch).times       = timeBoundsTrials(iEpoch,:);
%         sFile.epochs(iEpoch).samples     = round(sFile.epochs(iEpoch).times * sFile.prop.sfreq);
        sFile.epochs(iEpoch).nAvg        = 1;
        sFile.epochs(iEpoch).select      = 1;
        sFile.epochs(iEpoch).bad         = 0;
%         sFile.epochs(iEpoch).bad         = badTrials(iEpoch); 
        sFile.epochs(iEpoch).channelflag = [];
    end

    sFile.format    = 'NWB';
end

end