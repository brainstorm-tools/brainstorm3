function varargout = process_plv2( varargin )
% PROCESS_PLV2: Compute the coherence between one signal in one file, and all the signals in another file.

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2012-2014

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Phase locking value AxB';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Connectivity';
    sProcess.Index       = 656;
    sProcess.Description = 'http://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isPaired    = 1;
    sProcess.isSeparator = 1;
    
    % === CONNECT INPUT
    sProcess = process_corr2('DefineConnectOptions', sProcess);
    % === FREQ BANDS
    sProcess.options.label2.Comment = '<BR><U><B>Estimator options</B></U>:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.freqbands.Comment = 'Frequency bands for the Hilbert transform:';
    sProcess.options.freqbands.Type    = 'groupbands';
    sProcess.options.freqbands.Value   = bst_get('DefaultFreqBands');
    % === Mirror
    sProcess.options.mirror.Comment = 'Mirror signal before filtering (not recommended)';
    sProcess.options.mirror.Type    = 'checkbox';
    sProcess.options.mirror.Value   = 0;
    % === KEEP TIME
    sProcess.options.keeptime.Comment = 'Keep time information, and estimate the PLV across trials<BR>(requires the average of many trials)';
    sProcess.options.keeptime.Type    = 'checkbox';
    sProcess.options.keeptime.Value   = 0;
    % === PLV METHOD
    sProcess.options.plvmeasure.Comment = {'None (complex)', 'Magnitude', 'Measure:'};
    sProcess.options.plvmeasure.Type    = 'radio_line';
    sProcess.options.plvmeasure.Value   = 2;
    % === OUTPUT MODE
    sProcess.options.label3.Comment = '<BR><U><B>Output configuration</B></U>:';
    sProcess.options.label3.Type    = 'label';
    sProcess.options.outputmode.Comment = {'Save individual results (one file per input file)', 'Concatenate input files before processing (one file)', 'Save average connectivity matrix (one file)'};
    sProcess.options.outputmode.Type    = 'radio';
    sProcess.options.outputmode.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputA, sInputB) %#ok<DEFNU>
    % Input options
    OPTIONS = process_corr2('GetConnectOptions', sProcess, sInputA, sInputB);
    if isempty(OPTIONS)
        OutputFiles = {};
        return
    end
    
    % Keep time or not: different methods
    if sProcess.options.keeptime.Value
        OPTIONS.Method = 'plvt';
    else
        OPTIONS.Method = 'plv';
    end
    % Hilbert and frequency bands options
    OPTIONS.Freqs = sProcess.options.freqbands.Value;
    OPTIONS.isMirror = sProcess.options.mirror.Value;
    % PLV measure
    if isfield(sProcess.options, 'plvmeasure') && isfield(sProcess.options.plvmeasure, 'Value') && ~isempty(sProcess.options.plvmeasure.Value) 
        switch (sProcess.options.plvmeasure.Value)
            case 1,  OPTIONS.PlvMeasure = 'none';
            case 2,  OPTIONS.PlvMeasure = 'magnitude';
        end
    else
        OPTIONS.PlvMeasure = 'magnitude';
    end
    
    % Compute metric
    OutputFiles = bst_connectivity({sInputA.FileName}, {sInputB.FileName}, OPTIONS);
end




