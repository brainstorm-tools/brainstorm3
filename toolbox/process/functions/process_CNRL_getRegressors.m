function varargout = process_CNRL_getRegressors( varargin ) %#ok<STOUT>


eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() 
    % Description the process
    sProcess.Comment     = 'CNRL_Regressors';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'CNRL';
    sProcess.Index       = 10013;
    sProcess.Description = 'Get Regressors';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;

    sProcess.options.intercept.Comment = 'Include Intercept in Model';
    sProcess.options.intercept.Type    = 'checkbox';
    sProcess.options.intercept.Value   = 2;

    % === SELECT: ROWS
    sProcess.options.columns.Comment    = 'Regressor Description (one for each regressor, comma-seperated)';
    sProcess.options.columns.Type       = 'text';
    sProcess.options.columns.Value      = '';
    sProcess.options.columns.InputTypes = {'data'};

end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) 
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) 
    
    if sProcess.options.intercept.Value
        Description= {'Intercept'};
        intercept_column=1;
    else
        Description= {};
        intercept_column=0;
    end

    reg_titles = strsplit(sProcess.options.columns.Value, ',');
    reg_titles = erase(reg_titles, ' ');
    
    for i=1:length(reg_titles)
        Description{end+1} = reg_titles{i};

    end

    % sort input files by condition/subject
    [iGroups, ~] = process_average('SortFiles',sInputs, 3);

    OutputFiles = cell(1,length(iGroups));

    for i = 1:length(iGroups)
        
        sInput = sInputs(iGroups{i});


        OutEvents = zeros(length(sInput),3);
        OutEvents(:,1) = ones(length(sInput),1);
        for iInput = 1:length(sInput)

            [FileMat, ~] = in_bst(sInput(iInput).FileName, [-0.01, 0.01]);

            % === EVENTS ===
            if isfield(FileMat, 'Events') && ~isempty(FileMat.Events) 
                if length(reg_titles) == length(FileMat.Events) 
                    for j=1:length(reg_titles)
                        OutEvents(iInput,intercept_column+j) = str2double(FileMat.Events(j).label);
                    end
                else
                    disp(['Not enough events in trial ' num2str(iInput)]);
                end
            else
                disp(['No events in trial ' num2str(iInput)]);
            end
        end

        % ===== GET OPTIONS =====
        [~, iStudy, ~] = bst_process('GetOutputStudy', sProcess, sInput);

        OutputFiles{i} = CNRL_import_matrix(iStudy,OutEvents',Description,1);
    end

end

function OutputFile = CNRL_import_matrix(iStudy, Value, Description, sfreq)
    % IMPORT_MATRIX: Imports a 2D matrix as a "matrix" file.
    % 
    % USAGE:  OutputFile = import_matrix(iStudy, Value=[ask], sfreq=[ask])
    %
    % INPUT:
    %    - iStudy  : Index of the study where to import the SourceFiles
    %    - Value   : 2D matrix to import as a "matrix" object in the database
    %                If not specified: ask for selecting a variable in the workspace
    %    - sfreq   : Sampling frequency of the signals (Hertz)

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
    % Authors: Francois Tadel, 2015

    % Parse inputs
    if (nargin < 3) || isempty(sfreq)
        sfreq = [];
    end
    if (nargin < 2) || isempty(Value)
        Value = [];
    end
    OutputFile = [];

    % Ask for a variable in the workspace
    if isempty(Value)
        Value = in_matlab_var([], 'numeric');
        if isempty(Value)
            OutputFile = [];
            return
        end
    end
    % Build time vector
    if (size(Value,2) == 1)
        Time = 0;
    elseif (size(Value,2) == 2)
        Time = [0 1];
    else
        % Ask for the sampling frequency
        if isempty(sfreq)
            res = java_dialog('input', sprintf('Matrix size: [%d signals x %d samples].\nEnter the sampling frequency of the signal:\n\n', size(Value,1), size(Value,2)), 'Import data matrix', [], '1000');
            if isempty(res) || isempty(str2num(res)) || (str2num(res) < 0)
                return;
            end
            sfreq = str2num(res);
        end
        % Create time vector
        Time = (0:(size(Value,2)-1)) ./ sfreq;
    end

    % Create a "matrix" structure
    sMat = db_template('matrixmat');
    sMat.Value       = Value;
    sMat.Time        = Time;
    sMat.Comment     = sprintf('Imported matrix [%dx%d]', size(Value,1), size(Value,2));
    sMat.Description = Description;
    % Add history entry
    sMat = bst_history('add', sMat, 'process', 'Imported matrix');

    % Add structure to database
    OutputFile = db_add(iStudy, sMat);

end