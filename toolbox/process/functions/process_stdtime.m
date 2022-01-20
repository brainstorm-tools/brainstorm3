function varargout = process_stdtime( varargin )
% PROCESS_STDTIME: Uniformize the time vector for a list of input files.

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
% Authors: Francois Tadel, 2012-2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Uniform epoch time';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 302;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    sProcess.isSeparator = 1;
    % Help
    sProcess.options.help.Comment = ['Apply the time vector of the <B>first file</B> to all the <B>other files</B>.<BR><BR>' ...
                                     'If the number of samples is the same, it simply replaces the Time field.<BR>' ...
                                     'If the number of samples is different, it reinterpolates the values with<BR>' ...
                                     'Matlab function interp1.'];
    sProcess.options.help.Type    = 'label';
    % === Interpolation method
    sProcess.options.method.Comment = 'Interpolation method: ';
    sProcess.options.method.Type    = 'combobox_label';
    sProcess.options.method.Value   = {'spline', {'nearest', 'linear', 'spline', 'pchip', 'v5cubic', 'makima'; ...
                                                  'nearest', 'linear', 'spline', 'pchip', 'v5cubic', 'makima'}};
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
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Output
    OutputFiles = {};
    Time = [];
    % Get options
    if isfield(sProcess.options, 'method') && isfield(sProcess.options.method, 'Value') && ~isempty(sProcess.options.method.Value)
        Method = sProcess.options.method.Value{1};
    else
        Method = 'spline';
    end
    if isfield(sProcess.options, 'overwrite') && isfield(sProcess.options.overwrite, 'Value') && ~isempty(sProcess.options.overwrite.Value)
        isOverwrite = sProcess.options.overwrite.Value;
    else
        isOverwrite = 1;
    end
    % Process files one by one
    for iFile = 1:length(sInputs)
        % Get input study
        sStudy = bst_get('Study', sInputs(iFile).iStudy);
        % Links cannot be overwritten
        isLink = strcmpi(sInputs(iFile).FileType, 'results') && sStudy.Result(sInputs(iFile).iItem).isLink;
        if (iFile >= 2) && isLink && isOverwrite
            bst_report('Error', sProcess, sInputs(iFile), 'Result links cannot be overwritten. Disable the option "overwrite".');
            return;
        end
        % Load file
        [sMatrix, matName] = in_bst(sInputs(iFile).FileName);
        % Check if there is a non-empty time vector
        if ~isfield(sMatrix, 'Time') || isempty(sMatrix.Time)
            bst_report('Error', sProcess, sInputs(iFile), 'File does not have a Time vector.');
            return;
        end
        % First file: define time reference
        if (iFile == 1)
            Time = sMatrix.Time;
        % Following files: force the time vector of the first file
        else
            % If the time is not the same: reinterpolate values
            if (length(sMatrix.Time) ~= length(Time))
                % interp1 works only on single signals: loops in time and frequency
                F = sMatrix.(matName);
                newMat = zeros(size(F,1), length(Time), size(F,3));
                for iChan = 1:size(F,1)
                    for iFreq = 1:size(F,3)
                        newMat(iChan,:,iFreq) = interp1(linspace(0,1,length(sMatrix.Time)), F(iChan,:,iFreq), linspace(0,1,length(Time)), Method);
                    end
                end
                sMatrix.(matName) = newMat;
            end
            % Update time vector
            sMatrix.Time = Time;
            % Disconnect from parent file because time is not compatible anymore
            if isfield(sMatrix, 'DataFile') && ~isempty(sMatrix.DataFile)
                sMatrix.DataFile = [];
            end
            % Overwrite the input file
            if isOverwrite
                bst_save(file_fullpath(sInputs(iFile).FileName), sMatrix, 'v6');
                OutputFiles{end+1} = sInputs(iFile).FileName;
            % Save new file
            else
                % If results link
                if isLink
                    [OutputFile, DataFile] = file_resolve_link(sInputs(iFile).FileName);
                    OutputFile = strrep(OutputFile, '_KERNEL_', '_');
                    % Get data file comment and add to output file comment
                    DataMat = in_bst_data(DataFile, 'Comment');
                    sMatrix.Comment = [DataMat.Comment, ' | ', sMatrix.Comment];
                % Regular files
                else
                    OutputFile = file_fullpath(sInputs(iFile).FileName);
                    sMatrix.Comment = [sMatrix.Comment, ' | stdtime'];
                end
                % Save file: add file tag
                OutputFile = file_unique(strrep(OutputFile, '.mat', '_stdtime.mat'));
                bst_save(OutputFile, sMatrix, 'v6');
                % Add file to database structure
                db_add_data(sInputs(iFile).iStudy, OutputFile, sMatrix);
                % Add to list of returned files
                OutputFiles{end+1} = OutputFile;
            end
        end
    end
end



