function varargout = process_average_freq( varargin )
% PROCESS_AVERAGE_FREQ: For each file in input, compute the average of the different frequency bands.

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
% Authors: Francois Tadel, 2012-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Average frequency bands';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Average';
    sProcess.Index       = 303;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % === OVERWRITE
    sProcess.options.overwrite.Comment = 'Overwrite input files';
    sProcess.options.overwrite.Type    = 'checkbox';
    sProcess.options.overwrite.Value   = 0;
    sProcess.options.overwrite.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFile = [];
    isOverwrite = sProcess.options.overwrite.Value;
    % Load TF file
    TimefreqMat = in_bst_timefreq(sInput.FileName, 0);
    % Check for measure
    if strcmpi(TimefreqMat.Measure, 'none')
        bst_report('Error', sProcess, sInput, 'Cannot average complex values. Please apply a measure to the values before calling this function.');
        return;
    end
    % Average time-freq values
    TimefreqMat.TF = mean(TimefreqMat.TF, 3);
    % Remove the frequency information
    if iscell(TimefreqMat.Freqs)
        TimefreqMat.Freqs = {'Avg freq', TimefreqMat.Freqs{1,2}, TimefreqMat.Freqs{end,3}};
    else
        TimefreqMat.Freqs = TimefreqMat.Freqs(end);
    end
    % Do not keep the Std field in the output
    if isfield(TimefreqMat, 'Std') && ~isempty(TimefreqMat.Std)
        TimefreqMat.Std = [];
    end
    % TFmask: Keep only the values good everywhere
    if isfield(TimefreqMat, 'TFmask') && ~isempty(TimefreqMat.TFmask)
        TimefreqMat.TFmask = all(TimefreqMat.TFmask, 1);
    end
    
    % Add file tag
    TimefreqMat.Comment = [TimefreqMat.Comment, ' | avgfreq'];
    % Add history entry
    TimefreqMat = bst_history('add', TimefreqMat, 'avgfreq', 'Averaged all the frequency bands.');

    % Overwrite the input file
    if isOverwrite
        OutputFile = file_fullpath(sInput.FileName);
        bst_save(OutputFile, TimefreqMat, 'v6');
        % Reload study
        db_reload_studies(sInput.iStudy);
    % Save new file
    else
        % Output filename: add file tag
        OutputFile = strrep(file_fullpath(sInput.FileName), '.mat', '_avgfreq.mat');
        OutputFile = file_unique(OutputFile);
        % Save file
        bst_save(OutputFile, TimefreqMat, 'v6');
        % Add file to database structure
        db_add_data(sInput.iStudy, OutputFile, TimefreqMat);
    end
end




