function varargout = process_set_t0_datetime( varargin )
% PROCESS_SET_T0_DATETIME: Set the timestamp that corresponds to time = 0s for a data file
% 
% USAGE:  
%         Output = Run(sProcess, sInput)
%         Compute(DataFile, newStartDatetime)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundastion. Further details on the GPLv3
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
% Authors: Edouard Delaire, 2026
%          Raymundo Cassani, 2026

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Set datetime for time = 0s';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1021.5;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = { 'raw', 'data'};
    sProcess.OutputTypes = { 'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % === Acquisition date
    sProcess.options.t0_date.Comment = 'Date (YYYY-MM-DD): ';
    sProcess.options.t0_date.Type    = 'text';
    sProcess.options.t0_date.Value   = '';
    % === Acquisition time
    sProcess.options.t0_time.Comment = 'Time, 24-hour format (HH:MM:SS): ';
    sProcess.options.t0_time.Type    = 'text';
    sProcess.options.t0_time.Value   = '';
    % === Acquisition time
    sProcess.options.isUpdateStudyDate.Comment = 'Update acquisition date for the parent Study?';
    sProcess.options.isUpdateStudyDate.Type    = 'checkbox';
    sProcess.options.isUpdateStudyDate.Value   = 0;    
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function Output = Run(sProcess, sInput)
    Output = {sInput.FileName};

    emptyfields = {};
    errMsg = '';

    % Validate date time, and get timestamp
    file_date = strrep(sProcess.options.t0_date.Value, ' ', '');
    file_time = strrep(sProcess.options.t0_time.Value, ' ', '');
    isUpdateStudyDate = sProcess.options.isUpdateStudyDate.Value;    
    if isempty(file_date)
        emptyfields{end+1} = '"Date"';
    end
    if isempty(file_time)
        emptyfields{end+1} = '"Time"';
    end
    if ~isempty(emptyfields)
        errMsg = 'Field';
        if length(emptyfields) > 1
            errMsg = [errMsg 's'];
        end
        errMsg = [errMsg ': ' strjoin(emptyfields, ' and ') ' cannot be empty.'];
    else
        try
            ts = datetime([file_date ' ' file_time], 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
        catch ME
            errMsg = ME.message;                
        end
    end
    if ~isempty(errMsg)
        bst_report('Error', sProcess, sInput, errMsg);
        return
    end
    % Update t0/T0
    Compute(sInput.FileName, ts, isUpdateStudyDate);
end


%% ===== SET t0/T0 FOR DATA FILES =====
function Compute(DataFile, NewStartTs, isUpdateStudyDate)
    if nargin < 3 || isempty(isUpdateStudyDate)
        isUpdateStudyDate = 0;
    end
    if nargin < 2 || isempty(NewStartTs)
        ComputeInteractive(DataFile);
        return
    end

    % Check for raw data
    isRaw = (length(DataFile) > 9) && ~isempty(strfind(DataFile, 'data_0raw'));
    % Get only necessary fields
    if isRaw
        DataMat = in_bst_data(DataFile, {'F', 'Time'});
    else
        DataMat = in_bst_data(DataFile, {'T0', 'Time'});        
    end
    % Update only necessary fields
    if isRaw
        DataMat.F.t0 = newDateTimeStr;
    else
        DataMat.T0 = newDateTimeStr;
    end
    % Save
    bst_save(file_fullpath(DataFile), DataMat, [], 1);
    % Update Study acquisition time
    if isUpdateStudyDate
        [~, iStudy] = bst_get('DataFile', DataFile);
        panel_record('SetAcquisitionDate', iStudy, str_date(newDateTimeStr));
    end
end


%% ===== INTERACTIVE CALL =====
function ComputeInteractive(DataFile)
    % Ask for new acquisition date and time for data file
    res = java_dialog('input', {'Date (YYYY-MM-DD):', 'Time, 24-hour format (HH:MM:SS):'}, ...
           'Set datetime for time = 0s', [], {'YYYY-MM-DD', 'HH:MM:SS'});
    if isempty(res)
        return        
    end
    try
        ts = datetime([res{1} ' ' res{2}], 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
    catch ME
        bst_error(ME.message, 'Set t0 datetime', 0);
        return
    end
    res = java_dialog('question', 'Do you want to update acquisition date for the parent Study?', ...
            'Data acquisition Recording start datetime', [], {'Yes', 'No'}, 'Yes');

    isUpdateStudyDate = ~isempty(res) && strcmpi(res, 'Yes');
    % Compute    
    Compute(DataFile, ts, isUpdateStudyDate)
    % Update loaded data and figures time axis
    iDS = bst_memory('GetDataSetData', DataFile);
    if ~isempty(iDS)
        bst_memory('LoadDataFile', DataFile, 1);
        FigId.Type = 'DataTimeSeries'; FigId.SubType = []; FigId.Modality = [];
        hFigs = bst_figures('GetFigure', iDS, FigId);
        for ix = 1 : length(hFigs)
            figure_timeseries('UpdateXAxisTimeLabels', hFigs(ix), 'update');
        end
    end
end