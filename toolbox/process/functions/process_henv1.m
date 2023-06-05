function varargout = process_henv1(varargin)
% PROCESS_HENV1N: Compute the time-varying COherence and enVELope measures using Hilbert transform and Morlet Wavelet

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
% Author: Hossein Shahabi, Francois Tadel, 2022
eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % === Description the process
    sProcess.Comment     = 'Envelope Correlation 1xN [2022]';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Connectivity';
    sProcess.Index       = 685;
    sProcess.Description = 'http://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    % === Definition of the input accepted by this process
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
    sProcess.options.removeevoked.Group   = 'input';
    % === TIME-FREQUENCY TRANSFORMATION METHOD
    % === TITLE
    sProcess.options.label2.Comment = '<U><B>Time-frequency transformation method</B></U>:';
    sProcess.options.label2.Type    = 'label';
    % === Hilbert/Morlet
    sProcess.options.tfmeasure.Comment = {'Hilbert transform', 'Morlet wavelet', ''; 'hilbert', 'morlet', ''};
    sProcess.options.tfmeasure.Type    = 'radio_linelabel';
    sProcess.options.tfmeasure.Value   = 'hilbert';
    % === Edit Panel 
    sProcess.options.edit.Comment = {'panel_timefreq_options', 'Options: '};
    sProcess.options.edit.Type    = 'editpref';
    sProcess.options.edit.Value   = [];
    % === Split a Large Signal into Blocks 
    sProcess.options.tfsplit.Comment = 'Split large data in:';
    sProcess.options.tfsplit.Type    = 'value';
    sProcess.options.tfsplit.Value   = {1, 'block(s)', 0};
    % === Connectivity measure 
    sProcess.options.label4.Comment = '<BR><U><B>Connectivity measure</B></U>:';
    sProcess.options.label4.Type    = 'label';
    % === Connectivity measure 
    sProcess.options.cohmeasure.Comment = {'Magnitude coherence: |C|= |Cxy|/sqrt(Cxx*Cyy)', ...
                                           'Magnitude-squared coherence: |C|^2 = |Cxy|^2/(Cxx*Cyy)', ...
                                           'Lagged coherence: LC = |imag(C)|/sqrt(1-real(C)^2)', ...
                                           'Envelope correlation (no orthogonalization)','Envelope correlation (orthogonalized) '; ...
                                           'coh', 'msc', 'lcoh', 'penv', 'oenv'};
    sProcess.options.cohmeasure.Type    = 'radio_label';
    sProcess.options.cohmeasure.Value   = 'coh';
    % === Time-varying or Average
    sProcess.options.statdyn.Comment = {'Dynamic', 'Static', 'Time resolution: '; 'dynamic', 'static', ''};
    sProcess.options.statdyn.Type    = 'radio_linelabel';
    sProcess.options.statdyn.Value   = 'dynamic';
    % === Time window
    sProcess.options.win_length.Comment = 'Estimation window length:';
    sProcess.options.win_length.Type    = 'value';
    sProcess.options.win_length.Value   = {1.5, 'ms', 0};
    % === overlap
    sProcess.options.win_overlap.Comment = 'Sliding window overlap:';
    sProcess.options.win_overlap.Type    = 'value';
    sProcess.options.win_overlap.Value   = {50, '%', 0};
    % === Parallel processing
    sProcess.options.parallel.Comment = 'Use the parallel processing toolbox';
    sProcess.options.parallel.Type    = 'checkbox';
    sProcess.options.parallel.Value   = 0;  
    % === OUTPUT MODE
    sProcess.options.outputmode.Comment = {'Save individual results (one file per input file)', 'Average among output files (one file - only for trials)'};
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
    % Initialize returned values
    OutputFiles = {};
    
    % === Input options
    OPTIONS = process_corr1n('GetConnectOptions', sProcess, sInputA);
    if isempty(OPTIONS)
        return
    end

    % === Metric options
    OPTIONS.Method        = 'henv';
    OPTIONS.RemoveEvoked  = sProcess.options.removeevoked.Value;
    OPTIONS.isSave        = 1;
    OPTIONS.isSymmetric   = 1; 
    
    % === Time-freq method 
    % Get time-freq panel options
    tfOPTIONS = sProcess.options.edit.Value;
    if isempty(tfOPTIONS)
        [bstPanelNew, panelName] = panel_timefreq_options('CreatePanel', sProcess, sInputA);
        gui_show(bstPanelNew, 'JavaWindow', panelName, 0, 0, 0); 
        drawnow;
        tfOPTIONS = panel_timefreq_options('GetPanelContents');
        gui_hide(panelName);
    end
    % Fill bst_henv options structure
    OPTIONS.tfMeasure = sProcess.options.tfmeasure.Value;
    switch OPTIONS.tfMeasure
        case 'hilbert'
            OPTIONS.Freqrange    = tfOPTIONS.Freqs;
        case 'morlet'
            OPTIONS.Freqrange    = tfOPTIONS.Freqs(:);
            OPTIONS.MorletFc     = tfOPTIONS.MorletFc;
            OPTIONS.MorletFwhmTc = tfOPTIONS.MorletFwhmTc;
    end
    
    % === Number of Blocks
    entNumBlocks = sProcess.options.tfsplit.Value{1}; 
    if entNumBlocks <= 1
        OPTIONS.tfSplit = 1; 
    elseif entNumBlocks > 20
        OPTIONS.tfSplit = 20;
    else
        OPTIONS.tfSplit = round(entNumBlocks); 
    end
    
    % === Connectivity measure
    OPTIONS.CohMeasure = sProcess.options.cohmeasure.Value;
    OPTIONS.WinLength  = sProcess.options.win_length.Value{1};
    OPTIONS.WinOverlap = sProcess.options.win_overlap.Value{1} / 100;
    OPTIONS.HStatDyn   = sProcess.options.statdyn.Value; 
    
    % === Parallel Processing 
    OPTIONS.isParallel = sProcess.options.parallel.Value ; 

    % === Computing connectivity matrix
    OutputFiles = bst_connectivity({sInputA.FileName}, {sInputA.FileName}, OPTIONS);
end
