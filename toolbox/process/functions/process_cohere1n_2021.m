function varargout = process_cohere1n_2021( varargin )
% PROCESS_COHERE1N_2021: Compute the coherence between all the pairs of signals, in one file.
%
% USAGE:   OutputFiles = process_cohere1n_2021('Run', sProcess, sInputA)
%                        process_cohere1n_2021('Test')

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
% Authors: Francois Tadel, 2012-2021
%          Hossein Shahabi, 2019-2020
%          Raymundo Cassani, 2021-2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Coherence NxN [2021]';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Connectivity';
    sProcess.Index       = 656;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',     'results',  'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % === CONNECT INPUT
    sProcess = process_corr1n('DefineConnectOptions', sProcess, 1);
    % === REMOVE EVOKED REPONSE
    sProcess.options.removeevoked.Comment = 'Remove evoked response from each trial';
    sProcess.options.removeevoked.Type    = 'checkbox';
    sProcess.options.removeevoked.Value   = 0;
    sProcess.options.removeevoked.Group   = 'input';
    % === COHERENCE METHOD
    sProcess.options.cohmeasure.Comment = {...
        ['<B>Magnitude-squared Coherence</B><BR>' ...
        '|C|^2 = |Cxy|^2/(Cxx*Cyy)'], ...
        ['<B>Imaginary Coherence (2019)</B><BR>' ...
        'IC    = |imag(C)|'], ...
        ['<B>Lagged Coherence (2019)</B><BR>' ...
        'LC    = |imag(C)|/sqrt(1-real(C)^2)'], ...
        ['<FONT color="#777777"> Imaginary Coherence (before 2019)</FONT><BR>' ...
        '<FONT color="#777777"> IC    = imag(C)^2 / (1-real(C)^2) </FONT>']; ...
        'mscohere', 'icohere2019', 'lcohere2019', 'icohere'};
    sProcess.options.cohmeasure.Type    = 'radio_label';
    sProcess.options.cohmeasure.Value   = 'mscohere';
    % === WINDOW LENGTH
    sProcess.options.win_length.Comment = 'Window length for PSD estimation:';
    sProcess.options.win_length.Type    = 'value';
    sProcess.options.win_length.Value   = {1, 's', []};
    % === OVERLAP
    sProcess.options.overlap.Comment = 'Overlap for PSD estimation:' ;
    sProcess.options.overlap.Type    = 'value';
    sProcess.options.overlap.Value   = {50, '%', []};
    % === HIGHEST FREQUENCY OF INTEREST
    sProcess.options.maxfreq.Comment = 'Highest frequency of interest:';
    sProcess.options.maxfreq.Type    = 'value';
    sProcess.options.maxfreq.Value   = {60,'Hz',2};
    % === OUTPUT MODE 2021
    sProcess.options.outputmode.Comment = {'Save individual results (one output file per input file)', 'Average cross-spectra of input files (one output file)'; ...
                                           'input', 'avgcoh'};
    sProcess.options.outputmode.Type    = 'radio_label';
    sProcess.options.outputmode.Value   = 'input';
    sProcess.options.outputmode.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputA) %#ok<DEFNU>
    % Input options
    OPTIONS = process_corr1n('GetConnectOptions', sProcess, sInputA);
    if isempty(OPTIONS)
        OutputFiles = {};
        return
    end
    
    % Metric options
    OPTIONS.Method = 'cohere';
    OPTIONS.RemoveEvoked  = sProcess.options.removeevoked.Value;
    OPTIONS.WinLen        = sProcess.options.win_length.Value{1};
    OPTIONS.MaxFreq       = sProcess.options.maxfreq.Value{1};
    OPTIONS.CohOverlap    = 0.50;  % First pre-define the overlap
    OPTIONS.CohMeasure    = sProcess.options.cohmeasure.Value; 

    % Change the overlap if it is specified
    if isfield(sProcess.options, 'overlap') && isfield(sProcess.options.overlap, 'Value') && ...
       iscell(sProcess.options.overlap.Value) && ~isempty(sProcess.options.overlap.Value) && ~isempty(sProcess.options.overlap.Value{1})
        OPTIONS.CohOverlap = sProcess.options.overlap.Value{1}/100 ; 
    end

    % Compute metric
    OutputFiles = bst_connectivity({sInputA.FileName}, [], OPTIONS);
