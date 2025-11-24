function varargout = process_spgranger1n( varargin )
% PROCESS_SPGRANGER1N: Compute the spectral Granger causality between all the pairs of signals, in one file.
%
% USAGE:   OutputFiles = process_spgranger1n('Run', sProcess, sInputA)
%                        process_spgranger1n('Test')

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
% Authors: Francois Tadel, 2014-2020
%          Raymundo Cassani, 2025


eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Bivariate Granger causality (spectral) NxN';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Connectivity';
    sProcess.Index       = 666;
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
    % === GRANGER METHOD
    sProcess.options.label.Comment = '<B>Granger causility method:</B>';
    sProcess.options.label.Type    = 'label';
    sProcess.options.grangermethod.Comment = {['Conditional Granger causality<BR>', ...
                                             '<FONT color="#777777">(MVGC Toolbox implementation)</FONT>'], ...
                                             ['<FONT color="#777777">Unconditional Granger causality (Not recommended)</FONT><BR>', ...
                                             '<FONT color="#777777">Default before Sep 2025</FONT>']; ...
                                             'mvgc', 'bst'};
    sProcess.options.grangermethod.Type    = 'radio_label';
    sProcess.options.grangermethod.Value   = 'bst';
    sProcess.options.grangermethod.Controller.bst = 'bst';
    % === GRANGER ORDER
    sProcess.options.grangerorder.Comment = 'Maximum Granger model order (default=10):';
    sProcess.options.grangerorder.Type    = 'value';
    sProcess.options.grangerorder.Value   = {10, '', 0};
    % === MAX FREQUENCY RESOLUTION
    sProcess.options.maxfreqres.Comment = 'Maximum frequency resolution:';
    sProcess.options.maxfreqres.Type    = 'value';
    sProcess.options.maxfreqres.Value   = {2,'Hz',2};
    sProcess.options.maxfreqres.Class   = 'bst';
    % === HIGHEST FREQUENCY OF INTEREST
    sProcess.options.maxfreq.Comment = 'Highest frequency of interest:';
    sProcess.options.maxfreq.Type    = 'value';
    sProcess.options.maxfreq.Value   = {100,'Hz',2};
    % === OUTPUT MODE
    sProcess.options.outputmode.Comment = {'Save individual results (one file per input file)', 'Concatenate input files before processing (one file)', 'Save average connectivity matrix (one file)'};
    sProcess.options.outputmode.Type    = 'radio';
    sProcess.options.outputmode.Value   = 1;
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
    OPTIONS.GrangerMethod = 'bst';
    OPTIONS.Method = 'spgranger';
    if isfield(sProcess.options, 'grangermethod') && ~isempty(sProcess.options.grangermethod.Value)
        OPTIONS.GrangerMethod = sProcess.options.grangermethod.Value;
    end
    OPTIONS.RemoveEvoked = sProcess.options.removeevoked.Value;
    OPTIONS.GrangerOrder = sProcess.options.grangerorder.Value{1};
    OPTIONS.MaxFreqRes   = sProcess.options.maxfreqres.Value{1};
    OPTIONS.MaxFreq      = sProcess.options.maxfreq.Value{1};
%     OPTIONS.pThresh      = sProcess.options.pthresh.Value{1};
    
    % Compute metric
    OutputFiles = bst_connectivity(sInputA, [], OPTIONS);
end




%% ===== TEST FUNCTION =====
function Test() %#ok<DEFNU>
    % Start a new report
    bst_report('Start');
    % Get test datasets
    sFile = process_simulate_ar('Test');
    % Loop on frequency resolutions
    for freq = [1 2 3 5 10 20]
        % Granger spectral process
        sTmp = bst_process('CallProcess', 'process_spgranger1n', sFile, [], ...
            'timewindow',    [], ...    % All the time in input
            'removeevoked',  0, ...
            'grangermethod', 'mvgc', ...
            'grangerorder',  10, ...
            'maxfreqres',    freq, ...
            'maxfreq',       [], ...
            'outputmode',    1);  % Save individual results (one file per input file)
        % Snapshot
        bst_process('CallProcess', 'process_snapshot', sTmp, [], ...
            'target',       11, ...  % Connectivity matrix (image)
            'modality',     1, 'orient', 1, 'time', 0, 'contact_time', [-40, 110], 'contact_nimage', 16, ...
            'Comment',      [sFile.Comment, ': ' sTmp.Comment]);
    end
    % Save and display report
    ReportFile = bst_report('Save', sTmp);
    bst_report('Open', ReportFile);
end




