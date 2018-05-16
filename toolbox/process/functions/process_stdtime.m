function varargout = process_stdtime( varargin )
% PROCESS_STDTIME: Uniformize the time vector for a list of input files.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
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
% Authors: Francois Tadel, 2012-2017

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
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    sProcess.isSeparator = 1;
    % Help
    sProcess.options.help.Comment = ['Apply the time vector of the first file to all the other files.<BR>' ...
                                     'If the number of samples is the same, it simply replaces the Time field.<BR>' ...
                                     'If the number of samples is different, it reinterpolates the values with<BR>' ...
                                     'Matlab function interp1. <B>Always overwrites the input files</B>.'];
    sProcess.options.help.Type    = 'label';
    % === Interpolation method
    sProcess.options.method.Comment = 'Interpolation method: ';
    sProcess.options.method.Type    = 'combobox_label';
    sProcess.options.method.Value   = {'spline', {'linear', 'spline', 'pchip', 'v5cubic', 'makima'; ...
                                                  'linear', 'spline', 'pchip', 'v5cubic', 'makima'}};
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
    % Process files one by one
    for iFile = 1:length(sInputs)
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
            % Update file
            bst_save(file_fullpath(sInputs(iFile).FileName), sMatrix, 'v6');
            OutputFiles{end+1} = sInputs(iFile).FileName;
        end
    end
end



