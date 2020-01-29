function varargout = process_hcoh( varargin )
% PROCESS_HCOH: Compute the time-varying coherence measures using Hilbert transform 
% and Morlet Wavelet between all the pairs of signals, in one file.

% USAGE:  OutputFiles = process_hcoh('Run', sProcess, sInputA)

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
% Author: Hossein Shahabi, 2020
eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % === Description the process
    sProcess.Comment     = 'Coherence/Envelope by Hilbert/Morlet NxN (2020)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Connectivity';
    sProcess.Index       = 720;
    sProcess.Description = 'http://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    % === Definition of the input accepted by this process
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
    % === TIME-FREQUENCY TRANSFORMATION METHOD
    % === TITLE
    sProcess.options.label2.Comment = '<BR><U><B>Time-frequency transformation method</B></U>:';
    sProcess.options.label2.Type    = 'label';
    % === Hilbert/Morlet
    sProcess.options.tfmeasure.Comment = {'Hilbert transform', 'Morlet wavelet', ' '};
    sProcess.options.tfmeasure.Type    = 'radio_line';
    sProcess.options.tfmeasure.Value   = 1;
    % === Edit Panel 
    sProcess.options.edit.Comment = {'panel_timefreq_options', 'Options: '};
    sProcess.options.edit.Type    = 'editpref';
    sProcess.options.edit.Value   = [];
    % === Split a Large Signal into Blocks 
    sProcess.options.tfSplit.Comment = 'Blocking (large data):';
    sProcess.options.tfSplit.Type    = 'value';
    sProcess.options.tfSplit.Value   = {1, 'block(s)', []};
    % === Connectivity measure 
    sProcess.options.label4.Comment = '<BR><U><B>Connectivity measure</B></U>:';
    sProcess.options.label4.Type    = 'label';
    % === Connectivity measure 
    sProcess.options.cohmeasure.Comment = {'Coherence', 'Lagged coherence', ...
        'Envelope Correlation','Measure: '};
    sProcess.options.cohmeasure.Type    = 'radio_line';
    sProcess.options.cohmeasure.Value   = 1;
    % === Time-varying or Average
    sProcess.options.StatDyn.Comment = {'Dynamic', 'Static','Time resolution: '};
    sProcess.options.StatDyn.Type    = 'radio_line';
    sProcess.options.StatDyn.Value   = 1;
    % === Time window
    sProcess.options.win.Comment = 'Estimation window length:';
    sProcess.options.win.Type    = 'value';
    sProcess.options.win.Value   = {1500, 'ms', []};
    % === overlap
    sProcess.options.overlap.Comment = 'Sliding window overlap:';
    sProcess.options.overlap.Type    = 'value';
    sProcess.options.overlap.Value   = {50, '%', []};
    % === Parallel processing for envelope correlation
    sProcess.options.parMode.Comment = 'Parallel processing (envelope correlation)';
    sProcess.options.parMode.Type    = 'checkbox';
    sProcess.options.parMode.Value   = 0 ;
    % === Number of pools in parallel processing 
    sProcess.options.numParPool.Comment = 'Number of pools: ';
    sProcess.options.numParPool.Type    = 'value';
    sProcess.options.numParPool.Value   = {2, '', []};
    % === OUTPUT MODE
    sProcess.options.label6.Comment = '<BR><U><B>Output configuration</B></U>:';
    sProcess.options.label6.Type    = 'label';
    % === OUTPUT MODE
    sProcess.options.outputmode.Comment = {'Save individual results (one file per input file)',...
        'Average among output files (one file - only for trials)'};
    sProcess.options.outputmode.Type    = 'radio';
    sProcess.options.outputmode.Value   = 0;
    % === OUTPUT FILE TAG
    sProcess.options.commenttag.Comment = 'File tag: ';
    sProcess.options.commenttag.Type    = 'text';
    sProcess.options.commenttag.Value   = '';  
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
    OPTIONS.TargetA = OPTIONS.TargetB ; 
    OPTIONS.TargetB = [] ; 
    if isempty(OPTIONS)
        return
    end
    
    % === Metric options
    OPTIONS.Method        = 'hcoh';
    OPTIONS.RemoveEvoked  = sProcess.options.removeevoked.Value;
    OPTIONS.isSave        = 1 ;
    OPTIONS.isSymmetric   = 1 ; 
    
    % === Time-freq method 
    switch (sProcess.options.tfmeasure.Value)
        case 1 
            OPTIONS.tfMeasure = 'hilbert';
            OPTIONS.Freqrange = sProcess.options.edit.Value.Freqs ;  
            OPTIONS.WavPar    = [] ; 
        case 2  
            OPTIONS.tfMeasure = 'morlet';
            OPTIONS.Freqrange = sProcess.options.edit.Value.Freqs(:) ; 
            OPTIONS.WavPar(1) = sProcess.options.edit.Value.MorletFc ; 
            OPTIONS.WavPar(2) = sProcess.options.edit.Value.MorletFwhmTc ; 
    end
    
    % === Number of Blocks
    entNumBlocks = sProcess.options.tfSplit.Value{1} ; 
    if entNumBlocks <= 1
        OPTIONS.tfSplit = 1 ; 
    elseif entNumBlocks >20
        OPTIONS.tfSplit = 20 ;
    else
        OPTIONS.tfSplit = round(entNumBlocks) ; 
    end
    
    % === Connectivity measure 
    switch (sProcess.options.cohmeasure.Value)
        case 1,  OPTIONS.CohMeasure = 'coh';
        case 2,  OPTIONS.CohMeasure = 'lcoh';
        case 3,  OPTIONS.CohMeasure = 'env';
    end
    
    % === Time windows options
    CommentTag        = sProcess.options.commenttag.Value;
    EstTimeWinLen     = sProcess.options.win.Value{1};
    Overlap           = sProcess.options.overlap.Value{1}/100;
    OPTIONS.WinParam  = [EstTimeWinLen Overlap]; 
    % Dynamic Networks or Static (average among all Matrices)
    OPTIONS.HStatDyn  = sProcess.options.StatDyn.Value; 
    
    % === Number of Parallel Pools 
    OPTIONS.parMode = sProcess.options.parMode.Value ; 
    entNumPools = sProcess.options.numParPool.Value{1} ;  
    if entNumPools <=1 
        OPTIONS.numParPool = 1 ; 
    else
        OPTIONS.numParPool = round(entNumPools) ;
    end 
    
    % === Output
    switch (sProcess.options.outputmode.Value)
        case 1,  OPTIONS.OutputMode = 'input';
        case 2,  OPTIONS.OutputMode = 'avg';
    end
    
    % === Computing connectivity matrix
    OutputFiles = bst_connectivity({sInputA.FileName}, [], OPTIONS);

end




