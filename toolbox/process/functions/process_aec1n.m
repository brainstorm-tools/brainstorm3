function varargout = process_aec1n( varargin )
% PROCESS_PLV1N: Compute amplitude envelope correlation between all the pairs of signals, in one file.

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
%          Peter Donhauser, 2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Amplitude Envelope Correlation NxN';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Connectivity';
    sProcess.Index       = 662;
    sProcess.Description = 'http://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',     'results',  'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;

    % === CONNECT INPUT
    sProcess = process_corr1n('DefineConnectOptions', sProcess, 1);
    % === FREQ BANDS
    sProcess.options.label2.Comment = '<BR><U><B>Estimator options</B></U>:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.freqbands.Comment = 'Frequency bands for the Hilbert transform:';
    sProcess.options.freqbands.Type    = 'groupbands';
    sProcess.options.freqbands.Value   = bst_get('DefaultFreqBands');
    % === KEEP TIME
    sProcess.options.isorth.Comment = 'Orthogonalize signal pairs before envelope computation';
    sProcess.options.isorth.Type    = 'checkbox';
    sProcess.options.isorth.Value   = 0;
    % === OUTPUT
    sProcess.options.label3.Comment = '<BR><U><B>Output configuration</B></U>:';
    sProcess.options.label3.Type    = 'label';
    % === OUTPUT MODE
    sProcess.options.outputmode.Comment = {'Save individual results (one file per input file)', 'Concatenate input files before processing (one file)', 'Save average connectivity matrix (one file)'};
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
    OPTIONS.Method = 'aec';
    % Filtering bands options
    OPTIONS.Freqs = sProcess.options.freqbands.Value;
    OPTIONS.isOrth = sProcess.options.isorth.Value;
    
    % Compute metric
    OutputFiles = bst_connectivity({sInputA.FileName}, [], OPTIONS);
end