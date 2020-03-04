function varargout = process_cohere1( varargin )
% PROCESS_COHERE1: Compute the coherence between one signal and all the others, in one file.
%
% USAGE:  OutputFiles = process_cohere1('Run', sProcess, sInputA)
%                       process_cohere1('Test', 1)
%                       process_cohere1('Test', 2)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2012-2014; Hossein Shahabi, 2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Coherence 1xN';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Connectivity';
    sProcess.Index       = 653;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',     'results',  'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % === CONNECT INPUT
    sProcess = process_corr1n('DefineConnectOptions', sProcess, 0);
    % === REMOVE EVOKED REPONSE
    sProcess.options.removeevoked.Comment = 'Remove evoked response from each trial';
    sProcess.options.removeevoked.Type    = 'checkbox';
    sProcess.options.removeevoked.Value   = 0;
    % === TITLE
    sProcess.options.label2.Comment = '<BR><U><B>Estimator options</B></U>:';
    sProcess.options.label2.Type    = 'label';
    % === COHERENCE METHOD
    sProcess.options.cohmeasure.Comment = {...
        ['<B>Magnitude-squared Coherence</B><BR>' ...
        '|C|^2 = |Gxy|^2/(Gxx*Gyy)'], ...
        ['<B>Imaginary Coherence (2019)</B><BR>' ...
        'IC    = |imag(C)|'], ...
        ['<B>Lagged Coherence (2019)</B><BR>' ...
        'LC    = |imag(C)|/sqrt(1-real(C)^2)'], ...
        ['<FONT color="#777777"> Imaginary Coherence (before 2019)</FONT><BR>' ...
        '<FONT color="#777777"> IC    = imag(C)^2 / (1-real(C)^2) </FONT>']; ...
        'mscohere', 'icohere2019','lcohere2019', 'icohere'};
    sProcess.options.cohmeasure.Type    = 'radio_label';
    sProcess.options.cohmeasure.Value   = 'mscohere';
    % === Overlap
    sProcess.options.overlap.Comment = 'Overlap for PSD estimation:' ;
    sProcess.options.overlap.Type    = 'value';
    sProcess.options.overlap.Value   = {50, '%', []};
    % === MAX FREQUENCY RESOLUTION
    sProcess.options.maxfreqres.Comment = 'Maximum frequency resolution:';
    sProcess.options.maxfreqres.Type    = 'value';
    sProcess.options.maxfreqres.Value   = {2,'Hz',2};
    % === HIGHEST FREQUENCY OF INTEREST
    sProcess.options.maxfreq.Comment = 'Highest frequency of interest:';
    sProcess.options.maxfreq.Type    = 'value';
    sProcess.options.maxfreq.Value   = {60,'Hz',2};
%     % === P-VALUE THRESHOLD
%     sProcess.options.pthresh.Comment = 'Metric significativity: &nbsp;&nbsp;&nbsp;&nbsp;p&lt;';
%     sProcess.options.pthresh.Type    = 'value';
%     sProcess.options.pthresh.Value   = {0.05,'',4};
%     % === IS FREQ BANDS
%     sProcess.options.isfreqbands.Comment = 'Group by frequency bands (name/freqs/function):';
%     sProcess.options.isfreqbands.Type    = 'checkbox';
%     sProcess.options.isfreqbands.Value   = 0;
%     % === FREQ BANDS
%     sProcess.options.freqbands.Comment = '';
%     sProcess.options.freqbands.Type    = 'groupbands';
%     sProcess.options.freqbands.Value   = bst_get('DefaultFreqBands');
    % === OUTPUT MODE
    sProcess.options.label3.Comment = '<BR><U><B>Output configuration</B></U>:';
    sProcess.options.label3.Type    = 'label';
    sProcess.options.outputmode.Comment = {'Save individual results (one file per input file)', 'Concatenate input files before processing (one file)'};
    sProcess.options.outputmode.Type    = 'radio';
    sProcess.options.outputmode.Value   = 1;
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
    OPTIONS.MaxFreqRes    = sProcess.options.maxfreqres.Value{1};
    OPTIONS.MaxFreq       = sProcess.options.maxfreq.Value{1};
    OPTIONS.CohOverlap    = 0.50;  % First pre-define the overlap
    OPTIONS.pThresh       = 0.05;  % sProcess.options.pthresh.Value{1};
    OPTIONS.CohMeasure    = sProcess.options.cohmeasure.Value; 

    % Change the overlap if it is specified
    if isfield(sProcess.options, 'overlap') && isfield(sProcess.options.overlap, 'Value') && ...
       iscell(sProcess.options.overlap.Value) && ~isempty(sProcess.options.overlap.Value) && ~isempty(sProcess.options.overlap.Value{1})
        OPTIONS.CohOverlap = sProcess.options.overlap.Value{1}/100 ; 
    end
%     switch (sProcess.options.overlap.Value)
%         case 1,  OPTIONS.CohOverlap = 0;
%         case 2,  OPTIONS.CohOverlap = 0.25;
%         case 3,  OPTIONS.CohOverlap = 0.50;
%         case 4,  OPTIONS.CohOverlap = 0.75;
%     end
%     % Frequency bands
%     isFreqBands = sProcess.options.isfreqbands.Value;
%     if isFreqBands
%         OPTIONS.Freqs = sProcess.options.freqbands.Value;
%     else
%         OPTIONS.Freqs = [];
%     end

    % Compute metric
    OutputFiles = bst_connectivity({sInputA.FileName}, {sInputA.FileName}, OPTIONS);
end



%% ===== TEST FUNCTION =====
function Test(iTest) %#ok<DEFNU>
    % Start a new report
    bst_report('Start');
    % Select tests
    if (nargin < 1) || isempty(iTest)
        iTest = 1;
    end
    % Get test datasets
    switch iTest
        case 1,  sFile = process_simulate_matrix('Test');
        case 2,  sFile = process_simulate_ar('Test');
    end
    % Loop on frequency resolutions
    for freq = [1 2 3 5 10 20]
        % Coherence process
        sTmp = bst_process('CallProcess', 'process_cohere1', sFile, [], ...
            'timewindow',   [], ...    % All the time in input
            'src_rowname',  '1', ...   % Test signal #1 => other signals
            'cohmeasure',   1, ...     % 1=Magnitude-squared, 2=Imaginary
            'overlap',      3, ...     % 50%
            'maxfreqres',   freq, ...  % VARIES
            'maxfreq',      [], ...    % No maximum frequency
            'pThresh',      0.05, ...  % p-value thrshold
            ... 'isfreqbands',  0, ...     % No frequency bands
            ... 'freqbands',    [], ...
            'outputmode',   1);        % Save individual results (one file per input file)
        % Snapshot: spectrum
        bst_process('CallProcess', 'process_snapshot', sTmp, [], ...
            'target',       10, ...  % Frequency spectrum
            'modality',     1, 'orient', 1, 'time', 0, 'contact_time', [-40, 110], 'contact_nimage', 16, ...
            'Comment',      [sFile.Comment, ': ' sTmp.Comment]);
    end
    % Save and display report
    ReportFile = bst_report('Save', sFile);
    bst_report('Open', ReportFile);
end


