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
    sProcess.options.freqlist.Comment = 'Frequencies to remove:';
    sProcess.options.freqlist.Type    = 'value';
    sProcess.options.freqlist.Value   = {[], 'list', 2};
    % === Freq width
    sProcess.options.freqwidth.Comment = 'Width of the frequency bands:';
    sProcess.options.freqwidth.Type    = 'value';
    sProcess.options.freqwidth.Value   = {1.5, 'Hz', 1};
    % === Display properties
    sProcess.options.display.Comment = {'process_bandstop(''DisplaySpec'',iProcess,sfreq);', '<BR>', 'View filter response'};
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
    FreqList  = sProcess.options.freqlist.Value{1};
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
        sInput.Events.label   = 'transient_bandstop';
        sInput.Events.color   = [.8 0 0];
        sInput.Events.epochs  = [1 1];
        sInput.Events.samples = round(trans .* sfreq);
        sInput.Events.times   = sInput.Events.samples ./ sfreq;
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
                FiltSpec.b(ifreq,:) = B;
                FiltSpec.a(ifreq,:) = A;
                % Filter signal
                if ~isempty(x)
                    x = filtfilt(B, A, x')';
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
            if length(FreqList)>1
                for ifreq = 2:length(FreqList)
                    FiltSpec.NumT = conv(FiltSpec.NumT,FiltSpec.b(ifreq,:)) ; 
                    FiltSpec.DenT = conv(FiltSpec.DenT,FiltSpec.a(ifreq,:)) ; 
                end
            end
            FiltSpec.order = length(FiltSpec.DenT)-1 ; 
            % Compute the cumulative energy of the impulse response
            [h,t] = impz(FiltSpec.NumT,FiltSpec.DenT,[],sfreq);
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
function DisplaySpec(iProcess, sfreq) %#ok<DEFNU>
    % Get current process options
    global GlobalData;
    sProcess = GlobalData.Processes.Current(iProcess);
    % Progress bar
    bst_progress('start', 'Filter specifications', 'Updating graphs...');
    % Get options
    FreqList  = sProcess.options.freqlist.Value{1};
    FreqWidth = sProcess.options.freqwidth.Value{1};
    method    = 'fieldtrip_butter';
    % Compute filter specification
    [tmp, FiltSpec, Messages] =  Compute([], sfreq, FreqList, FreqWidth, method);
    if isempty(FiltSpec)
        bst_error(Messages, 'Filter response', 0);
    end

    % Get existing specification figure
    hFig = findobj(0, 'Type', 'Figure', 'Tag', 'FilterSpecs');
    % If the figure doesn't exist yet: create it
    if isempty(hFig)
        hFig = figure(...
            'MenuBar',     'none', ...
            ... 'Toolbar',     'none', ...
            'Toolbar',     'figure', ...
            'NumberTitle', 'off', ...
            'Name',        sprintf('Filter properties'), ...
            'Tag',         'FilterSpecs', ...
            'Units',       'Pixels');
    % Figure already exists: re-use it
    else
        clf(hFig);
        figure(hFig);
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
    % Plot frequency response
    hAxesFreqz = axes('Units', 'pixels', 'Parent', hFig, 'Tag', 'AxesFreqz');
    Hf = 20.*log10(abs(Hf));
    plot(hAxesFreqz, Freqs, Hf,'linewidth',1.5);
    % Plot impulse response
    hAxesImpz = axes('Units', 'pixels', 'Parent', hFig, 'Tag', 'AxesImpz');
    stem(hAxesImpz, t, Ht);
    
    % Add legends
    title(hAxesFreqz, 'Frequency response');
    xlabel(hAxesFreqz, 'Frequency (Hz)');
    ylabel(hAxesFreqz, 'Magnitude (dB)');
    title(hAxesImpz, 'Impulse response');
    xlabel(hAxesImpz, 'Time (seconds)');
    ylabel(hAxesImpz, 'Amplitude');
    
    % Configure axes limits
%     dF = Freqs(2) - Freqs(1);
    set(hAxesFreqz, 'XLim', [Freqs(1) Freqs(end)]); 
    set(hAxesFreqz, 'YLim', [min(Hf), max(Hf)] + (max(Hf)-min(Hf)) .* [-0.05,0.05]);
    YLimImpz = [min(Ht), max(Ht)] + (max(Ht)-min(Ht)) .* [-0.05,0.05];
    set(hAxesImpz, 'XLim', [min(t), max(t)], 'YLim', YLimImpz);
    % Add grids
    set([hAxesFreqz, hAxesImpz], 'XGrid', 'on', 'YGrid', 'on');
    % Enable zooming by default
    zoom(hFig, 'on');
%     
    % Plot vertical lines to indicate effective transients (99% energy)
    line(FiltSpec.transient.*[1 1], YLimImpz, -0.1.*[1 1], ...
        'LineWidth', 1, ...
        'Color',     [.7 .7 .7], ...
        'Parent',    hAxesImpz);
    line(FiltSpec.transient.*[-1 -1], YLimImpz, -0.1.*[1 1], ...
        'LineWidth', 1, ...
        'Color',     [.7 .7 .7], ...
        'Parent',    hAxesImpz);
    text(FiltSpec.transient .* 1.1, YLimImpz(2), '99% energy', ...
        'Color',               [.7 .7 .7], ...
        'FontSize',            bst_get('FigFont'), ...
        'FontUnits',           'points', ...
        'VerticalAlignment',   'top', ...
        'HorizontalAlignment', 'left', ...
        'Parent',              hAxesImpz);
%     
%   % Filter description: Left panel
    strFilter1 = ['<HTML>Zero-phase <B>IIR Butterworth filter</B>' '<BR>'];
    strFilter1 = [strFilter1 'Absolute value of the largest pole: &nbsp;&nbsp;<B>' num2str(max(abs(roots(a)))) '</B><BR>'];

    % Filter description: Right panel
    strFilter2 = '<HTML>';
    strFilter2 = [strFilter2 'Filter order (# of poles): &nbsp;&nbsp;<B>' num2str(FiltSpec.order) '</B><BR>'];
    strFilter2 = [strFilter2 'Transient (full): &nbsp;&nbsp;<B>' num2str(length(Ht) / 2 / sfreq, '%1.3f') ' s</B><BR>'];
    strFilter2 = [strFilter2 'Transient (99% energy): &nbsp;&nbsp;<B>' num2str(FiltSpec.transient, '%1.3f') ' s</B><BR>'];
    strFilter2 = [strFilter2 'Sampling frequency: &nbsp;&nbsp;<B>', num2str(sfreq), ' Hz</B><BR>'];

    % Display left panel
    [jLabel1, hLabel1] = javacomponent(javax.swing.JLabel(strFilter1), [0 0 1 1], hFig);
    set(hLabel1, 'Units', 'pixels', 'BackgroundColor', get(hFig, 'Color'), 'Tag', 'Label1');
    bgColor = get(hFig, 'Color');
    jLabel1.setBackground(java.awt.Color(bgColor(1),bgColor(2),bgColor(3)));
    jLabel1.setVerticalAlignment(javax.swing.JLabel.TOP);
    % Display right panel
    [jLabel2, hLabel2] = javacomponent(javax.swing.JLabel(strFilter2), [0 0 1 1], hFig);
    set(hLabel2, 'Units', 'pixels', 'BackgroundColor', get(hFig, 'Color'), 'Tag', 'Label2');
    bgColor = get(hFig, 'Color');
    jLabel2.setBackground(java.awt.Color(bgColor(1),bgColor(2),bgColor(3)));
    jLabel2.setVerticalAlignment(javax.swing.JLabel.TOP);
    
    % Set resize function
    set(hFig, bst_get('ResizeFunction'), @ResizeCallback);
    % Force calling the resize function at least once
    ResizeCallback(hFig);
    bst_progress('stop');
    
    % Resize function
    function ResizeCallback(hFig, ev)
        % Get figure position
        figpos = get(hFig, 'Position');
        textH = 90;
        marginL = 70;
        marginR = 30;
        marginT = 30;
        marginB = 50;
        axesH = round((figpos(4) - textH) ./ 2);
        % Position axes
        set(hAxesFreqz, 'Position', max(1, [marginL, textH + marginB + axesH, figpos(3) - marginL - marginR, axesH - marginB - marginT]));
        set(hAxesImpz,  'Position', max(1, [marginL, textH + marginB,         figpos(3) - marginL - marginR, axesH - marginB - marginT]));
        set(hLabel1,    'Position', max(1, [40,                  1,  round((figpos(3)-40)/2),  textH]));
        set(hLabel2,    'Position', max(1, [round(figpos(3)/2),  1,  round(figpos(3)/2),       textH]));
    end
end
