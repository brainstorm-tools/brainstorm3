function varargout = process_bandpass( varargin )
% PROCESS_BANDPASS: Frequency filters: Lowpass/Highpass/Bandpass
%
% USAGE:                sProcess = process_bandpass('GetDescription')
%                         sInput = process_bandpass('Run', sProcess, sInput, method=[])
%        [x, FiltSpec, Messages] = process_bandpass('Compute', x, sfreq, HighPass, LowPass, Method=[], isMirror=0, isRelax=0)
%                              x = process_bandpass('Compute', x, sfreq, FiltSpec)

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
% Authors: Francois Tadel, Hossein Shahabi, John Mosher, Richard Leahy, 2010-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Band-pass filter';
    sProcess.FileTag     = @GetFileTag;
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Pre-process';
    sProcess.Index       = 64;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.processDim  = 1;   % Process channel by channel
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsFilter#What_filters_to_apply.3F';
    % Definition of the options
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
    % ==== Parameters 
    sProcess.options.label1.Comment = '<BR><U><B>Filtering parameters</B></U>:';
    sProcess.options.label1.Type    = 'label';
    % === Low bound
    sProcess.options.highpass.Comment = 'Lower cutoff frequency (0=disable):';
    sProcess.options.highpass.Type    = 'value';
    sProcess.options.highpass.Value   = {0,'Hz ',3};
    % === High bound
    sProcess.options.lowpass.Comment = 'Upper cutoff frequency (0=disable):';
    sProcess.options.lowpass.Type    = 'value';
    sProcess.options.lowpass.Value   = {40,'Hz ',3};
    % === Relax
    sProcess.options.attenuation.Comment = {'60dB', '40dB (relaxed)', 'Stopband attenuation:'; ...
                                            'strict', 'relax', ''};
    sProcess.options.attenuation.Type    = 'radio_linelabel';
    sProcess.options.attenuation.Value   = 'strict';
    % === Mirror
    sProcess.options.mirror.Comment = '<FONT color="#999999">Mirror signal before filtering (not recommended)</FONT>';
    sProcess.options.mirror.Type    = 'checkbox';
    sProcess.options.mirror.Value   = 0;
    % === Legacy
    sProcess.options.useold.Comment = '<FONT color="#999999">Use old filter implementation (before Oct 2016)</FONT>';
    sProcess.options.useold.Type    = 'checkbox';
    sProcess.options.useold.Value   = 0;
    % === Display properties
    sProcess.options.display.Comment = {'process_bandpass(''DisplaySpec'',iProcess,sfreq);', '<BR>', 'View filter response'};
    sProcess.options.display.Type    = 'button';
    sProcess.options.display.Value   = [];
end


%% ===== GET OPTIONS =====
function [HighPass, LowPass, isMirror, isRelax, Method] = GetOptions(sProcess)
    HighPass = sProcess.options.highpass.Value{1};
    LowPass  = sProcess.options.lowpass.Value{1};
    if (HighPass == 0) 
        HighPass = [];
    end
    if (LowPass == 0) 
        LowPass = [];
    end
    isMirror = sProcess.options.mirror.Value;
    isRelax  = isequal(sProcess.options.attenuation.Value, 'relax');
    % Method selection
    if (sProcess.options.useold.Value)
        Method = 'bst-fft-fir';
    else
        Method = 'bst-hfilter';
    end
end


%% ===== FORMAT COMMENT =====
function [Comment, fileTag] = FormatComment(sProcess)
    % Get options
    [HighPass, LowPass] = GetOptions(sProcess);
    % Format comment
    if ~isempty(HighPass) && ~isempty(LowPass)
        Comment = ['Band-pass:' num2str(HighPass) 'Hz-' num2str(LowPass) 'Hz'];
        fileTag = 'band';
    elseif ~isempty(HighPass)
        Comment = ['High-pass:' num2str(HighPass) 'Hz'];
        fileTag = 'high';
    elseif ~isempty(LowPass)
        Comment = ['Low-pass:' num2str(LowPass) 'Hz'];
        fileTag = 'low';
    else
        Comment = '';
    end
end


