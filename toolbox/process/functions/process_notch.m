function varargout = process_notch( varargin )
% PROCESS_NOTCH: Remove one or more sinusoids from a signal
%
% USAGE:      sProcess = process_notch('GetDescription')
%               sInput = process_notch('Run',     sProcess, sInput)
%                    x = process_notch('Compute', x, sfreq, FreqList, Method, bandWidth=1)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% The "hnotch" filter is implemented based on: 
% Mitra, Sanjit Kumar, and Yonghong Kuo. Digital signal processing: a computer-based approach. Vol. 2. New York: McGraw-Hill, 2006.
%
% The older code inspired from MatlabCentral post:
% http://www.mathworks.com/matlabcentral/newsreader/view_thread/292960

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Notch filter';
    sProcess.FileTag     = 'notch';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Pre-process';
    sProcess.Index       = 66;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsFilter#Filter_specifications:_Notch';
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
    sProcess.options.freqlist.Comment = 'Frequencies to remove (Hz):';
    sProcess.options.freqlist.Type    = 'value';
    sProcess.options.freqlist.Value   = {[], 'list', 2};
    % === 3-dB bandwidth
    sProcess.options.cutoffW.Comment = '3-dB notch bandwidth:';
    sProcess.options.cutoffW.Type    = 'value';
    sProcess.options.cutoffW.Value   = {1, 'Hz', 2};
    % === Legacy
    sProcess.options.useold.Comment = '<FONT color="#999999">Use old filter implementation (before 2019)</FONT>';
    sProcess.options.useold.Type    = 'checkbox';
    sProcess.options.useold.Value   = 0;
    % === Display properties
    sProcess.options.display.Comment = {'process_notch(''DisplaySpec'',iProcess,sfreq);', '<BR>', 'View filter response'};
    sProcess.options.display.Type    = 'button';
    sProcess.options.display.Value   = [];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    if isempty(sProcess.options.freqlist.Value{1})
        Comment = 'Notch filter: No frequency selected';
    else
        strValue = sprintf('%1.0fHz ', sProcess.options.freqlist.Value{1});
        Comment = ['Notch filter: ' strValue(1:end-1)];
    end
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get options
    FreqList = sProcess.options.freqlist.Value{1};
    if isempty(FreqList) || isequal(FreqList, 0)
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
    % Method 
    if (sProcess.options.useold.Value)
        Method = 'fixed-width' ; 
        bandWidth = [] ; 
    else
        Method = 'hnotch' ;
        bandWidth = sProcess.options.cutoffW.Value{1} ;
    end  
    % Filter data
    [sInput.A, FiltSpec, Messages] = Compute(sInput.A, sfreq, FreqList, Method, bandWidth);
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
        sInput.Events.label   = 'transient_notch';
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
% USAGE: x = process_notch('Compute', x, sfreq, FreqList)
function [x, FiltSpec, Messages] = Compute(x, sfreq, FreqList, Method, bandWidth)
    % Use the signal processing toolbox?
    UseSigProcToolbox = bst_get('UseSigProcToolbox');
    % Check list of freq to remove
    if isempty(FreqList) || isequal(FreqList, 0)
        return;
    end
    if (nargin < 5) || isempty(bandWidth)
        bandWidth = 1 ;  % Default bandwidth in Hz
    end
    if (nargin < 4) || isempty(Method)
        Method = 'hnotch' ;
    end
    % Define a default width
    % Remove the mean of the data before filtering
    xmean = mean(x,2);
    x = bst_bsxfun(@minus, x, xmean);
    % Remove all the frequencies sequencially
    for ifreq = 1:length(FreqList)
        % Define coefficients of an IIR notch filter
        w0 = 2 * pi * FreqList(ifreq) / sfreq;      %Normalized notch frequncy
        % Pole radius
        switch Method
            case 'hnotch' % (Default after 2019)  radius by a user defined bandwidth (-3dB)
                beta  = cos(w0) ; 
                Bw    = (2 * pi * bandWidth) / sfreq ;   % bandwidth in radians
                alpha = -((-(cos(Bw) - 1)*(cos(Bw) + 1))^(1/2) - 1)/cos(Bw) ; 
                % Gain factor
                B0    = (1+alpha)/2 ; 
                % Numerator coefficients
                B     = B0 * [1 -2*beta 1] ; 
                % Denominator coefficients
                A     = [1 -beta*(1+alpha) alpha] ;
                
            case 'fixed-width'    % radius using a fixed bandwidth (before 2019)
                FreqWidth = 1;
                delta     = FreqWidth/2;
                r         = 1 - (delta * pi / sfreq);
                % Gain factor
                B0 = abs(1 - 2*r*cos(w0) + r^2) / (2*abs(1-cos(w0)));
                % Numerator coefficients
                B = B0 * [1, -2*cos(w0), 1];
                % Denominator coefficients
                A = [1, -2*r*cos(w0), r^2];
        end

        % Output structure
        FiltSpec.b(ifreq,:) = B;
        FiltSpec.a(ifreq,:) = A;
        
        % Filter signal
        if ~isempty(x)
            if UseSigProcToolbox
                x = filtfilt(B,A,x')';
            else
                x = filter(B,A,x')';
                x(:,end:-1:1) = filter(B,A,x(:,end:-1:1)')';
            end
        end
    end
    % Restore the mean of the signal
    if ~isempty(x)
        x = bst_bsxfun(@plus, x, xmean);
    end
    
    % Find the general transfer function
    Num1 = FiltSpec.b';
    Den1 = FiltSpec.a';
    tmpn = (size(Num1,1)-1)*size(Num1,2)+1;
    FiltSpec.NumT  = ifft(prod(fft(Num1,tmpn),2),'symmetric');
    FiltSpec.DenT  = ifft(prod(fft(Den1,tmpn),2),'symmetric');
    FiltSpec.order = length(FiltSpec.DenT)-1 ;
    [h,t] = impz(FiltSpec.NumT,FiltSpec.DenT,[],sfreq);
    % Compute the cumulative energy of the impulse response
    E = h(1:end) .^ 2 ;
    E = cumsum(E) ;
    E = E ./ max(E) ;
    % Compute the effective transient: Number of samples necessary for having 99% of the impulse response energy
    [tmp, iE99] = min(abs(E - 0.99)) ;
    FiltSpec.transient      = iE99 / sfreq ;
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
    FreqList = sProcess.options.freqlist.Value{1};
    % Method 
    if (sProcess.options.useold.Value)
        Method = 'fixed-width' ; 
        bandWidth = [] ; 
    else
        Method = 'hnotch' ;
        bandWidth = sProcess.options.cutoffW.Value{1} ;
    end
    % Compute filter specification
    [tmp, FiltSpec, Messages] = Compute([], sfreq, FreqList, Method, bandWidth) ;
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
%     % Filter description: Left panel
    strFilter1 = ['<HTML>Second-order <B>IIR notch filter</B>' '<BR>'];
    strFilter1 = [strFilter1 'Absolute value of the largest pole: &nbsp;&nbsp;<B>' num2str(max(abs(roots(a)))) '</B><BR>'];
    
    % Filter description: Right panel
    strFilter2 = '<HTML>';
    strFilter2 = [strFilter2 'Filter order (# of poles): &nbsp;&nbsp;<B>' num2str(FiltSpec.order) '</B><BR>'];
    strFilter2 = [strFilter2 'Transient (full): &nbsp;&nbsp;<B>' num2str(length(Ht) / sfreq, '%1.3f') ' s</B><BR>'];
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
