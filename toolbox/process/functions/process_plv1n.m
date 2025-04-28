function varargout = process_plv1n( varargin )
% PROCESS_PLV1N: Compute the coherence between all the pairs of signals, in one file.

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
% Authors: Francois Tadel, 2012-2020
%          Marc Lalancette, 2023

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Phase locking value NxN [2023]';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Connectivity';
    sProcess.Index       = 671;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',     'results',  'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;

    % === CONNECT INPUT
    sProcess = process_corr1n('DefineConnectOptions', sProcess, 1);
    % === PLV METHOD
    sProcess.options.label1.Comment = '<B>Connectivity Metric:</B>';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.plvmethod.Comment = {'Phase locking value', 'Lagged phase synchronization / Corrected imaginary PLV', 'Weighted phase lag index'; ...
                                          'plv', 'ciplv', 'wpli'};
    sProcess.options.plvmethod.Type    = 'radio_label';
    sProcess.options.plvmethod.Value   = 'plv';
    % === PLV MEASURE 
    % now always magnitude, complex was only used to average files for PLV, before averaging was improved.
    sProcess.options.plvmeasure.Comment = {'None (complex)', 'Magnitude', 'Measure:'};
    sProcess.options.plvmeasure.Type    = 'radio_line';
    sProcess.options.plvmeasure.Value   = 2;
    sProcess.options.plvmeasure.Hidden  = 1;
    % === Time-freq options
    sProcess.options.tfmeasure.Comment = {'Hilbert transform', 'Fourier transform', '<B>Time-frequency decomposition:</B>'; ...
                                          'hilbert', 'stft', ''};
    sProcess.options.tfmeasure.Type    = 'radio_linelabel';
    sProcess.options.tfmeasure.Value   = 'hilbert';
    % === TF OPTIONS Panel 
    sProcess.options.tfedit.Comment = {'panel_timefreq_options', 'Options: '};
    sProcess.options.tfedit.Type    = 'editpref';
    sProcess.options.tfedit.Value   = [];
    % === TIME AVERAGING
    sProcess.options.timeres.Comment = {'Full (requires epochs)', 'Windowed', 'None', '<B>Time resolution:</B>'; ...
                                     'full', 'windowed', 'none', ''};
    sProcess.options.timeres.Type    = 'radio_linelabel';
    sProcess.options.timeres.Value   = 'full';
    sProcess.options.timeres.Controller = struct('full', 'nowindowed', 'windowed', 'windowed', 'none', 'nowindowed');
    % === WINDOW LENGTH
    sProcess.options.avgwinlength.Comment = '&nbsp;&nbsp;&nbsp;Time window length:';
    sProcess.options.avgwinlength.Type    = 'value';
    sProcess.options.avgwinlength.Value   = {1, 's', []};
    sProcess.options.avgwinlength.Class   = 'windowed';
    % === WINDOW OVERLAP
    sProcess.options.avgwinoverlap.Comment = '&nbsp;&nbsp;&nbsp;Time window overlap:';
    sProcess.options.avgwinoverlap.Type    = 'value';
    sProcess.options.avgwinoverlap.Value   = {50, '%', []};
    sProcess.options.avgwinoverlap.Class   = 'windowed';
    % === OUTPUT MODE / FILE AVERAGING
    % Ideally, 'input' would be disabled for 'full' time resolution.
    sProcess.options.outputmode.Comment = {'separately for each file', 'across combined files/epochs', 'Estimate & save:'; ...
                                            'input', 'avg', ''};
    sProcess.options.outputmode.Type    = 'radio_linelabel';
    sProcess.options.outputmode.Value   = 'input';
    sProcess.options.outputmode.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    if ~isempty(sProcess.options.plvmethod.Value)
        iMethod = find(strcmpi(sProcess.options.plvmethod.Comment(2,:), sProcess.options.plvmethod.Value));
        if ~isempty(iMethod)
            method_str = str_striptag(sProcess.options.plvmethod.Comment{1,iMethod});
            connect_str = regexp(sProcess.Comment, '[1|N|A]x[N|B].*$', 'match');
            Comment = [method_str, ' ', connect_str{1}];
        else
            Comment = sProcess.Comment;
        end
    else
        Comment = sProcess.Comment;
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputA)
    % Input options
    OPTIONS = process_corr1n('GetConnectOptions', sProcess, sInputA);
    if isempty(OPTIONS)
        OutputFiles = {};
        return
    end

    OPTIONS.Method = sProcess.options.plvmethod.Value;

    % === Time-freq method 
    OPTIONS.tfMeasure = sProcess.options.tfmeasure.Value;
    if ismember(OPTIONS.tfMeasure, {'hilbert','stft'})
        % Get time-freq panel options
        tfOPTIONS = sProcess.options.tfedit.Value;
        if isempty(tfOPTIONS)
            [bstPanelNew, panelName] = panel_timefreq_options('CreatePanel', sProcess, sInputA);
            gui_show(bstPanelNew, 'JavaWindow', panelName, 0, 0, 0);
            drawnow;
            tfOPTIONS = panel_timefreq_options('GetPanelContents');
            gui_hide(panelName);
        end
    end
    switch OPTIONS.tfMeasure
        case 'hilbert'
            OPTIONS.Freqs = tfOPTIONS.Freqs;
            if strcmpi(sProcess.options.timeres.Value, 'windowed')
                OPTIONS.WinLen = sProcess.options.avgwinlength.Value{1};
                OPTIONS.WinOverlap = sProcess.options.avgwinoverlap.Value{1}/100;
            end
            OPTIONS.isMirror = 0;
        case 'stft'
            OPTIONS.Freqs = [];
            OPTIONS.StftWinLen = tfOPTIONS.StftWinLen;
            OPTIONS.StftWinOvr = tfOPTIONS.StftWinOvr/100;
            OPTIONS.MaxFreq    = tfOPTIONS.StftFrqMax;
            if strcmpi(sProcess.options.timeres.Value, 'windowed')
                OPTIONS.WinLen = sProcess.options.avgwinlength.Value{1};
                OPTIONS.WinOverlap = sProcess.options.avgwinoverlap.Value{1}/100;
            end
    end
    % Keep time or not; now option, no longer separate process
    OPTIONS.TimeRes = sProcess.options.timeres.Value;

    % PLV measure (compatibility)
    if isfield(sProcess.options, 'plvmeasure') && isfield(sProcess.options.plvmeasure, 'Value') && ~isempty(sProcess.options.plvmeasure.Value) 
        switch (sProcess.options.plvmeasure.Value)
            case 1,  OPTIONS.PlvMeasure = 'none';
            case 2,  OPTIONS.PlvMeasure = 'magnitude';
        end
    else
        OPTIONS.PlvMeasure = 'magnitude';
    end
    % Compute metric
    OutputFiles = bst_connectivity(sInputA, [], OPTIONS);
end




%% ===== TEST FUNCTION =====
function Test()
    % Start a new report
    bst_report('Start');
    % Get test datasets
    sFile = process_simulate_ar('Test');
    % Coherence process
    sTmp = bst_process('CallProcess', 'process_plv1n', sFile, [], ...
        'timewindow',   [], ...    % All the time in input
        'freqbands',    {'delta', '2, 4', 'mean'; 'theta', '5, 7', 'mean'; 'alpha', '8, 12', 'mean'; 'beta', '15, 29', 'mean'; 'gamma1', '30, 59', 'mean'; 'gamma2', '60, 90', 'mean'}, ...
        'mirror',       1, ...
        'keeptime',     0, ...
        'outputmode',   1);        % Save individual results (one file per input file)
    % Snapshot: spectrum
    bst_process('CallProcess', 'process_snapshot', sTmp, [], ...
        'target',       11, ...  % Connectivity matrix (image)
        'modality',     1, 'orient', 1, 'time', 0, 'contact_time', [-40, 110], 'contact_nimage', 16, ...
        'Comment',      [sFile.Comment, ': ' sTmp.Comment]);
    % Save and display report
    ReportFile = bst_report('Save', sFile);
    bst_report('Open', ReportFile);
end




