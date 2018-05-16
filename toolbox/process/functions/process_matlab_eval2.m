function varargout = process_matlab_eval2( varargin )
% PROCESS_MATLAB_EVAL2: Evaluate a matlab script.

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
% Authors: Francois Tadel, 2013

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Run Matlab command';
    sProcess.FileTag     = 'matlab';
    sProcess.Category    = 'Filter2';
    sProcess.SubGroup    = 'Other';
    sProcess.Index       = 902;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/TutUserProcess#Alternative';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'raw', 'matrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isPaired    = 1;
    % Default values for some options
    sProcess.isSourceAbsolute = -1;
    sProcess.processDim  = [];
    % === Matlab command
    sProcess.options.matlab.Comment = 'Type your Matlab script below: ';
    sProcess.options.matlab.Type    = 'textarea';
    sProcess.options.matlab.Value   = ['% Input variables: DataA, DataB, TimeVector' 10  ...
                                       '% Output variables: Data, Comment, Condition', 10 ...
                                       'Data = DataA - DataB;' 10 ...
                                       'Comment = ''New file'';' 10 ...
                                       'Condition = ''NewCondition'';'];
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function sOutput = Run(sProcess, sInputA, sInputB) %#ok<DEFNU>
    % Prepare input
    DataA = sInputA.A;
    DataB = sInputB.A;
    TimeVector = sInputA.TimeVector;
    Comment    = sInputA.Comment;
    Condition  = [];
    
    % Evaluate Matlab code
    try
        eval(sProcess.options.matlab.Value);
    catch
        % Get error message
        e = lasterror();
        if ~isempty(e)
            % Remove HTML tags
            errMsg = str_striptag(e.message);
            % Strip "Error:"
            errMsg = strrep(errMsg, 'Error: ', '');
            % Strip first line
            iNewLine = find(errMsg == 10);
            if ~isempty(iNewLine)
                errMsg = errMsg(iNewLine(1)+1:end);
            end
            errMsg = ['Error while executing Matlab command:' 10 errMsg];
        else
            errMsg = 'Error while executing Matlab command.';
        end
        % Report error
        bst_report('Error', sProcess, sInputA, errMsg);
        sOutput = [];
        return;
    end

    % Check if time was modified with only a few sensors selected 
    if isfield(sProcess.options, 'sensortypes') && isfield(sProcess.options.sensortypes, 'Value') && ~isempty(sProcess.options.sensortypes.Value) && (length(TimeVector) ~= length(sInputA.TimeVector))
        sInputA = [];
        bst_report('Error', sProcess, sInputA, ...
            ['This process can modify the time definition only if all the channels are processed at once.' 10 ...
             'Either you leave the option "Sensor types or names" empty to process all the channels at once,' 10 ... 
             'or your keep the number of time points of the original file.']);
        return;
    end
    
    % Output structure
    sOutput = sInputA;
    % Output condition name
    sOutput.A         = Data;
    sOutput.Condition = Condition;
    sOutput.Comment   = Comment;
end




