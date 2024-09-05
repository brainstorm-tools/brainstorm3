function varargout = process_psd_features( varargin )
% PROCESS_PSD_FEATURES: Extract features from the power spectrum

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
    sProcess.Comment     = 'Compute PSD features';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Frequency';
    sProcess.Index       = 482;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/DeviationMaps';
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
    % Options: Extract coefficient of variation
    sProcess.options.cv.Comment = 'Extract cv';
    sProcess.options.cv.Type    = 'checkbox';
    sProcess.options.cv.Value   = 1;
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
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFiles = {};
    % Process options
    if (sProcess.options.mean.Value && sProcess.options.std.Value) || sProcess.options.cv.Value
        sProcess.options.win_std.Value = 'mean+std'; % One PSD file with mean and std across windows
    elseif sProcess.options.mean.Value
        sProcess.options.win_std.Value = 'mean';     % One PSD file with mean (Welch)
    elseif sProcess.options.std.Value
        sProcess.options.win_std.Value = 'std';      % One PSD file with std
    else
        bst_report('Error', sProcess, [], 'Must choose at least one feature.'); return;
    end

    % Call TIME-FREQ process
    OutputFile = process_timefreq('Run', sProcess, sInput);

    % Extract std and/or cv from one PSD (mean+std) file
    if strcmpi(sProcess.options.win_std.Value, 'mean+std')
        OutputFiles = ExtractStdCv(sProcess, OutputFile{1}, sInput);
    else
        OutputFiles = OutputFile;
    end
end

%% ===== EXTRACT PSD FEATURES =====
function OutputFiles = ExtractStdCv(sProcess, tfMeanStdFile, sInput)
    OutputFiles = {tfMeanStdFile};
    % Get options
    extractMean = sProcess.options.mean.Value;
    extractStd  = sProcess.options.std.Value;
    extractCv   = sProcess.options.cv.Value;
    % Load timefreq file with mean+std
    timefreqtMat = in_bst_timefreq(tfMeanStdFile);
    if isempty(timefreqtMat.Std)
        bst_report('Error', sProcess, [], 'Input file must contain Std matrix.');  
        return;
    end

    % Extract std from mean+std file, and save in new timefreq file
    if extractStd
        newTF = timefreqtMat.Std;
        OutputFile = saveMat(timefreqtMat, tfMeanStdFile, newTF, 'std', sInput);
        OutputFiles = [OutputFiles, OutputFile];
    end

    % Extract cv (std/mean) from mean+std file, and save in new timefreq file
    if extractCv
        newTF = timefreqtMat.Std ./ timefreqtMat.TF;
        OutputFile = saveMat(timefreqtMat, tfMeanStdFile, newTF, 'cv', sInput);
        OutputFiles = [OutputFiles, OutputFile];
    end

    % Modify or delete initial mean+std file
    if extractMean
        % Update content of original mean+std file
        % Remove std
        newMat.Std = [];
        % Update the function name
        newMat.Options = timefreqtMat.Options;
        newMat.Options.WindowFunction = 'mean';
        % Add extraction in history
        newMat.History = timefreqtMat.History;
        newMat = bst_history('add', newMat, 'extract_std_cv', sprintf('mean matrix extracted from %s', tfMeanStdFile));
        fileName = file_fullpath(tfMeanStdFile);
        bst_save(fileName, newMat, [], 1);
    else
        % Delete mean+std file
        bst_process('CallProcess', 'process_delete', tfMeanStdFile, [], 'target', 1);
        OutputFiles(1) = [];
    end
end

%% ===== UPDATE AND SAVE TIMEFREQ =====
function OutputFile = saveMat(timefreqtMat, tfMeanStdFile, newTF, function_name, sInput)
    % Update TF field
    newMat     = timefreqtMat;
    newMat.TF  = newTF;
    newMat.Std = [];
    % Update across-windows function name
    newMat.Options.WindowFunction = function_name;
    % Update Comment, append function name
    newMat.Comment = [timefreqtMat.Comment ' ' function_name];
    % Add extraction in history
    newMat = bst_history('add', newMat, 'extract_std_cv', sprintf('%s matrix extracted from %s', function_name, tfMeanStdFile));
    % New file name
    [tfMeanStdFilePath, tfMeanStdFileBase, tfMeanStdFileExt] = bst_fileparts(tfMeanStdFile);
    output = bst_fullfile(tfMeanStdFilePath, [tfMeanStdFileBase, '_' function_name, tfMeanStdFileExt]);
    output = file_unique(output);
    % Save the file
    bst_save(output, newMat, 'v6');
    db_add_data(sInput.iStudy, output, newMat);
    OutputFile = {output};
end