end



%% ===== TEST FUNCTION =====
function Test() %#ok<DEFNU>
    % Start a new report
    bst_report('Start');
    % Get test datasets
    sFile = process_simulate_ar('Test'); % Fs = 1200 Hz
    % NOTES:
    % bst_cohn.m (2019) uses 2^nextpow2(round(Fs / MaxFreqRes)) samples 
    % of DATA for the FFT, there is no zero padding
    %
    % bst_cohn_2021.m uses nWinLen = round(WinLen * Fs) samples of DATA, 
    % that are zero padded to 2^nextpow2(nWinLen * 2) for the FFT
    %
    % To get the similar results with bst_cohn and bst_cohn_2021:
    % 1. Select a MaxFreqRes that leads to a power-of-2 number of samples, 
    % thus, we can be sure that no extra data is used in the FFT. 
    % 2. Use the duration associated to that MaxFreqRes as WinLen parameter  
    % for bst_cohn_2021, with this we will compute coherence on the same data
        
    Fs = 1200;      % Default Fs for process_simulate_ar('Test')
    nSamples = 512; % Desired number of samples 
    MaxFreqRes = Fs/nSamples; % Hz ==> round(Fs / MaxFreqRes) = 512 samples
    WinLen = 1 / MaxFreqRes;  % s  ==> 512 samples zero-padded to 1024
    
    % Coherence process with bst_cohn.m (2019)
    tic;
    sTmp = bst_process('CallProcess', 'process_cohere1n', sFile, [], ...
        'timewindow',   [], ...          % All the time in input
        'cohmeasure',   'mscohere', ...  % 1=Magnitude-squared, 2=Imaginary
        'overlap',      50, ...          % 50%
        'maxfreqres',   MaxFreqRes, ...  % VARIES
        'maxfreq',      [], ...          % No maximum frequency
        'outputmode',   1);              % Save individual results (one file per input file)
    t = toc;
    % Execution time
    bst_report('Info', 'process_cohere1n', sFile, sprintf('Execution time: %1.6f seconds', t));
    % Add tag
    bst_process('CallProcess', 'process_add_tag', sTmp.FileName, [], 'tag', '(2019)' );
    % Snapshot: spectrum
    bst_process('CallProcess', 'process_snapshot', sTmp, [], ...
        'target',       11, ...  % Connectivity matrix (image)
        'modality',     1, 'orient', 1, 'time', 0, 'contact_time', [-40, 110], 'contact_nimage', 16, ...
        'Comment',      [sTmp.Comment, ': (2019)']);

    
    % Coherence process with bst_cohn_2021.m
    tic;
    sTmp = bst_process('CallProcess', 'process_cohere1n_2021', sFile, [], ...
        'timewindow',   [], ...          % All the time in input
        'includebad',   1, ...
        'removeevoked', 0, ...
        'cohmeasure',   'mscohere', ...  % Magnitude-squared Coherence|C|^2 = |Cxy|^2/(Cxx*Cyy)
        'win_length',   WinLen, ...
        'overlap',      50, ...          % 50%
        'maxfreq',      [], ...
        'outputmode',   'input');        % Save individual results (one output file per input file)
    t = toc;
    % Execution time
    bst_report('Info', 'process_cohere1n_2021', sFile, sprintf('Execution time: %1.6f seconds', t));   
    % Snapshot: spectrum
    bst_process('CallProcess', 'process_snapshot', sTmp, [], ...
        'target',         11, ...  % Connectivity matrix (image)
        'modality',       1, ...
        'orient',         1, ...
        'contact_nimage', 16, ...
        'Comment',      [sTmp.Comment, ': (2021)']);

    % Save and display report
    ReportFile = bst_report('Save', sTmp);
    bst_report('Open', ReportFile);
end



