function varargout = process_eeg_interpbad( varargin )
% PROCESS_INTERP_BAD: Replace bad channels with interpolations of neighboring values.
% The algorithm is similar to FieldTrip function ft_channelrepair, with method 'nearest'

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
% Authors: Roey Schurr, Francois Tadel, 2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Interpolate bad electrodes';
    sProcess.FileTag     = 'interpbad';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 308;
    sProcess.Description = 'http://www.fieldtriptoolbox.org/reference/ft_channelrepair';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    sProcess.processDim  = 2;    % Process time by time
    
    % Definition of the options
    % === WARNING
    sProcess.options.warning.Comment = ['<B>Warning</B>: Interpolating the bad channels is not necessary<BR>' ...
                                        'for ERP analysis and not recommended for source estimation.<BR>' ...
                                        'Make sure you really need this process before using it.<BR><BR>' ...
                                        'Note that you cannot indicate the bad channels here,<BR>' ...
                                        'you need to mark them from the interface before.<BR><BR>'];
    sProcess.options.warning.Type    = 'label';
    % === MAXIMAL DISTANCE BETWEEN NEIGHBOURS
    sProcess.options.maxdist.Comment = 'Maximal distance between neighbours: ';
    sProcess.options.maxdist.Type    = 'value';
    sProcess.options.maxdist.Value   = {5, 'cm', 1};
    % === SENSOR TYPES
    sProcess.options.sensortypes.Comment = 'Sensor types (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'EEG';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
     Comment = sProcess.Comment;
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get option values
    MaxDist = sProcess.options.maxdist.Value{1} / 100;   % Convert from centimeters to meters
    
    % ===== LOAD CHANNEL FILE =====
    % Load channel file
    ChannelMat = in_bst_channel(sInput.ChannelFile);
    % Get channel indices
    iChannels = sInput.iRowProcess;

    
    % ===== LOAD DATA FILE =====
    % Load the file descriptor
    DataMat = in_bst_data(sInput.FileName);
    % Get bad electrodes
    iBad = find(DataMat.ChannelFlag == -1);
    if isempty(iBad)
        bst_report('Info', sProcess, sInput, 'No bad channels in this file.');
        return;
    end
    % Get good channels
    iGood = setdiff(iChannels, iBad);
    % Check that all the sensors have valid locations
    if ~all(cellfun(@(c)size(c,2), {ChannelMat.Channel(iChannels).Loc}) == 1) || any(cellfun(@(c)isequal(c,[0;0;0]), {ChannelMat.Channel(iChannels).Loc}))
        bst_report('Error', sProcess, sInput, 'Some sensors do not have a valid positions or are not EEG electrodes.');
        return;
    end

    % ===== FIND NEIGHBORS =====
    % Get electrode positions
    ChanLoc = [ChannelMat.Channel(iChannels).Loc]';
    % Calculate distance between electrodes
    nChan = length(ChannelMat.Channel);
    nChanSel = length(iChannels);
    dist = zeros(nChan);
    dist(iChannels,iChannels) = ...
        sqrt((ChanLoc(:,1) * ones(1,nChanSel) - ones(nChanSel,1) * ChanLoc(:,1)') .^ 2 + ...
             (ChanLoc(:,2) * ones(1,nChanSel) - ones(nChanSel,1) * ChanLoc(:,2)') .^ 2 + ...
             (ChanLoc(:,3) * ones(1,nChanSel) - ones(nChanSel,1) * ChanLoc(:,3)') .^ 2);
    % Remove all the distances > threshold
    dist(dist > MaxDist) = 0;
    % Remove all the values [GoodChannels x BadChannels], because we want only the values of the bad channels in output based on the good channels
    dist(iGood,:) = 0;
    dist(:,iBad) = 0;
    % Check that all the bad values can be interpolated with something
    iFix = iBad(sum(dist(iBad,:),2) > 0);
    % Warning if some channels could not be fixed
    if (length(iFix) ~= length(iBad))
        iNotFix = setdiff(iBad, iFix);
        bst_report('Warning', sProcess, sInput, ['The following channels could not be interpolated from any good neighbor: ' sprintf('%s ', ChannelMat.Channel(iNotFix).Name)]);
    else
        iNotFix = [];
    end
    % If none of the bad channels can be interpolated
    if isempty(iFix)
        return;
    end
    % List the channels used for each bad channel
    if (sInput.iBlockCol == 1)
        strInfo = '';
        for i = 1:length(iFix)
            strInfo = [strInfo 'Neighbors for "', ChannelMat.Channel(iFix(i)).Name, '": ', sprintf('%s ', ChannelMat.Channel(dist(iFix(i),:) > 0).Name), 10];
        end
        bst_report('Info', sProcess, sInput, strInfo(1:end-1));
    end
    
    % ===== INTERPOLATE BAD VALUES =====
    % Create the weighting matrix (values decrease at a 1/dist rate)
    W = zeros(nChan);
    W(dist~=0) = 1 ./ dist(dist~=0);
    W(iFix,:) = bst_bsxfun(@rdivide, W(iFix,:), sum(W(iFix,:),2));
    % Add a diagonal so it doesn't change the good or unchanged values
    W(iGood,iGood) = eye(length(iGood));
    if ~isempty(iNotFix)
        W(iNotFix,iNotFix) = eye(length(iNotFix));
    end
    % Apply weights to recordings
    sInput.A = W(iChannels,iChannels) * sInput.A;
    
    % ===== RETURN MODIFICATIONS =====
    % Set the corrected channels as good
    sInput.ChannelFlag(iFix) = 1;
    % Add history comment
    sInput.HistoryComment = ['Replaced bad channels with neighbors interpolations (' num2str(MaxDist*100) 'cm): ' sprintf('%s ', ChannelMat.Channel(iFix).Name)];
end




