function varargout = process_GEDAI_Brainstorm( varargin )
% PROCESS_GEDAI: Wrapper for GEDAI.m function (copy into the Brainstorm toolbox directory: brainstorm3\toolbox\process\functions )
%
% USAGE:                sProcess = process_GEDAI('GetDescription')
%                         sInput = process_GEDAI('Run', sProcess, sInput)

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
% Authors: Tomas Ros, Center for Biomedical Imaging (CIBM), University of Geneva, 2025

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'GEDAI';
    sProcess.FileTag     = 'gedai';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Artifacts';
    sProcess.Index       = 65;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.Description = 'https://github.com/neurotuning/GEDAI-master';
    % Definition of the options
    % === Artifact threshold type
        % Options: Comment
    sProcess.options.Comment1.Comment = '<BR><B>ARTIFACTING STRENGTH:<B>';
    sProcess.options.Comment1.Type    = 'label';
    sProcess.options.artifact_threshold_type.Comment = {'auto-', 'auto', 'auto+'};
    sProcess.options.artifact_threshold_type.Type    = 'radio';
    sProcess.options.artifact_threshold_type.Value   = 2;
    % === Epoch size in cycles
    sProcess.options.Comment2.Comment = '<BR><B>EPOCH SIZE:<B>';
    sProcess.options.Comment2.Type    = 'label';
    sProcess.options.epoch_size_in_cycles.Comment = 'Epoch size in wave cycles (e.g., 12)';
    sProcess.options.epoch_size_in_cycles.Type    = 'value';
    sProcess.options.epoch_size_in_cycles.Value   = {12, 'cycles', 0};
    % === Low-cut frequency
    sProcess.options.Comment2_5.Comment = '<BR><B>LOW-CUT FREQUENCY:<B>';
    sProcess.options.Comment2_5.Type    = 'label';
    sProcess.options.lowcut_frequency.Comment = 'Low-cut frequency (Hz)';
    sProcess.options.lowcut_frequency.Type    = 'value';
    sProcess.options.lowcut_frequency.Value   = {0.5, 'Hz', 0};
    % === Reference matrix type
    sProcess.options.Comment3.Comment = '<BR><B>LEADFIELD MATRIX:<B>';
    sProcess.options.Comment3.Type    = 'label';
    sProcess.options.ref_matrix_type.Comment = {'Freesurfer (precomputed)', 'Freesurfer (interpolated)', 'Brainstorm leadfield'};
    sProcess.options.ref_matrix_type.Type    = 'radio';
    sProcess.options.ref_matrix_type.Value   = 1;
    % === Parallel processing
    sProcess.options.Comment4.Comment = '<BR><B> <B>';
    sProcess.options.Comment4.Type    = 'label';
    sProcess.options.parallel.Comment = 'Use parallel processing';
    sProcess.options.parallel.Type    = 'checkbox';
    sProcess.options.parallel.Value   = 1;
    % === Visualize artifacts
    sProcess.options.visualize_artifacts.Comment = 'Visualize artifacts';
    sProcess.options.visualize_artifacts.Type    = 'checkbox';
    sProcess.options.visualize_artifacts.Value   = 0;
end


