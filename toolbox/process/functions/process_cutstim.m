function varargout = process_cutstim( varargin )
% PROCESS_CUTSTIM: Remove the values on a specific time window, and replace them with a linear interpolation.

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
% Authors: Francois Tadel, 2010-2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Cut stimulation artifact';
    sProcess.FileTag     = 'cutstim';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Artifacts';
    sProcess.Index       = 114;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/TutMindNeuromag#Stimulation_artifact';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Default values for some options
    sProcess.processDim  = 1;    % Process channel by channel
    
    % Definition of the options
    % === Help
    sProcess.options.help.Comment  = ['This process replaces a short time window around an event<BR>' ...
                                      'with interpolated values obtained with Matlab function interp1.<BR>' ...
                                      'Consider this option only for removing few data samples.<BR><BR>'];
    sProcess.options.help.Type     = 'label';
    % === Event names
    sProcess.options.eventname.Comment  = 'Event name (if empty, use t=0): ';
    sProcess.options.eventname.Type     = 'text';
    sProcess.options.eventname.Value    = '';
    % === Artifact time window
    sProcess.options.timewindow.Comment = 'Artifact time window:';
    sProcess.options.timewindow.Type    = 'range';
    sProcess.options.timewindow.Value   = {[-0.005, 0.005], 'ms', []};
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    % === Interpolation method
    sProcess.options.method.Comment = 'Interpolation method: ';
    sProcess.options.method.Type    = 'combobox_label';
    sProcess.options.method.Value   = {'linear', {'linear', 'spline', 'pchip', 'v5cubic', 'makima'; ...
                                                  'linear', 'spline', 'pchip', 'v5cubic', 'makima'}};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Get time window
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value{1})
        Time = sProcess.options.timewindow.Value{1};
    else
        Time = [];
    end
    % Add time window
    if isempty(Time)
        Comment = [sProcess.Comment ': [All file]'];
    elseif any(abs(Time) > 2)
        Comment = sprintf('%s: [%1.3fs,%1.3fs]', sProcess.Comment, Time(1), Time(2));
    else
        Comment = sprintf('%s: [%dms,%dms]', sProcess.Comment, round(Time(1)*1000), round(Time(2)*1000));
    end
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get inputs
    if isfield(sProcess.options, 'eventname') && isfield(sProcess.options.eventname, 'Value') && ~isempty(sProcess.options.eventname.Value)
        EvtName = strtrim(sProcess.options.eventname.Value);
    else
        EvtName = [];
    end
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value{1})
        TimeBounds = sProcess.options.timewindow.Value{1};
    else
        TimeBounds = [];
    end
    if isfield(sProcess.options, 'method') && isfield(sProcess.options.method, 'Value') && ~isempty(sProcess.options.method.Value)
        Method = sProcess.options.method.Value{1};
    else
        Method = 'linear';
    end
    
    % Check inputs
    if isempty(TimeBounds)
        bst_report('Error', sProcess, [], 'Invalid time definition.');
        sInput = [];
        return;
    end
    [Nchan, Ntime] = size(sInput.A);
    
    % Get the reference time event
    cutSegments = [];
    if ~isempty(EvtName)
        % Load the raw file descriptor
        isRaw = strcmpi(sInput.FileType, 'raw');
        if isRaw
            DataMat = in_bst_data(sInput.FileName, 'F');
            sFile = DataMat.F;
        else
            sFile = in_fopen(sInput.FileName, 'BST-DATA');
        end
        % If no markers are present in this file
        if isempty(sFile.events)
            bst_report('Error', sProcess, [], 'This file does not contain any event. Skipping File...');
            sInput = [];
            return;
        end
        % Find event in the list
        iEvt = find(strcmpi({sFile.events.label}, EvtName));
        if isempty(iEvt) || (size(sFile.events(iEvt).times,2) == 0)
            bst_report('Error', sProcess, [], ['Event not found:' EvtName]);
            sInput = [];
            return;
        end
        % Extended events: Use as is
        if (size(sFile.events(iEvt).times, 1) == 2)
            cutSegments = sFile.events(iEvt).times';
        % Simple events: Use the time window definition
        else
            cutSegments = bst_bsxfun(@plus, [sFile.events(iEvt).times', sFile.events(iEvt).times'], TimeBounds);
        end
    end
    % Default segment: around zero
    if isempty(cutSegments)
        cutSegments = TimeBounds;
    end
    
    % Process multiple blocks
    for iSeg = 1:size(cutSegments,1)
        % Get time indices to remove
        iTime = panel_time('GetTimeIndices', sInput.TimeVector, cutSegments(iSeg,:));
        if isempty(iTime)
            bst_report('Error', sProcess, [], 'Invalid time definition.');
            sInput = [];
            return;
        end
        % Get all the indices except but the removed time window
        iValid = setdiff(1:Ntime, iTime);
        if isempty(iValid)
            bst_report('Error', sProcess, [], 'No valid time segment left in the file.');
            sInput = [];
            return;
        end
        % Reinterpolate values for the removed time window
        for iChan = 1:Nchan
            sInput.A(iChan,iTime) = interp1(iValid, sInput.A(iChan,iValid), iTime, Method);
        end
    end
    
    % Do not keep the Std field in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
end




