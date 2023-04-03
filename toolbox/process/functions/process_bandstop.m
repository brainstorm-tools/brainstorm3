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
% Authors: Hossein Shahabi, Francois Tadel, 2014-2019
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
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
    
    % Definition of the options
    % === Freq list
    sProcess.options.freqlist.Comment = 'Center of bandstop filter:';
    sProcess.options.freqlist.Type    = 'value';
    sProcess.options.freqlist.Value   = {[], 'Hz', 2};
    % === Freq width
    sProcess.options.freqwidth.Comment = '3-dB bandstop bandwidth:';
    sProcess.options.freqwidth.Type    = 'value';
    sProcess.options.freqwidth.Value   = {1.5, 'Hz', 2};
    % === Display properties
    sProcess.options.display.Comment = {'process_bandstop(''DisplaySpec'',sfreq);', '<BR>', 'View filter response'};
    sProcess.options.display.Type    = 'button';
    sProcess.options.display.Value   = [];
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
    FreqList  = sProcess.options.freqlist.Value{1}; % It is no longer a list (only a single frequency)
    FreqWidth = sProcess.options.freqwidth.Value{1};
    if isempty(FreqList) || isequal(FreqList, 0) || (FreqWidth <= 0)
        bst_report('Error', sProcess, [], 'No frequency in input.');
        sInput = [];
        return;
    end
    if length(FreqList)>1
        bst_report('Error', sProcess, [], 'Only one frequency band is allowed.');
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
    [sInput.A, FiltSpec, Messages] = Compute(sInput.A, sfreq, FreqList, FreqWidth, 'fieldtrip_butter');
    
    % Process warnings
    if ~isempty(Messages)
        bst_report('Warning', sProcess, sInput, Messages);
    end
    
    % Add events to represent the transients (edge effects)
    if ~isempty(FiltSpec) && isfield(FiltSpec, 'transient')
        % Time windows with filter transients (two extended events)
        trans = [sInput.TimeVector(1), sInput.TimeVector(end) - FiltSpec.transient; ...
            sInput.TimeVector(1) + FiltSpec.transient, sInput.TimeVector(end)];
        % Create a new event type
        sInput.Events = db_template('event');
        sInput.Events.label    = 'transient_bandstop';
        sInput.Events.color    = [.8 0 0];
        sInput.Events.epochs   = [1 1];
        sInput.Events.times    = round(trans .* sfreq) ./ sfreq;
        sInput.Events.channels = [];
        sInput.Events.notes    = [];
    end
    
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
function [x, FiltSpec, Messages] = Compute(x, sfreq, FreqList, FreqWidth, method)
    % Define a default method and width
    if (nargin < 4) || isempty(FreqWidth) || isempty(method)
        method = 'fieldtrip_butter';
        FreqWidth = 1.5;
    end
    % Use the signal processing toolbox?
    if bst_get('UseSigProcToolbox')
        filtfilt_fcn = @filtfilt;
        butter_fcn = @butter;
    else
        filtfilt_fcn = @oc_filtfilt;
        butter_fcn = @oc_butter;
    end
    % Check list of freq to remove
    if isempty(FreqList) || isequal(FreqList, 0)
        return;
    end
    % Nyqist frequency
    Fnyq = sfreq/2;
    % Remove the mean of the data before filtering
    if ~isempty(x)
        xmean = mean(x,2);
        x = bst_bsxfun(@minus, x, xmean);
    end
    
    % Remove all the frequencies sequencially
    for ifreq = 1 %:length(FreqList)
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
                [B,A] = butter_fcn(N, FreqBand ./ Fnyq, 'stop');
                FiltSpec.b(ifreq,:) = B;
                FiltSpec.a(ifreq,:) = A;
                % Filter signal
                if ~isempty(x)
                    x = filtfilt_fcn(B, A, x')';
                end

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
    if ~isempty(x)
        x = bst_bsxfun(@plus, x, xmean);
    end
    
    % Find the general transfer function
    switch (method)
        case 'fieldtrip_butter'
            FiltSpec.NumT = FiltSpec.b(1,:) ; 
            FiltSpec.DenT = FiltSpec.a(1,:) ; 
            FiltSpec.order = length(FiltSpec.DenT)-1 ;
            % Compute the cumulative energy of the impulse response
            if bst_get('UseSigProcToolbox')
                [h,t] = impz(FiltSpec.NumT,FiltSpec.DenT,[],sfreq);
            else
                [h,t] = oc_impz(FiltSpec.NumT,FiltSpec.DenT,[],sfreq);
            end
            E = h(1:end) .^ 2 ;
            E = cumsum(E) ;
            E = E ./ max(E) ;
            % Compute the effective transient: Number of samples necessary for having 99% of the impulse response energy
            [tmp, iE99] = min(abs(E - 0.99)) ;
            FiltSpec.transient      = iE99 / sfreq ;
    end
    Messages = [] ;
end


%% ===== DISPLAY FILTER SPECS =====
function DisplaySpec(sfreq)
    % Get current process structure
    sProcess = panel_process_select('GetCurrentProcess');
    % Get options
    FreqList  = sProcess.options.freqlist.Value{1};
    FreqWidth = sProcess.options.freqwidth.Value{1};
    method    = 'fieldtrip_butter';
    if isempty(FreqList) || isempty(FreqWidth)
        disp('BST> No frequencies selected.');
        return;
    end
    % Compute filter specification
    [tmp, FiltSpec, Messages] =  Compute([], sfreq, FreqList, FreqWidth, method);
    if isempty(FiltSpec)
        bst_error(Messages, 'Filter response', 0);
    end
    if length(FreqList)>1
        bst_error('Only one frequency band is allowed.', 0);
        return ; 
    end
    b = FiltSpec.NumT; 
    a = FiltSpec.DenT; 
    
    % Compute filter response
    if bst_get('UseSigProcToolbox')
        [Hf,Freqs] = freqz(b, a, 2^15, sfreq);
        [Ht,t] = impz(b, a, [], sfreq);
    else
        [Hf,Freqs] = oc_freqz(b, a, 2^15, sfreq);
        [Ht,t] = oc_impz(b, a, [], sfreq);
    end
    XFreqLim = [Freqs(1) Freqs(end)] ; 

    % Filter description: Left panel
    strFilter1 = ['<HTML> Filter type: <B>Butterworth IIR filter</B>' '<BR>'];
    strFilter1 = [strFilter1 'Absolute value of the largest pole: &nbsp;&nbsp;<B>' num2str(max(abs(roots(a)))) '</B><BR>'];

    % Filter description: Right panel
    strFilter2 = '<HTML>';
    strFilter2 = [strFilter2 'Filter order (# of poles): &nbsp;&nbsp;<B>' num2str(FiltSpec.order) '</B><BR>'];
    strFilter2 = [strFilter2 'Transient (full): &nbsp;&nbsp;<B>' num2str(length(Ht) / sfreq, '%1.3f') ' s</B><BR>'];
    strFilter2 = [strFilter2 'Transient (99% energy): &nbsp;&nbsp;<B>' num2str(FiltSpec.transient, '%1.3f') ' s</B><BR>'];
    strFilter2 = [strFilter2 'Sampling frequency: &nbsp;&nbsp;<B>', num2str(sfreq), ' Hz</B><BR>'];

    hFig = process_bandpass('HFilterDisplay',Hf,Freqs,Ht,t,FiltSpec.transient,strFilter1,strFilter2,XFreqLim) ; 
end