%% ===== GET FILE TAG =====
function fileTag = GetFileTag(sProcess)
    [Comment, fileTag] = FormatComment(sProcess);
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get options
    [HighPass, LowPass, isMirror, isRelax, Method] = GetOptions(sProcess);
    % Filter signals
    sfreq = 1 ./ (sInput.TimeVector(2) - sInput.TimeVector(1));
    [sInput.A, FiltSpec, Messages] = Compute(sInput.A, sfreq, HighPass, LowPass, Method, isMirror, isRelax);
    
    % Process warnings
    if ~isempty(Messages)
        bst_report('Warning', sProcess, sInput, Messages);
    end
    % Add events to represent the transients (edge effects)
    if ~isempty(FiltSpec) && isfield(FiltSpec, 'transient')
        % Time windows with filter transients (two extended events)
        trans = [sInput.TimeVector(1),                      sInput.TimeVector(end) - FiltSpec.transient; ...
                 sInput.TimeVector(1) + FiltSpec.transient, sInput.TimeVector(end)];
        % Create a new event type
        sInput.Events = db_template('event');
        sInput.Events.label   = 'transient';
        sInput.Events.color   = [.8 0 0];
        sInput.Events.epochs  = [1 1];
        sInput.Events.samples = round(trans .* sfreq);
        sInput.Events.times   = sInput.Events.samples ./ sfreq;
    end
    
    % File comment
    if ~isempty(HighPass) && ~isempty(LowPass)
        filterComment = ['band(' num2str(HighPass) '-' num2str(LowPass) 'Hz)'];
    elseif ~isempty(HighPass)
        filterComment = ['high(' num2str(HighPass) 'Hz)'];
    elseif ~isempty(LowPass)
        filterComment = ['low(', num2str(LowPass) 'Hz)'];
    else
        filterComment = '';
    end
    sInput.CommentTag = filterComment;
    % Do not keep the Std field in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
end


%% ===== EXTERNAL CALL =====
% USAGE: [x, FiltSpec, Messages] = process_bandpass('Compute', x, sfreq, HighPass, LowPass, Method=[], isMirror=0, isRelax=0)
%                              x = process_bandpass('Compute', x, sfreq, FiltSpec)             
function [x, FiltSpec, Messages] = Compute(x, sfreq, HighPass, LowPass, Method, isMirror, isRelax)
    % Filter is already computed
    if (nargin == 3)
        FiltSpec = HighPass;
        Method   = 'bst-hfilter';
    % Default filter options
    else
        if (nargin < 7) || isempty(isRelax)
            isRelax = 0;
        end
        if (nargin < 6) || isempty(isMirror)
            isMirror = 0;
        end
        if (nargin < 5) || isempty(Method)
            Method = 'bst-hfilter';
        end
        FiltSpec = [];
    end
    Messages = [];
    
    % Filtering using the selected method
    switch (Method)
        % Shahabi/Leahy, 2016    [DEFAULT IN BRAINSTORM AFTER 2016]
        case 'bst-hfilter'
            if ~isempty(FiltSpec)
                [x, tmp, Messages] = bst_bandpass_hfilter(x, sfreq, FiltSpec);
            else
                [x, FiltSpec, Messages] = bst_bandpass_hfilter(x, sfreq, HighPass, LowPass, isMirror, isRelax);
            end
        
        % Baillet, 2010-2012
        % Faster filter, but not all the cases are handled properly  (2012)
        case 'bst-fft'
            x = bst_bandpass_fft(x, sfreq, HighPass, LowPass, 0, isMirror);
        % Baillet, 2010-2012   [DEFAULT IN BRAINSTORM 2010-2016]
        % Better filter, a bit slower
        case 'bst-fft-fir'
            x = bst_bandpass_fft(x, sfreq, HighPass, LowPass, 1, isMirror);
            
        % Mosher, 2014:   Never used
        case 'bst-filtfilt-fir'
            x = bst_bandpass_filtfilt(x, sfreq, HighPass, LowPass, 0, 'fir');
        case 'bst-filtfilt-iir'
            x = bst_bandpass_filtfilt(x, sfreq, HighPass, LowPass, 0, 'iir');

        % Mosher, 2010:   Filter using SOS functions: too slow, unstable...
        case 'bst-sos'
            % Prepare options structure
            coef.LowPass = LowPass;
            coef.HighPass = HighPass;
            % Filter signal
            x = bst_bandpass_sos(x, sfreq, coef);
    end
end


