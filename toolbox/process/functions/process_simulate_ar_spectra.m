function varargout = process_simulate_ar_spectra( varargin )
% PROCESS_SIMULATE_AR_SPECTRA: Simulate source signals with an auto-regressive model
% Using this ARfit toolbox: https://climate-dynamics.org/software/#arfit
% The interactions in the AR model are defined as spectral peaks (frequency and magnitude) 
% Coefficients are computed with the function DesignTwoPoles()
%
% USAGE:   OutputFiles = process_simulate_ar_spectra('Run', sProcess, sInputA)
%               signal = process_simulate_ar_spectra('Compute', b, A, C, nsamples)
%               sFiles = process_simulate_ar_spectra('Test')
 
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
% Authors: Raymundo Cassani, 2021-2022
%          Francois Tadel, 2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Simulate AR signals';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Simulate'; 
    sProcess.Index       = 902; 
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity2#Simulated_data';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;

    % === SUBJECT NAME
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = 'Test';
    % === CONDITION NAME
    sProcess.options.condition.Comment = 'Condition name:';
    sProcess.options.condition.Type    = 'text';
    sProcess.options.condition.Value   = 'Simulation';
    % === NUMBER OF SAMPLES
    sProcess.options.samples.Comment = 'Number of time samples:';
    sProcess.options.samples.Type    = 'value';
    sProcess.options.samples.Value   = {12000, ' (Ntime)', 0};
    % === SAMPLING FREQUENCY
    sProcess.options.srate.Comment = 'Signal sampling frequency:';
    sProcess.options.srate.Type    = 'value';
    sProcess.options.srate.Value   = {1200, 'Hz', 2};
    % === PEAKS: FREQUENCY AND AMPLITUDE 
    % === COEFFICIENT MATRIX
    sProcess.options.interactions.Comment = [
                                  'Interactions specification: <BR>' ...
                                  '<FONT color="#707070">From, To&nbsp;&nbsp;/&nbsp;&nbsp;PeakFrequencies [Hz]&nbsp;&nbsp;/&nbsp;&nbsp;PeakMagnitudes [0-1]<BR>' ...
                                  'Example:&nbsp;&nbsp;1, 2&nbsp;&nbsp;/&nbsp;&nbsp;10, 20, 40&nbsp;&nbsp;/&nbsp;&nbsp;0.5, 0.2, 1.0</FONT><BR>'];
    sProcess.options.interactions.Type    = 'textarea';
    sProcess.options.interactions.Value   = ['1, 1 / 10, 25 / 0.0, 1.0', 10 ...
                                             '2, 2 / 10, 25 / 1.0, 0.0', 10 ...
                                             '3, 3 / 10, 25 / 1.0, 0.2', 10 ...
                                             '1, 3 / 10, 25 / 0.0, 0.6'];
    % === DISPLAY SPECTRAL METRICS
    sProcess.options.display.Comment = {'process_simulate_ar_spectra(''DisplayMetrics'');', '<BR>', 'View spectral metrics'};
    sProcess.options.display.Type    = 'button';
    sProcess.options.display.Value   = [];
    % === DISPLAY COEFFICIENT MATRIX
    sProcess.options.coeff.Comment = {'process_simulate_ar_spectra(''DisplayCoefficients'');', '<BR>', 'Get coefficients matrix'};
    sProcess.options.coeff.Type    = 'button';
    sProcess.options.coeff.Value   = [];        
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== GET COEFFICIENTS =====
function [A, b, C, errMsg] = GetCoefficients(sProcess)
    % Initialize returned values
    A = [];
    b = [];
    C = [];
    errMsg = '';
    % Parse interactions
    [interactions, errMsg] = process_tf_bands('ParseBands', sProcess.options.interactions.Value);
    if ~isempty(errMsg)
        return;
    end
    nInteractions = size(interactions, 1);
    ToFroms = zeros(nInteractions, 2);   
    % Number of signals from interactions
    for i = 1: nInteractions
        FromTo = eval(['[' interactions{i,1} ']']);
        if length(FromTo) ~= 2
            errMsg = 'Direction must be a pair of values: From, To';
            return;
        end
        ToFroms(i, :) = fliplr(FromTo);
    end    
    nSignals = max(ToFroms(:));
    % Parse definition of peaks: frequency and magnitude
    peaks = repmat(struct('freqs', [], 'mags', []), nSignals); % peaks(To, From)
    for i = 1: nInteractions
        peakFreqs = eval(['[' interactions{i,2} ']']);
        peakMags  = eval(['[' interactions{i,3} ']']);
        if length(peakFreqs) ~= length(peakMags)
            errMsg = 'Number of frequencies must match number of magnitudes';
            return;
        end       
        peaks(ToFroms(i,1), ToFroms(i,2)).freqs = peakFreqs;
        peaks(ToFroms(i,1), ToFroms(i,2)).mags  = peakMags;
    end
    % Find the maximum order requested (2 * maximun_requested_peaks)
    nOrder = max(max(arrayfun(@(x) length(x.freqs),peaks))) * 2;
    % Signal sampling frequency [Hz]
    sfreq = sProcess.options.srate.Value{1}; 
    
    % Compute coefficients
    A = zeros(nSignals, nSignals, nOrder); % To, From, Order 
    for iFrom = 1 : nSignals
        for iTo = 1 : nSignals
            frqs = peaks(iTo, iFrom).freqs;
            mags = peaks(iTo, iFrom).mags;
            if ~isempty(frqs)
                [~, a] = DesignTwoPoles(sfreq, frqs, mags, nOrder);
                A(iTo, iFrom, :) = -a(2:end);
            end
        end
    end
    A = reshape(A, nSignals, nSignals * nOrder);
    b = zeros(1, nSignals);
    C = eye(nSignals, nSignals);    
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputA) %#ok<DEFNU>
    OutputFiles = {};
    % === GET OPTIONS ===
    % Get subject name
    SubjectName = file_standardize(sProcess.options.subjectname.Value);
    if isempty(SubjectName)
        bst_report('Error', sProcess, sInputs, 'Subject name is empty.');
        return
    end
    % Get condition name
    Condition = file_standardize(sProcess.options.condition.Value);
    % Get signal options
    nsamples = sProcess.options.samples.Value{1};
    srate   = sProcess.options.srate.Value{1};
    
    % Get coefficients
    [A, b, C, errMsg] = GetCoefficients(sProcess);
    if ~isempty(errMsg)
        bst_report('Error', sProcess, [], errMsg);
        return;
    end
    % Generate the signal
    try
        Data = Compute(b, A, C, nsamples);
    catch
        e = lasterr();
        bst_report('Error', sProcess, [], e);
        return;
    end
    
    % ===== GENERATE FILE STRUCTURE =====
    % Create empty matrix file structure
    FileMat = db_template('matrixmat');
    FileMat.Value       = Data;
    FileMat.Time        = (0:nsamples-1) ./ srate;
    FileMat.Comment     = sprintf('Simulated AR (%dx%d)', size(Data,1), nsamples);
    FileMat.Description = cell(size(Data,1),1);
    for i = 1:size(Data,1)
        FileMat.Description{i} = ['s', num2str(i)];
    end
    % Add history entry
    FileMat = bst_history('add', FileMat, 'process', 'Simulate AR signals:');
    FileMat = bst_history('add', FileMat, 'process', ['   ' strrep(sProcess.options.interactions.Value, char(10), ' ')]);
    
    % === OUTPUT CONDITION ===
    % Get subject
    sSubject = bst_get('Subject', SubjectName);
    % Create subject if it does not exist yet
    if isempty(sSubject)
        sSubject = db_add_subject(SubjectName);
    end
    % Default condition name
    if isempty(Condition)
        Condition = 'Simulation';
    end
    % Get condition asked by user
    [sStudy, iStudy] = bst_get('StudyWithCondition', bst_fullfile(SubjectName, Condition));
    % Condition does not exist: create it
    if isempty(sStudy)
        iStudy = db_add_condition(SubjectName, Condition, 1);
        sStudy = bst_get('Study', iStudy);
    end
    
    % === SAVE FILE ===
    % Output filename
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'matrix_simar');
    % Save file
    bst_save(OutputFiles{1}, FileMat, 'v6');
    % Register in database
    db_add_data(iStudy, OutputFiles{1}, FileMat);