%% ===== GET OPTIONS =====
function [artifact_threshold_type, epoch_size_in_cycles, lowcut_frequency, ref_matrix_type, parallel, visualize_artifacts] = GetOptions(sProcess)
    % Artifact threshold type
    switch sProcess.options.artifact_threshold_type.Value
        case 1
            artifact_threshold_type = 'auto-';
        case 2
            artifact_threshold_type = 'auto';
        case 3
            artifact_threshold_type = 'auto+';
    end
    % Epoch size in cycles
    epoch_size_in_cycles = sProcess.options.epoch_size_in_cycles.Value{1};
    % Low-cut frequency
    lowcut_frequency = sProcess.options.lowcut_frequency.Value{1};
    % Reference matrix type
    switch sProcess.options.ref_matrix_type.Value
        case 1
            ref_matrix_type = 'Freesurfer (precomputed)';
        case 2
            ref_matrix_type = 'Freesurfer (interpolated)';
        case 3
            ref_matrix_type = 'Brainstorm leadfield';
    end
    % Parallel processing
    parallel = sProcess.options.parallel.Value;
    % Visualize artifacts
    visualize_artifacts = sProcess.options.visualize_artifacts.Value;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    [artifact_threshold_type, epoch_size_in_cycles, lowcut_frequency, ref_matrix_type, ~, ~] = GetOptions(sProcess);
    Comment = ['GEDAI: ' artifact_threshold_type ', ' num2str(epoch_size_in_cycles) ' cycles, ' num2str(lowcut_frequency) ' Hz, ' ref_matrix_type];
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get options
    [artifact_threshold_type, epoch_size_in_cycles, lowcut_frequency, ref_matrix_type, parallel, visualize_artifacts] = GetOptions(sProcess);
    
    % Get channel file for study
    [sChannel, iStudyChannel] = bst_get('ChannelForStudy', sInput.iStudy);
    % Load channel file
    ChannelMat = in_bst_channel(sChannel.FileName);

    % Convert Brainstorm sInput to EEGLAB format
    EEG = brainstorm2eeglab(sInput, ChannelMat);

    % Handle ref_matrix_type
    if strcmp(ref_matrix_type, 'Brainstorm leadfield')
        sStudy = bst_get('Study', iStudyChannel);
        HeadModelFile = sStudy.HeadModel(sStudy.iHeadModel).FileName;
        HeadModel = in_bst_headmodel(HeadModelFile, 0, 'Gain');
        
        % Apply average reference to leadfield
        Gain_avref = HeadModel.Gain - mean(HeadModel.Gain, 1);

        % Compute channel covariance matrix
        ref_matrix_param = Gain_avref * Gain_avref';

    elseif strcmp(ref_matrix_type, 'Freesurfer (precomputed)')
        ref_matrix_param = 'precomputed';

    elseif strcmp(ref_matrix_type, 'Freesurfer (interpolated)')
        ref_matrix_param = 'interpolated';
    end


    % Run GEDAI
    [EEGclean, ~, ~, ~, ~, ~] = GEDAI(EEG, artifact_threshold_type, epoch_size_in_cycles, lowcut_frequency, ref_matrix_param, parallel, visualize_artifacts);
    
    % Convert back to Brainstorm format
    sInput = eeglab2brainstorm(EEGclean, sInput);
    sInput.CommentTag = FormatComment(sProcess);
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
end

%% ===== HELPER FUNCTIONS =====
function EEG = brainstorm2eeglab(sInput, ChannelMat)
    % Check if EEGLAB is in the path
    if ~exist('eeg_checkset', 'file')
        error('EEGLAB function eeg_checkset.m not found in the path. Please add EEGLAB to your Matlab path.');
    end

    % Create an empty EEGLAB structure
    EEG = eeg_emptyset;

    % Populate EEG fields from sInput
    EEG.setname = sInput.Comment;
    if isfield(sInput, 'FileName')
        EEG.filename = sInput.FileName;
        EEG.filepath = fileparts(sInput.FileName);
    end
    EEG.subject = '';
    EEG.group = '';
    EEG.condition = '';
    EEG.session = [];
    EEG.nbchan = size(sInput.A, 1);
    EEG.trials = 1;
    EEG.pnts = size(sInput.A, 2);
    EEG.srate = 1 / (sInput.TimeVector(2) - sInput.TimeVector(1));
    EEG.xmin = sInput.TimeVector(1);
    EEG.xmax = sInput.TimeVector(end);
    EEG.times = sInput.TimeVector * 1000; % Convert to ms
    EEG.data = sInput.A;
    
    % Populate chanlocs
    for i = 1:length(ChannelMat.Channel)
        EEG.chanlocs(i).labels = ChannelMat.Channel(i).Name;
        if ~isempty(ChannelMat.Channel(i).Loc)
            EEG.chanlocs(i).X = ChannelMat.Channel(i).Loc(1);
            EEG.chanlocs(i).Y = ChannelMat.Channel(i).Loc(2);
            EEG.chanlocs(i).Z = ChannelMat.Channel(i).Loc(3);
        end
        EEG.chanlocs(i).type = ChannelMat.Channel(i).Type;
    end

    % Check the consistency of the dataset
    EEG = eeg_checkset(EEG);
end

function sOutput = eeglab2brainstorm(EEG, sInput)
    % Create a copy of the input structure
    sOutput = sInput;

    % Update the data
    sOutput.A = EEG.data;

    % Update the time vector if it has changed
    if (length(sOutput.TimeVector) ~= size(EEG.data, 2))
        sOutput.TimeVector = EEG.times / 1000; % Convert back to seconds
    end

    % Update the comment
    sOutput.Comment = EEG.setname;

    % Update the history
    if isfield(EEG, 'history')
        sOutput.History = EEG.history;
    end
end