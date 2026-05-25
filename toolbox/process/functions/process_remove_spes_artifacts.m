function varargout = process_remove_spes_artifacts(varargin)
% PROCESS_REMOVE_SPES_ARTIFACTS: Remove Single-Pulse Electrical Stimulation (SPES) artifacts
%
% This process:
%   1) Detects selected stimulation event
%   2) Replaces the artifact window around the event using spline interpolation
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
sProcess.FileTag     = 'remartifacts';
sProcess.Category    = 'Filter';
sProcess.SubGroup    = 'FAST graph';
sProcess.Index       = 1301;
sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/FastGraph';
% Definition of the input accepted by this process
sProcess.InputTypes  = {'data'};
sProcess.OutputTypes = {'data'};
sProcess.nInputs     = 1;
sProcess.nMinFiles   = 1;
% Stimulation event
sProcess.options.stimevent.Comment = 'Stimulation trigger event: ';
sProcess.options.stimevent.Type    = 'text';
sProcess.options.stimevent.Value   = 'STIM';
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
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get process option values
    StimEvent  = sProcess.options.stimevent.Value;    
    TimeArt    = sProcess.options.timeart.Value{1};
    if TimeArt <= 0
        bst_report('Error', sProcess, [], 'Artifact duration must be positive.');
        return;
    end
    TimeSpline = sProcess.options.timespline.Value{1};
    if TimeSpline <= 0
        bst_report('Error', sProcess, [], 'Spline duration must be positive.');
        return;
    end   

    % Sampling frequency
    Fs = 1 / mean(diff(sInput.TimeVector));

    % Convert time windows to samples
    nArt    = round(TimeArt * Fs);
    nSpline = round(TimeSpline * Fs);

    % Find selected stimulation event
    DataMat = in_bst_data(sInput.FileName, 'Events');
    eventLabels = {DataMat.Events.label};
    iStimEvent = find(strncmp(eventLabels, StimEvent, length(StimEvent)));
    if isempty(iStimEvent)
        bst_report('Error', sProcess, [], ['No ' StimEvent ' event found']);
        return;
    end        

    % Convert trigger times to sample indices
    stimTimes = DataMat.Events(iStimEvent).times;
    stimSamples = bst_closest(stimTimes, sInput.TimeVector);

    % Build the full interpolation window around each trigger
    win = -nSpline:(nArt + nSpline - 1);

    % Indices used as spline anchors: samples before and after the artifact window
    iSpline = [1:nSpline, (numel(win) - nSpline + 1):numel(win)];
    
    % Build all stimulation windows
    stimWin = win(:) + stimSamples(:)';
    % Remove windows that go outside boundaries
    nTime = size(sInput.TimeVector, 2);
    isValidWin = all(stimWin >= 1 & stimWin <= nTime, 1);
    stimWin = stimWin(:, isValidWin);
    
    % Replace each artifact window with spline interpolation
    for iChan = 1:size(sInput.A, 1) % for each channel of data
        for iStimWin = 1:size(stimWin, 2) % for each artifact window
            sInput.A(iChan, stimWin(:, iStimWin)) = spline(win(iSpline), sInput.A(iChan, stimWin(iSpline, iStimWin)), win);
        end
    end

    % Add history comment
    sInput.HistoryComment = sprintf('Removed SPES artifacts around "%s" event: artifact window = %.3f ms, spline window = %.3f ms', StimEvent, TimeArt*1000, TimeSpline*1000);
end