end


%% ===== GENERATE SIGNALS =====
% Generate synthetic AR signals
function yOut = Compute(b,A,C,samples)
    yOut = process_simulate_ar('arsim', b',A,C,samples)';
end


%% ===== DISPLAY SPECTRAL METRIC =====
function DisplayMetrics()
    % Get current process structure
    sProcess = panel_process_select('GetCurrentProcess');
    % Get options
    sfreq = sProcess.options.srate.Value{1}; % Signal sampling frequency [Hz]
    % Get coefficients
    [A,~,~,errMsg] = GetCoefficients(sProcess);
    if isempty(A)
        bst_error(['Error: Cannot compute coefficients.' 10 10 errMsg], 'Display metrics', 0);
        return;
    end
    A = reshape(A, size(A,1), size(A,1), []);
    % Display spectral metrics
    hFig = process_simulate_ar('HDisplayMetrics', A, sfreq); 
end

%% ===== DISPLAY COEFFICIENTS =====
function DisplayCoefficients()
    % Get current process structure
    sProcess = panel_process_select('GetCurrentProcess');
    % Get coefficients
    [A,~,~,errMsg] = GetCoefficients(sProcess);
    if ~isempty(errMsg)
        bst_error(['Error: Cannot compute coefficients.' 10 10 errMsg], 'Display coefficients', 0);
        return;
    end
    
    % Titles
    strTitleA = [...
        '<BR>Using the ARSIM function from ARFIT Toolbox (T.Schneider):<BR>' ...
        '&nbsp;&nbsp;&nbsp;&nbsp;X = <B>b</B> + <B>A1</B>.X1 + ... + <B>Ap</B>.Xp + <B>noise</B><BR><BR>' ... 
        'Coefficient matrix <B>A</B> =  [A1 ... Ap]<BR>' ...
        '&nbsp;&nbsp;&nbsp;&nbsp; - p is the order of the autorregresive model<BR>' ...
        '&nbsp;&nbsp;&nbsp;&nbsp; - Ai: [Nsignals_to x Nsignals_from]<BR>'];
    strTitleB = 'Intercept <B>b</B>: &nbsp;&nbsp;[1 x Nsignals]';
    strTitleC = 'Noise covariance matrix <B>C</B>: &nbsp;&nbsp;[Nsignals x Nsignals]<BR>';
    % Reshape A to [nSignals, nSignals, nOrder]
    nSignals = size(A, 1);
    A = reshape(A, nSignals, nSignals, []);
    nOrder = size(A,3);
    textA = [];
    textAtot = 'A = [';
    for iOrder = 1 : nOrder
        tmpA = A(:,:,iOrder);
        tmpTextA = evalc('disp(tmpA)');
        tmptextA = ['A', num2str(iOrder), ' = [' 10, tmpTextA(1:end-1), '];', 10];
        textA = [textA, tmptextA];
        textAtot  = [textAtot, 'A', num2str(iOrder), ' '];
    end
    textA = [textA, textAtot(1:end-1), '];'];
    
    % Text B
    textB = 'b = [';
    for iSignal = 1 : nSignals
        textB = [textB, '0 '];
    end
    textB = [textB(1:end-1), '];'];
    
    % Text C
    textC = ['C = eye(', num2str(nSignals), ', ', num2str(nSignals), ');'];
    
    % Using uifigure
    if exist('uitextarea', 'file')
        % Get existing specification figure
        hFig = findall(0, 'Type', 'Figure', 'Tag', 'CoeffMatrix');
        % If the figure doesn't exist yet: create it
        if isempty(hFig)
            hFig = uifigure(...
                'Name',   'AR Coefficients', ...
                'Tag',    'CoeffMatrix', ...
                'Units',  'Pixels');
        % Figure already exists: re-use it
        else
            clf(hFig);
            figure(hFig);
        end
        figpos = get(hFig, 'Position');
        wLabel = figpos(3) - 60;
        
        % Display A
        labelA = uilabel(hFig, ...
            'Position', [30, 260, wLabel, 220], ...
            'Text', strTitleA, ...
            'Interpreter', 'html', ...
            'FontSize', 12);
        textareaA = uitextarea(hFig, ...
            'Position',[30, 165, wLabel, 150], ...
            'Value', textA, ...
            'WordWrap', 'off');
        % Display B
        labelB = uilabel(hFig, 'Position', [30, 135, wLabel, 20], ...
                 'Text', strTitleB, ...
                 'Interpreter', 'html', 'FontSize', 12);
        textareaB = uitextarea(hFig, 'Position',[30, 105, wLabel, 30], ...
                                     'Value', textB, ...
                                     'WordWrap', 'off');
        % Display C
        labelC = uilabel(hFig, 'Position', [30, 75, wLabel, 20], ...
                 'Text', strTitleC, ...
                 'Interpreter', 'html', 'FontSize', 12);
        textareaC = uitextarea(hFig, 'Position',[30, 45, wLabel, 30], ...
                                     'Value', textC, ...
                                     'WordWrap', 'off');
    % Otherwise, just display as text                         
    else
        strFigure = [...
            str_striptag(strrep(strTitleA, '<BR>', char(10))), ...
            '-------------------------------------------------' 10 ...
            textA 10, ...
            '-------------------------------------------------' 10 10, ...
            str_striptag(strrep(strTitleB, '<BR>', char(10))), ...
            10 '-------------------------------------------------' 10 ...
            textB 10, ...
            '-------------------------------------------------' 10 10, ...
            str_striptag(strrep(strTitleC, '<BR>', char(10))), ...
            '-------------------------------------------------' 10 ...
            textC 10 ...
            '-------------------------------------------------' 10];
        view_text(strFigure, 'AR Coefficients');
    end
end


%% ===== DESIGN TWO POLES FILTER =====
function [b, a, n_order, rads, bws, rel_gains] = DesignTwoPoles(fs, freqs, gains, n_order)
% Computes a filter with two-poles peak 
% A peak is defined by its frequency and its gain 
% FREQS are peak frequencies in Hz
% GAINS are relative gains in [0,1] range, 
%   GAINS are relative with 1 = to gain for FS/4 peak with BW = 1Hz
%
% References
% [1] Ifeachor, EC (1993), Digital signal processing: A practical approach.
%     Chapter: Design of IIR digital filters ISBN: 020154413X 
% [2] Smith, JO (2007), Introduction to digital filters: With audio applications
%     Appendix: Elementary Audio Digital Filters ISBN: 0974560715

    % Compute gain for frequency peak at Fs/4 @ BW = 1 Hz;
    bw_ref = 1;
    radius_ref = exp(-pi * bw_ref / fs);
    theta_ref  = (fs/4) / fs * 2 * pi;
    gain_ref   = 1 / ((1 - radius_ref) * sqrt(1 - (2 * radius_ref * cos(2 * theta_ref))  + (radius_ref .^ 2)));

    % Number of peaks and order of filter
    n_peaks = length(freqs);
    if isempty(n_order)
        n_order = 2 * n_peaks;
    end

    % Find radius for each peak, and compute filter
    for i_peak = 1 : n_peaks
        % Estimate radius for given peak
        peak_theta = (freqs(i_peak) / fs) * 2 * pi;
        % Range to explore
        radius_range = 0 : 0.001 : 1; 
        gain_range = (1 / gain_ref) ./ ((1 - radius_range) .* sqrt(1 - (2 .* radius_range .* cos(2 * peak_theta))  + (radius_range .^ 2)));
        [~, ix] = min(abs(gain_range - gains(i_peak)));
        rads(i_peak) = radius_range(ix);
        rel_gains(i_peak) = gain_range(ix); 
        bws(i_peak) = -log(rads(i_peak)) * fs / pi;
        % Two poles
        poles_peak = rads(i_peak) .* exp(1i * peak_theta);
        poles_peak = transpose([poles_peak, conj(poles_peak)]);
        % Compute one SOS
        [bs{i_peak},as{i_peak}] = zp2tf([], poles_peak, 1);
    end

    % Convolve coefficients
    a = as{1};
    b = 1;
    for i_peak = 2 : n_peaks
        a = conv(a, as{i_peak});
    end

    % Complete order if required
    if length(a) ~= n_order +1
        n_miss = n_order - (length(a) - 1);
        a = conv([1, zeros(1, n_miss)], a);
    end
end

%% ===== TEST FUNCTION =====
function sFiles = Test() %#ok<DEFNU>
    % Three-variable AR model
    sFiles = bst_process('CallProcess', 'process_simulate_ar_spectra', [], [], ...
        'subjectname', 'Test', ...
        'condition',   'Simulation', ...
        'samples',     12000, ...
        'srate',       100, ...
        'interactions' , ['1, 1 / 10, 25 / 0.0, 1.0', 10 ...
                          '2, 2 / 10, 25 / 1.0, 0.0', 10 ...
                          '3, 3 / 10, 25 / 1.0, 0.2', 10 ...
                          '1, 3 / 10, 25 / 0.0, 0.6']);
end

