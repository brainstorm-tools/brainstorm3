function varargout = process_decoding_maxcorr( varargin )
% PROCESS_DECODING_MAXCORR: Decoding of multiple conditions using max-correlation

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
% Authors: Martin Cousineau, 2019; Dimitrios Pantazis, 2019

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Max-correlation decoding';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Decoding';
    sProcess.Index       = 712;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Decoding';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;

    % Definition of the options
    sProcess.options.description.Comment = ['Apply max-correlation classifier on MEG trials.<BR>' ...
                                            'Uses trial subaverages and permutations. <BR><BR>'];
    sProcess.options.description.Type    = 'label';
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG';
    % === lowpass filtering
    sProcess.options.lowpass.Comment = 'Low-pass cutoff frequency (0=disabled): ';
    sProcess.options.lowpass.Type    = 'value';
    sProcess.options.lowpass.Value   = {30,'Hz',2};
    % === number of permutations
    sProcess.options.num_permutations.Comment = 'Number of permutations: ';
    sProcess.options.num_permutations.Type    = 'value';
    sProcess.options.num_permutations.Value   = {50,'',0};
    % === trial bin size for sub-averaging
    sProcess.options.kfold.Comment = 'Number of folds: ';
    sProcess.options.kfold.Type    = 'value';
    sProcess.options.kfold.Value   = {5,'',0};
    % === decoding method
    sProcess.options.method.Comment = {'Pairwise', 'Temporal generalization', 'Multiclass', 'Decoding method:'};
    sProcess.options.method.Type    = 'radio_line';
    sProcess.options.method.Value   = 1;
    % === decoding model
    sProcess.options.model.Comment = 'Decoding model: ';
    sProcess.options.model.Type    = 'text';
    sProcess.options.model.Value   = 'maxcorr';
    sProcess.options.model.Hidden  = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Call mother process with actual implementation
    OutputFiles = process_decoding_svm('Run', sProcess, sInputs);
end

