function varargout = process_fft_features( varargin )
% PROCESS_FFT_FEATURES: Extract features from the power spectrum

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
% Authors: Pauline Amrouche, Raymundo Cassani, 2024

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Get FFT features';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Frequency';
    sProcess.Index       = 482;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data', 'results', 'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Options: Time window
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % Option: Window (Length)
    sProcess.options.win_length.Comment    = 'Window length: ';
    sProcess.options.win_length.Type       = 'value';
    sProcess.options.win_length.Value      = {1, 's', []};
    % Option: Window (Overlapping ratio)
    sProcess.options.win_overlap.Comment    = 'Window overlap ratio: ';
    sProcess.options.win_overlap.Type       = 'value';
    sProcess.options.win_overlap.Value      = {50, '%', 1};
    % Options: Units / scaling
    sProcess.options.units.Comment    = {'Physical: U<SUP>2</SUP>/Hz', '<FONT color="#a0a0a0">Normalized: U<SUP>2</SUP>/Hz/s</FONT>', ...
        '<FONT color="#a0a0a0">Before Nov 2020</FONT>', 'Units:'; ...
        'physical', 'normalized', 'old', ''};
    sProcess.options.units.Type       = 'radio_linelabel';
    sProcess.options.units.Value      = 'physical';
    % Options: CLUSTERS
    sProcess.options.clusters.Comment = '';
    sProcess.options.clusters.Type    = 'scout_confirm';
    sProcess.options.clusters.Value   = {};
    sProcess.options.clusters.InputTypes = {'results'};
    % Options: Scout function
    sProcess.options.scoutfunc.Comment    = {'Mean', 'Max', 'PCA', 'Std', 'All', 'Scout function:'};
    sProcess.options.scoutfunc.Type       = 'radio_line';
    sProcess.options.scoutfunc.Value      = 1;
    sProcess.options.scoutfunc.InputTypes = {'results'};
    % Options: Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'raw','data'};
    % Options: Extract mean
    sProcess.options.mean.Comment = 'Extract mean';
    sProcess.options.mean.Type    = 'checkbox';
    sProcess.options.mean.Value   = 1;
    % Options: Extract std
    sProcess.options.std.Comment = 'Extract std';
    sProcess.options.std.Type    = 'checkbox';
    sProcess.options.std.Value   = 1;
    % Options: Extract varcoef
    sProcess.options.varcoef.Comment = 'Extract varcoef';
    sProcess.options.varcoef.Type    = 'checkbox';
    sProcess.options.varcoef.Value   = 1;
    % Options: Compute relative power
    sProcess.options.relative.Comment = 'Use relative power';
    sProcess.options.relative.Type    = 'checkbox';
    sProcess.options.relative.Value   = 0;
    % Separator
    sProcess.options.sep.Type     = 'label';
    sProcess.options.sep.Comment  = '  ';
    % Options: Time-freq
    sProcess.options.edit.Comment = {'panel_timefreq_options', ' PSD options: '};
    sProcess.options.edit.Type    = 'editpref';
    sProcess.options.edit.Value   = [];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Process options
    if (sProcess.options.mean.Value && sProcess.options.std.Value) || sProcess.options.varcoef.Value
        sProcess.options.win_std.Value = 'mean+std';
    elif sProcess.options.mean.Value
        sProcess.options.win_std.Value = 'mean';
    elif sProcess.options.std.Value
        sProcess.options.win_std.Value = 'std';
    else
        bst_report('Error', sProcess, [], 'Must choose at least one feature.'); return;
    end

    % Call TIME-FREQ process
    OutputFiles = process_timefreq('Run', sProcess, sInputs);

    % If extract several features or varcoef
    if strcmpi(sProcess.options.win_std.Value, 'mean+std')
        % Get Output Study
        [sStudy, iStudy, ~] = bst_process('GetOutputStudy', sProcess, sInputs);
        OutputFiles = ExtractStdVarcoef(sProcess, OutputFiles, sStudy, iStudy);
    end

end

function OutputFiles = ExtractStdVarcoef(sProcess, MeanStdFiles, sStudy, iStudy) %#ok<DEFNU>
    
    OutputFiles = {};

    % Get options
    extractMean    = sProcess.options.mean.Value;
    extractStd     = sProcess.options.std.Value;
    extractVarcoef = sProcess.options.varcoef.Value;

    inputFile = MeanStdFiles(1);
    inputMat = in_bst_timefreq(inputFile.FileName);

    if isempty(inputMat.Std)
        bst_report('Error', sProcess, [], 'Input file must contain Std matrix.');  
        return;
    end

    if extractStd
        % Copy Std matrix of input file into TF field of stdFile
        newTF = inputMat.Std;
        OutputFiles = saveMat(inputMat, inputFile, newTF, 'std', sStudy, iStudy, OutputFiles);
    end

    if extractVarcoef
        % Varcoef = std ./ mean
        newTF = inputMat.Std ./ inputMat.TF;
        OutputFiles = saveMat(inputMat, inputFile, newTF, 'varcoef', sStudy, iStudy, OutputFiles);
    end

    if extractMean
        % Do not change TF
        newMat.Std = [];
        % Update the function name
        newMat.Options = inputMat.Options;
        newMat.Options.WindowFunction = 'mean';
        % Update Comment
        newMat.Comment = replace(inputMat.Comment, 'mean+std', 'mean');
        % Add extraction in history
        newMat.History = inputMat.History;
        newMat = bst_history('add', newMat, 'extract_std_varcoef', sprintf('mean matrix extracted from %s', inputFile.FileName));
        fileName = file_fullpath(inputFile.FileName);
        bst_save(fileName, newMat, [], 1);
        OutputFiles{end+1} = fileName;

    else
        % Delete file
        bst_process('CallProcess', 'process_delete', MeanStdFiles, [], ...
            'target', 1);
    end
    db_reload_studies(iStudy);
end

function OutputFiles = saveMat(inputMat, inputFile, newTF, function_name, sStudy, iStudy, OutputFiles)
    newMat = inputMat;
    newMat.TF = newTF;
    newMat.Std = [];
    % Update the function name
    newMat.Options.WindowFunction = function_name;
    % Update Comment, replace mean+std with function name
    newMat.Comment = replace(inputMat.Comment, 'mean+std', function_name);
    % Add extraction in history
    newMat = bst_history('add', newMat, 'extract_std_varcoef', sprintf('%s matrix extracted from %s', function_name, inputFile.FileName));
    [~, inputFilename] = bst_fileparts(inputFile.FileName);
    output = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [inputFilename, function_name]);
    % Save the file
    bst_save(output, newMat, 'v6');
    db_add_data(iStudy, output, newMat);
    OutputFiles{end+1} = output;
end




