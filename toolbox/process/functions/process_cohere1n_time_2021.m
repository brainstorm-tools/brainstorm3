function varargout = process_cohere1n_time_2021( varargin )
% PROCESS_COHERE1N_TIME_2021: Compute the time-resolved coherence between all the pairs of signals, in one file.

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
    % Forcing the concatenation of the inputs
    sProcess.options.outputmode.Comment = {'Save individual results (one file per input file)', 'Concatenate input files before processing (one file)', 'Save average connectivity matrix (one file)'};
    sProcess.options.outputmode.Type    = 'radio';
    sProcess.options.outputmode.Value   = 2;
    % Input options
    OPTIONS = process_corr1n('GetConnectOptions', sProcess, sInputA);
    if isempty(OPTIONS)
        return
    end
    % Metric options
    OPTIONS.Method = 'cohere';
    OPTIONS.RemoveEvoked  = sProcess.options.removeevoked.Value;
    OPTIONS.WinLen        = sProcess.options.win_length.Value{1};
    OPTIONS.MaxFreq       = sProcess.options.maxfreq.Value{1};
    OPTIONS.CohOverlap    = 0.50;
    OPTIONS.pThresh       = 0.05;
    OPTIONS.isSave        = 0;
    OPTIONS.CohMeasure    = sProcess.options.cohmeasure.Value; 

    % Sliding time windows options
    CommentTag    = sProcess.options.commenttag.Value;
    EstTimeWinLen = sProcess.options.slide_win.Value{1};
    Overlap       = sProcess.options.slide_overlap.Value{1}/100;
    
    % Read time information
    TimeVector   = in_bst(sInputA(1).FileName, 'Time');
    sfreq        = round(1/(TimeVector(2) - TimeVector(1)));
    winLen       = round(sfreq * EstTimeWinLen);
    overlapSamps = round(Overlap * winLen);
    SampTimeWin  = bst_closest(OPTIONS.TimeWindow, TimeVector); % number of baseline sample to ignore
    timeSamps    = [SampTimeWin(1),winLen+SampTimeWin(1)];  
    iTime = 1;
    % Error management
    if (timeSamps(2) >= SampTimeWin(2))
        bst_report('Error', sProcess, sInputA, 'Sliding window for the coherence estimation is too long compared with the epochs in input.');
        return;
    end
    % Get progress bar position
    posProgress = bst_progress('get');
    
    % Loop over all the time windows
    while (timeSamps(2) < SampTimeWin(2))
        % Set the progress bar at the same level at every iteration
        bst_progress('set', posProgress);
        % select time window
        OPTIONS.TimeWindow = TimeVector(timeSamps);
        % Compute metric
        ConnectMat = bst_connectivity({sInputA.FileName}, [], OPTIONS);
        % Processing errors
        if isempty(ConnectMat) || ~iscell(ConnectMat) || ~isstruct(ConnectMat{1}) || isempty(ConnectMat{1}.TF)
            bst_report('Error', sProcess, sInputA, 'Coherence for the selected time segment could not be calculated.');
            return;
        end
        % Start a new brainstorm structure
        if (iTime == 1)
            NewMat = ConnectMat{1};
            NewMat.Time = TimeVector(timeSamps(1));             
            NewMat.TimeBands = [];
        % Add next time point
        else
            NewMat.TF(:,iTime,:) = ConnectMat{1}.TF;
            NewMat.Time(end+1) = TimeVector(timeSamps(1));
        end
        % Update to the next time
        iTime = iTime+1;
        newStart = timeSamps(2) - overlapSamps;
        timeSamps = [newStart, newStart+winLen];
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




