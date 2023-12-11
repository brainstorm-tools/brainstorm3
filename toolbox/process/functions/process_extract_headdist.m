function varargout = process_extract_headdist( varargin )
% PROCESS_EXTRACT_HEADDIST Extract head distace time series and save it in a matrix file.
% 
% USAGE:  OutputFiles = process_extract_headdist('Run', sProcess, sInputs)

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
% Authors: Raymundo Cassani, 2023

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Extract head distance';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Extract';
    sProcess.Index       = 381;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw',    'data'};
    sProcess.OutputTypes = {'matrix', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
    sProcess.options.warning.Comment = 'Only for CTF MEG recordings with head localization channels (HLU) recorded.<BR><BR>';
    sProcess.options.warning.Type    = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
     Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize returned variable
    OutputFiles = {};
    % Set HLU distance montage
    sMontage = db_template('Montage');
    sMontage.Name = 'Head distance';
    sMontage.Type = 'custom';
    bst_progress('start', 'Detect head motion events', '', 0, 2*length(sInputs));
    for iInput = 1:length(sInputs)
        bst_progress('text', 'Loading HLU locations...');
        bst_progress('inc', 1);
        % Load input file
        DataMat = in_bst_data(sInputs(iInput).FileName);
        % Check for CTF.
        if ~strcmp(DataMat.Device, 'CTF')
            bst_report('Error', sProcess, sInputs(iInput), 'Extract head distance is currently only available for CTF data.');
        end
        % Channel file for Study
        ChannelMat = in_bst_channel(sInputs.ChannelFile);
        % Input sStudy (also output Study)
        [sStudy, iStudy] = bst_get('DataFile', sInputs(iInput).FileName);
        % Get montage for head distance
        sMontage = panel_montage('GetMontageHeadDistance', sMontage, ChannelMat.Channel, DataMat.ChannelFlag);
        if isempty(sMontage)
            bst_report('Error', sProcess, sInputs(iInput).FileName, 'There are not HLU channels in file');
        end
        % Get channels indices for the montage
        [iChannels, iMatrixChan, iMatrixDisp] = panel_montage('GetMontageChannels', sMontage, {ChannelMat.Channel.Name});
        % Get HLU data
        if strcmpi(sInputs(iInput).FileType, 'raw')
            % Raw file
            sFile = DataMat.F;
            [DataMat.F, DataMat.Time] = in_fread(sFile, ChannelMat, 1, [], iChannels);
        else
            % Data file
            DataMat.F = DataMat.F(iChannels,:);
        end
        bst_progress('text', 'Computing head distance...');
        bst_progress('inc', 1);
        % Apply head distance montage
        headDistF = panel_montage('ApplyMontage', sMontage, DataMat.F, sInputs(iInput).FileName, iMatrixDisp, iMatrixChan);
        % Save results in a matrix file
        newMat = db_template('matrixmat');
        newMat.Value        = headDistF;
        newMat.Description  = {'Dist'};
        newMat.ChannelFlag  = [];
        newMat.Time         = DataMat.Time;
        newMat.Comment      = [DataMat.Comment, ' | ', 'head dist'];
        newMat.DisplayUnits = 'mm';
        newMat = bst_history('add', newMat, 'compute', 'Head distance with Channel names renamed to 10-10 system according Biosemi caps.');
        bst_progress('text', 'Saving head distance...');
        % Save new  matrix file in database
        OutputFiles{iInput} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'matrix_headdist');
        % Save on disk
        bst_save(OutputFiles{iInput}, newMat, 'v6');
        % Register in database
        db_add_data(iStudy, OutputFiles{iInput}, newMat);
    end
    bst_progress('stop');
end
