function varargout = process_setAcquisitionDate( varargin )
% process_setAcquisitionDate: Set the acquisition date and time of the recording
% 
% USAGE:  
%         Output = Run(sProcess, sInput)
%         SetDateTimeRaw(FileName, acq_datetime)
%         SetDateTimeData(FileName, acq_datetime)

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
% Authors: Edouard Delaire, 2026

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>

    % Description the process
    sProcess.Comment     = 'Set Acquisition date';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1020;
    sProcess.Description = '';

    % Definition of the input accepted by this process
    sProcess.InputTypes  = { 'raw', 'data'};
    sProcess.OutputTypes = { 'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % === Acquisition date
    sProcess.options.acq_date.Comment = 'Date (YYYY-MM-DD): ';
    sProcess.options.acq_date.Type    = 'text';
    sProcess.options.acq_date.Value   = '';
    sProcess.options.acq_date.InputTypes = {'data', 'raw'};

    sProcess.options.acq_time.Comment = '24-hour time (HH:MM:SS) [ignore if empty]: ';
    sProcess.options.acq_time.Type    = 'text';
    sProcess.options.acq_time.Value   = '';
    sProcess.options.acq_time.InputTypes = {'data', 'raw'};
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function Output = Run(sProcess, sInput)
    
    file_date = strrep(sProcess.options.acq_date.Value, ' ', '');
    file_time = strrep(sProcess.options.acq_time.Value, ' ', '');
        
    if strcmp(sInput.FileType, 'raw')
        SetDateTimeRaw(sInput.iStudy, file_date, file_time);
    elseif strcmp(sInput.FileType, 'data')
        SetDateTimeData(sInput.FileName, acq_datetime)
    end

    Output = {sInput.FileName};
end

function SetDateTimeRaw(iStudy, acq_date, acq_time)
    
    if nargin < 3 || isempty(acq_time)
        acq_datetime = datetime(sprintf('%s', acq_date));
        has_time = 0;
    else
        acq_datetime = datetime(sprintf('%s %s', acq_date, acq_time));
        has_time = 1;
    end
    
    % Set acquisition time in the study file
    panel_record('SetAcquisitionDate', iStudy,  acq_date);
        
    % Set t0 for each files
    if has_time
        sStudy = bst_get('Study', iStudy);
        for iData = 1:length(sStudy.Data)
            sData = load(file_fullpath(sStudy.Data(iData).FileName));
            sData.F.t0 = str_datetime(acq_datetime - duration(0, 0, sData.Time(1)));
            bst_save(file_fullpath(sStudy.Data(iData).FileName),  sData);
        end
    end
end

function SetDateTimeData(FileName, acq_date, acq_time)
    sData = in_bst_data(FileName);
    sData.T0 = str_datetime(acq_datetime);
    bst_save(file_fullpath(FileName),  sData);
end
