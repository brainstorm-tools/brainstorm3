function varargout = process_cohere1n_time_2021( varargin )
% PROCESS_COHERE1N_TIME_2021: Compute the time-resolved coherence between all the pairs of signals, in one file.

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
% Authors: Elizabeth Bock, 2015
%          Francois Tadel, 2015-2021
%          Hossein Shahabi, 2019-2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Time-resolved coherence NxN [2021]';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Connectivity';
    sProcess.Index       = 657;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',     'results',  'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;

    % === CONNECT INPUT
    sProcess = process_corr1n('DefineConnectOptions', sProcess, 1);
    % === REMOVE EVOKED REPONSE
    sProcess.options.removeevoked.Comment = 'Remove evoked response from each trial';
    sProcess.options.removeevoked.Type    = 'checkbox';
    sProcess.options.removeevoked.Value   = 0;
    sProcess.options.removeevoked.Group   = 'input';
    % === Time window
    sProcess.options.slide_win.Comment = 'Sliding time window duration:';
    sProcess.options.slide_win.Type    = 'value';
    sProcess.options.slide_win.Value   = {.350, 'ms', []};
    % === Overlap for Sliding window (Time)
    sProcess.options.slide_overlap.Comment = 'Sliding window overlap:';
    sProcess.options.slide_overlap.Type    = 'value';
    sProcess.options.slide_overlap.Value   = {50, '%', []};
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
        'mscohere', 'icohere2019','lcohere2019', 'icohere'};
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
    % === OUTPUT FILE TAG
    sProcess.options.commenttag.Comment = 'File tag: ';
    sProcess.options.commenttag.Type    = 'text';
    sProcess.options.commenttag.Value   = '';
    sProcess.options.commenttag.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputA) %#ok<DEFNU>
    % Initialize returned values
    OutputFiles = {};
    % Output mode 2021: Forcing the average cross-spectra of input files (one output file)
    sProcess.options.outputmode.Value = 'avgcoh';
    % Input options
    OPTIONS = process_corr1n('GetConnectOptions', sProcess, sInputA);
    if isempty(OPTIONS)
        return
    end

    CommentTag = sProcess.options.commenttag.Value;
    % Metric options
    OPTIONS.Method = 'cohere';
    OPTIONS.RemoveEvoked  = sProcess.options.removeevoked.Value;
    OPTIONS.WinLen        = sProcess.options.win_length.Value{1};
    OPTIONS.MaxFreq       = sProcess.options.maxfreq.Value{1};
    OPTIONS.WinOverlap    = 0.50;
    OPTIONS.isSave        = 0;
    OPTIONS.CohMeasure    = sProcess.options.cohmeasure.Value; 
    OPTIONS.tfMeasure     = 'fourier';
    % Sliding time windows options
    WinLength  = sProcess.options.slide_win.Value{1};
    WinOverlap = sProcess.options.slide_overlap.Value{1};

    % Read time information
    TimeVector = in_bst(sInputA(1).FileName, 'Time');
    sfreq      = round(1/(TimeVector(2) - TimeVector(1)));
    % Get time window of first fileA if none specified in parameters
    if isempty(OPTIONS.TimeWindow)
        OPTIONS.TimeWindow = TimeVector([1, end]);
    end
    % Select input time window
    TimeVector = TimeVector((TimeVector >= OPTIONS.TimeWindow(1)) & (TimeVector <= OPTIONS.TimeWindow(2)));
    nTime      = length(TimeVector);

    % Compute sliding windows length
    Lwin  = round(WinLength * sfreq);
    Loverlap = round(Lwin * WinOverlap / 100);
    Nwin = floor((nTime - Loverlap) ./ (Lwin - Loverlap));
    % If window is bigger than the data
    if (Lwin > nTime)
        bst_report('Error', sProcess, sInputA, 'Sliding window for the coherence estimation is too long compared with the epochs in input.');
        return;
    end

    % Get progress bar position
    posProgress = bst_progress('get');
    % Loop over all the time windows
    for iWin = 1:Nwin
        % Set the progress bar at the same level at every iteration
        bst_progress('set', posProgress);
        % Select time window
        iTimes = (1:Lwin) + (iWin-1)*(Lwin - Loverlap);
        OPTIONS.TimeWindow = TimeVector(iTimes([1,end]));
        % Compute metric
        ConnectMat = bst_connectivity(sInputA, [], OPTIONS);
        % Processing errors
        if isempty(ConnectMat) || ~iscell(ConnectMat) || ~isstruct(ConnectMat{1}) || isempty(ConnectMat{1}.TF)
            bst_report('Error', sProcess, sInputA, 'Coherence for the selected time segment could not be calculated.');
            return;
        end
        % Start a new brainstorm structure
        if (iWin == 1)
            NewMat = ConnectMat{1};
            NewMat.Time = OPTIONS.TimeWindow(1);
            NewMat.TimeBands = [];
        % Add next time point
        else
            NewMat.TF(:,iWin,:) = ConnectMat{1}.TF;
            NewMat.Time(end+1) = OPTIONS.TimeWindow(1);
        end
    end
    
    % Fix time vector
    if (length(NewMat.Time) == 1)
        bst_report('Warning', sProcess, sInputA, 'Only one sliding time window could be estimated.');
        NewMat.Time = [TimeVector(1), TimeVector(end)];
    end
    % Add comment tag
    if ~isempty(CommentTag)
        NewMat.Comment = [NewMat.Comment ' | ' CommentTag];
    end
    % Output filename
    sOutputStudy = bst_get('Study', OPTIONS.iOutputStudy);
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sOutputStudy.FileName), 'timefreq_connectn_cohere_time');
    % Save file
    bst_save(OutputFiles{1}, NewMat, 'v6');
    % Add file to database structure
    db_add_data(OPTIONS.iOutputStudy, OutputFiles{1}, NewMat);
end