%% ===== DISPLAY FILTER SPECS =====
function DisplaySpec(iProcess, sfreq) %#ok<DEFNU>
    % Get current process options
    global GlobalData;
    sProcess = GlobalData.Processes.Current(iProcess);
    % Progress bar
    bst_progress('start', 'Filter specifications', 'Updating graphs...');
    % Get options
    [HighPass, LowPass, isMirror, isRelax, Method] = GetOptions(sProcess);    
    % Compute filter specification
    if strcmpi(Method, 'bst-hfilter')
        [tmp, FiltSpec, Messages] = bst_bandpass_hfilter([], sfreq, HighPass, LowPass, isMirror, isRelax);
        if isempty(FiltSpec)
            bst_error(Messages, 'Filter response', 0);
        end
    else
        bst_error('The filter response cannot be displayed for this method.', 'Filter response', 0);
        return;
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
    
    % Compute filter response
    if bst_get('UseSigProcToolbox')
        [Hf,Freqs] = freqz(FiltSpec.b, FiltSpec.a, 2^14, sfreq);
        [Ht,t] = impz(FiltSpec.b, FiltSpec.a, [], sfreq);
    else
        [Hf,Freqs] = oc_freqz(FiltSpec.b, FiltSpec.a, 2^14, sfreq);
        [Ht,t] = oc_impz(FiltSpec.b, FiltSpec.a, [], sfreq);
    end
    % Plot frequency response
    hAxesFreqz = axes('Units', 'pixels', 'Parent', hFig, 'Tag', 'AxesFreqz');
    Hf = 20.*log10(abs(Hf));
    plot(hAxesFreqz, Freqs, Hf);
    % Plot impulse response
    hAxesImpz = axes('Units', 'pixels', 'Parent', hFig, 'Tag', 'AxesImpz');
    t = t - t(round(length(t)/2));
    plot(hAxesImpz, t, Ht);
    
    % Add legends
    title(hAxesFreqz, 'Frequency response');
    xlabel(hAxesFreqz, 'Frequency (Hz)');
    ylabel(hAxesFreqz, 'Magnitude (dB)');
    title(hAxesImpz, 'Impulse response');
    xlabel(hAxesImpz, 'Time (seconds)');
    ylabel(hAxesImpz, 'Amplitude');
    % Configure axes limits
    dF = Freqs(2) - Freqs(1);
    if isempty(LowPass) || (LowPass == 0)
        set(hAxesFreqz, 'XLim', [0, min(3*max(dF,HighPass), max(Freqs))]);
    else
        set(hAxesFreqz, 'XLim', [0, min(max(5*LowPass, sfreq/8), max(Freqs))]);
    end
    set(hAxesFreqz, 'YLim', [min(Hf), max(Hf)] + (max(Hf)-min(Hf)) .* [-0.05,0.05]);
    YLimImpz = [min(Ht), max(Ht)] + (max(Ht)-min(Ht)) .* [-0.05,0.05];
    set(hAxesImpz, 'XLim', [min(t), max(t)], 'YLim', YLimImpz);
    % Add grids
    set([hAxesFreqz, hAxesImpz], 'XGrid', 'on', 'YGrid', 'on');
    % Enable zooming by default
    zoom(hFig, 'on');
    
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
    
    % Filter description: Left panel
    strFilter1 = ['<HTML>Even-order linear phase <B>FIR filter</B>' '<BR>'];
    if ~isempty(HighPass) && (HighPass > 0) && ~isempty(LowPass) && (LowPass > 0)
        strFilter1 = [strFilter1 'Band-pass: &nbsp;&nbsp;<B>' num2str(HighPass) '-' num2str(LowPass) ' Hz</B><BR>'];
        strFilter1 = [strFilter1 'Low transition: &nbsp;&nbsp;<B>' num2str(FiltSpec.fcuts(1)) '-' num2str(FiltSpec.fcuts(2)) ' Hz</B><BR>'];
        strFilter1 = [strFilter1 'High transition: &nbsp;&nbsp;<B>' num2str(FiltSpec.fcuts(3)) '-' num2str(FiltSpec.fcuts(4)) ' Hz</B><BR>'];
    elseif ~isempty(HighPass) && (HighPass > 0)
        strFilter1 = [strFilter1 'High-pass: &nbsp;&nbsp;<B>' num2str(HighPass) ' Hz</B><BR>'];
        strFilter1 = [strFilter1 'Transition: &nbsp;&nbsp;<B>' num2str(FiltSpec.fcuts(1)) '-' num2str(FiltSpec.fcuts(2)) ' Hz</B><BR>'];
    elseif ~isempty(LowPass) && (LowPass > 0)
        strFilter1 = [strFilter1 'Low-pass: &nbsp;&nbsp;<B>' num2str(LowPass) ' Hz</B><BR>'];
        strFilter1 = [strFilter1 'Transition: &nbsp;&nbsp;<B>' num2str(FiltSpec.fcuts(1)) '-' num2str(FiltSpec.fcuts(2)) ' Hz</B><BR>'];
    end
    if isRelax
        strFilter1 = [strFilter1 'Stopband attenuation: &nbsp;&nbsp;<B>40 dB</B><BR>'];
    else
        strFilter1 = [strFilter1 'Stopband attenuation: &nbsp;&nbsp;<B>60 dB</B><BR>'];
    end
    % Filter description: Right panel
    strFilter2 = '<HTML>';
    strFilter2 = [strFilter2 'Filter order: &nbsp;&nbsp;<B>' num2str(FiltSpec.order) '</B><BR>'];
    strFilter2 = [strFilter2 'Transient (full): &nbsp;&nbsp;<B>' num2str(FiltSpec.order / 2 / sfreq, '%1.3f') ' s</B><BR>'];
    strFilter2 = [strFilter2 'Transient (99% energy): &nbsp;&nbsp;<B>' num2str(FiltSpec.transient, '%1.3f') ' s</B><BR>'];
    strFilter2 = [strFilter2 'Sampling frequency: &nbsp;&nbsp;<B>', num2str(sfreq), ' Hz</B><BR>'];
    strFilter2 = [strFilter2 'Frequency resolution: &nbsp;&nbsp;<B>' num2str(dF, '%1.3f') ' Hz</B><BR>'];

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


