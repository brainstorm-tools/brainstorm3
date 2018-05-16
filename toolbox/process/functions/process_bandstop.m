function varargout = process_bandstop( varargin )
% PROCESS_BANDSTOP: Remove one or more sinusoids from a signal
%
% USAGE:      sProcess = process_bandstop('GetDescription')
%               sInput = process_bandstop('Run', sProcess, sInput)
%                    x = process_bandstop('Compute', x, sfreq, FreqList, FreqWidth=1.5, method='fieldtrip_butter')

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2014
% 
% Code copied or inspired from:
%   - Andreas Widmann, 2005-2014, University of Leipzig, widmann@uni-leipzig.de
%   - Robert Oostenveld, Arjen Stolk, Andreas Widmann, 2003-2014, FieldTrip toolbox (http://fieldtrip.fcdonders.nl/)

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Band-stop filter';
    sProcess.FileTag     = 'stop';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Pre-process';
    sProcess.Index       = 65;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsFilter#Filter_specifications:_Band-stop';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.processDim  = 1;   % Process channel by channel
    
    % Definition of the options
    % === Freq list
    sProcess.options.freqlist.Comment = 'Frequencies to remove:';
    sProcess.options.freqlist.Type    = 'value';
    sProcess.options.freqlist.Value   = {[], 'list', 2};
    % === Freq width
    sProcess.options.freqwidth.Comment = 'Width of the frequency bands:';
    sProcess.options.freqwidth.Type    = 'value';
    sProcess.options.freqwidth.Value   = {1.5, 'Hz', 1};
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    FreqWidth = sProcess.options.freqwidth.Value{1};
    if isempty(sProcess.options.freqlist.Value{1})
        Comment = 'Butterworth band-stop: No frequency selected';
    else
        strValue = sprintf('%1.0fHz ', sProcess.options.freqlist.Value{1});
        Comment = ['Butterworth band-stop: ' strValue(1:end-1) ' (+/-' num2str(FreqWidth/2) 'Hz)'];
    end
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get options
    FreqList = sProcess.options.freqlist.Value{1};
    FreqWidth = sProcess.options.freqwidth.Value{1};
    if isempty(FreqList) || isequal(FreqList, 0) || (FreqWidth <= 0)
        bst_report('Error', sProcess, [], 'No frequency in input.');
        sInput = [];
        return;
    end
    % Get sampling frequency
    sfreq = 1 ./ (sInput.TimeVector(2)-sInput.TimeVector(1));
%     % Test length of the signal
%     if (size(sInput.A,2) < round(sfreq))
%         bst_report('Warning', sProcess, [], 'Signal is too short for performing a proper filtering. Minimum duration = 1s');
%     end
    % Filter data
    sInput.A = Compute(sInput.A, sfreq, FreqList, FreqWidth, 'fieldtrip_butter');
    % Comment
    strValue = sprintf('%1.0fHz ', FreqList);
    sInput.CommentTag = [sProcess.FileTag '(' strValue(1:end-1) ')'];
    % Do not keep the Std field in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
end


%% ===== EXTERNAL CALL =====
% USAGE: x = process_bandstop('Compute', x, sfreq, FreqList, FreqWidth=1.5, method='fieldtrip_butter')
function x = Compute(x, sfreq, FreqList, FreqWidth, method)
    % Define a default method and width
    if (nargin < 4) || isempty(FreqWidth) || isempty(method)
        method = 'fieldtrip_butter';
        FreqWidth = 1.5;
    end
    % Check list of freq to remove
    if isempty(FreqList) || isequal(FreqList, 0)
        return;
    end
    % Nyqist frequency
    Fnyq = sfreq/2;
    % Remove the mean of the data before filtering
    xmean = mean(x,2);
    x = bst_bsxfun(@minus, x, xmean);
    
    % Remove all the frequencies sequencially
    for ifreq = 1:length(FreqList)
        % Frequency band to remove
        FreqBand = [FreqList(ifreq) - FreqWidth/2, FreqList(ifreq) + FreqWidth/2];
        % Filtering using the selected method
        switch (method)
            % Source: FieldTrip toolbox
            % Equivalent to: x = ft_preproc_bandstopfilter(x, sfreq, FreqBand, [], 'but');
            case 'fieldtrip_butter'
                % Filter order
                N = 4;
                % Butterworth filter
                if bst_get('UseSigProcToolbox')
                    [B,A] = butter(N, FreqBand ./ Fnyq, 'stop');
                else
                    [B,A] = oc_butter(N, FreqBand ./ Fnyq, 'stop');
                end
                % Filter signal
                x = filtfilt(B, A, x')';

            % Source: FieldTrip toolbox
            % Bandstop filter: Onepass-zerophase, hamming-windowed sinc FIR
            % Equivalent to: x = ft_preproc_bandstopfilter(x, sfreq, FreqBand, [], 'firws');
            case 'fieldtrip_firws'
                % Constants
                TRANSWIDTHRATIO = 0.25;
                % Max possible transition band width
                maxTBWArray = [FreqBand * 2, (Fnyq - FreqBand) * 2, diff(FreqBand)];
                maxDf = min(maxTBWArray);
                % Default filter order heuristic
                df = min([max([FreqBand(1) * TRANSWIDTHRATIO, 2]) maxDf]);
                if (df > maxDf)
                    error('Transition band too wide. Maximum transition width is %.2f Hz.', maxDf)
                end
                % Compute filter order from transition width
                N = firwsord('hamming', sfreq, df, []);
                % Window
                win = bst_window('hamming', N+1);
                % Impulse response
                B = firws(N, FreqBand / Fnyq, 'stop', win);
                % Padding
                x = x';
                groupDelay = (length(B) - 1) / 2;
                startPad = repmat(x(1,:), [groupDelay 1]);
                endPad = repmat(x(end,:), [groupDelay 1]);
                % Filter data
                x = filter(B, 1, [startPad; x; endPad]);
                % Remove padded data
                x = x(2 * groupDelay + 1:end, :);
                x = x';
        end
    end
    
    % Restore the mean of the signal
    x = bst_bsxfun(@plus, x, xmean);
end


