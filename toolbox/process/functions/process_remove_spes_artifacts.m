function varargout = process_remove_spes_artifacts(varargin)
% PROCESS_REMOVE_SPES_ARTIFACTS: Remove Single-Pulse Electrical Stimulation (SPES)
% artifacts and slow drifts
% This process:
%   1) Detects stimulation events from a selected trigger channel
%   2) Replaces the artifact window around each event using spline interpolation
%   3) Applies Empirical Mode Decomposition (EMD) based filtering to remove low-frequency drifts
%
% USAGE:
%   OutputFiles = process_remove_spes_artifacts('Run', sProcess, sInputs)

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
% Authors: Kenneth N. Taylor, 2020
%          John C. Mosher, 2020          
%          Chinmay Chinara, 2026

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
% Description the process
sProcess.Comment     = 'Remove SPES artifacts';
sProcess.Category    = 'Custom';
sProcess.SubGroup    = 'Stimulation';
sProcess.Index       = 902;
% Definition of the input accepted by this process
sProcess.InputTypes  = {'data'};
sProcess.OutputTypes = {'data'};
sProcess.nInputs     = 1;
sProcess.nMinFiles   = 1;
% Stimulation event
sProcess.options.stimevent.Comment = 'Stimulation event: ';
sProcess.options.stimevent.Type    = 'text';
sProcess.options.stimevent.Value   = 'STIM';
% EMD cutoff frequency
sProcess.options.label1.Comment  = ['<HTML><I><FONT color="#777777">' ...
                                    'Remove low-frequency drifts using Empirical Mode Decomposition (EMD)</FONT></I>'];
sProcess.options.label1.Type     = 'label';
sProcess.options.cutoff.Comment = 'EMD cutoff frequency: ';
sProcess.options.cutoff.Type    = 'value';
sProcess.options.cutoff.Value   = {2, 'Hz', 2};
% Duration to replace around each stimulation event
sProcess.options.timeart.Comment = 'Time to account for artifact:';
sProcess.options.timeart.Type    = 'value';
sProcess.options.timeart.Value   = {0.005, 'ms', 0};
% Time taken on each side of the artifact window for spline interpolation
sProcess.options.timespline.Comment = 'Time on either side of artifact to spline with:';
sProcess.options.timespline.Type    = 'value';
sProcess.options.timespline.Value   = {0.003, 'ms', 0};
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    % Initialize output
    OutputFiles = {};

    % Get process option values
    StimEvent     = sProcess.options.stimevent.Value;
    CutoffFreq    = sProcess.options.cutoff.Value{1};
    TimeArt       = sProcess.options.timeart.Value{1} * 1000;
    TimeSpline    = sProcess.options.timespline.Value{1} * 1000;
    
    for iFile = 1:length(sInput)
        fullFileName = file_fullpath(sInput(iFile).FileName);

        % Load full data only after confirming the trigger exists
        Data = load(fullFileName);
        
        % Load stimulation events
        eventMat = load(fullFileName, 'Events');        
        % Find the selected stimulation event
        iStimEvent = find(strncmp({eventMat.Events.label}, StimEvent, length(StimEvent)));
        if isempty(iStimEvent)
            bst_report('Error', sProcess, [], ['No ' StimEvent ' event found']);
            return;
        end        

        % Convert trigger times to sample indices
        stimSamples = eventMat.Events(iStimEvent).times;
        [~, stimSamples] = ismembertol(stimSamples, Data.Time, 1e-7);

        % Build the full interpolation window around each trigger
        win = -TimeSpline:(TimeArt + TimeSpline - 1);

        % Indices of the duration used to anchor the spline
        iSpline = [1:TimeSpline, (1-TimeSpline:0) + length(win)];
        
        % Sample indices of all interpolation windows
        stimWin = repmat(win(:), 1, length(stimSamples)) + repmat(stimSamples(:)', length(win), 1);
        
        % Replace each artifact window with spline interpolation
        for iChan = 1:size(Data.F, 1) % for each channel of data
            for iStimWin = 1:size(stimWin, 2) % for each artifact window
                Data.F(iChan, stimWin(:, iStimWin)) = spline(win(iSpline), Data.F(iChan, stimWin(iSpline, iStimWin)), win);
            end
        end
        
        % Apply EMD based filtering to suppress drift
        bst_progress('start', 'Process', sprintf('[%d/%d] Processing EMD, rejecting below %.1f Hz...', iFile, length(sInput), CutoffFreq), 0, 100);
        fprintf('REMOVE_SPES_ARTIFACTS> [%d/%d] Processing EMD, rejecting below %.1f Hz...', iFile, length(sInput), CutoffFreq);
        % Sampling frequency
        sampFreq = 1 / mean(diff(Data.Time));
        for iChan = 1:size(Data.F, 1)
            % Show progress
            progressPrc = round(100 .* iChan ./ size(Data.F, 1));
            bst_progress('set', progressPrc);
            % Decompose signal into intrinsic mode functions
            imf = emd(Data.F(iChan, :));
            % Estimate the characteristic frequency of each mode
            modeFreq = ImfStats(imf, sampFreq);
            if CutoffFreq > 0
                % Keep only modes above cutoff
                Data.F(iChan, :) = sum(imf(:, modeFreq > CutoffFreq), 2)';
            else
                % Keep only modes below abs(cutoff)
                Data.F(iChan, :) = sum(imf(:, modeFreq < abs(CutoffFreq)), 2)';
            end
        end
        fprintf('Done!\n');
       
        % Duplicate original file before writing cleaned data
        sFile = bst_process('CallProcess', 'process_duplicate', {sInput(iFile).FileName}, [], ...
            'target', 1, ...            % Duplicate data files
            'tag',    sprintf('_emd'));
        % Overwrite duplicated file with cleaned signal
        newFile   = file_fullpath(sFile.FileName);
        dataNew   = load(newFile, 'F');
        dataNew.F = Data.F;
        bst_save(newFile, dataNew, 'v7', 1);

        % Register output
        OutputFiles{end+1} = sFile.FileName;
    end
end

%% ===== IMF MODE STATISTICS =====
% Estimate the characteristic frequency of each IMF from its sign changes
function stats = ImfStats(imf, fs)
    signChanges = sum(abs(diff(sign(detrend(imf))) / 2));
    stats = signChanges / (size(imf, 1) / fs * 2);
end