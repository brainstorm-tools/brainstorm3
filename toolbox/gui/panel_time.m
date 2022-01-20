function varargout = panel_time(varargin)
% PANEL_TIME: Time window panel.
%
% USAGE:  bstPanel = panel_time('CreatePanel')
%                    panel_time('UpdatePanel')
%         timeUnit = panel_time('GetTimeUnit')
%       TimeVector = panel_time('GetRawTimeVector', sFile)
%                    panel_time('SetCurrentTime',  value)
%                    panel_time('TimeKeyCallback', keyEvent);

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
% Authors: Francois Tadel, 2008-2017

eval(macro_method);
end


%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'Time window';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;

    % Create tool panel
    jPanelNew = gui_river([1,4], [2,2,10,1]);
    jPanelNew.setMinimumSize(java_scaled('dimension', 10, 42));
    % Time labels
    jLabelTime = gui_component('label', jPanelNew, 'hfill', ' ');
    jLabelTime.setPreferredSize(java_scaled('dimension', 10, 42));
    
    % Time: Previous
    gui_component('label', jPanelNew, 'br', ' ');
    jButtonTime(1) = gui_component('button', jPanelNew, '', '<<<', [], [], @(h,ev)TimeKeyCallback('epoch-'));
    jButtonTime(2) = gui_component('button', jPanelNew, '',  '<<', [], [], @(h,ev)TimeKeyCallback('pagedown'));
    jButtonTime(3) = gui_component('button', jPanelNew, '',   '<', [], [], @(h,ev)TimeKeyCallback('leftarrow'));
    % Time: Current
    jTextCurrent = gui_component('texttime', jPanelNew, 'hfill', ' ');
    jTextCurrent.setPreferredSize(java_scaled('dimension', 62, 20));
    jTextCurrent.setHorizontalAlignment(JTextField.RIGHT);
    java_setcb(jTextCurrent, 'FocusLostCallback', @TextValidationCallback, 'ActionPerformedCallback', @TextValidationCallback);
    % Time: Next
    jButtonTime(4) = gui_component('button', jPanelNew, '', '>',   [], [], @(h,ev)TimeKeyCallback('rightarrow'));
    jButtonTime(5) = gui_component('button', jPanelNew, '', '>>',  [], [], @(h,ev)TimeKeyCallback('pageup'));
    jButtonTime(6) = gui_component('button', jPanelNew, '', '>>>', [], [], @(h,ev)TimeKeyCallback('epoch+'));
    gui_component('label', jPanelNew, '', ' ');
    
    % Button size
    jButtonTime(1).setPreferredSize(java_scaled('dimension', 28, 20));
    jButtonTime(2).setPreferredSize(java_scaled('dimension', 24, 20));
    jButtonTime(3).setPreferredSize(java_scaled('dimension', 20, 20));
    jButtonTime(4).setPreferredSize(java_scaled('dimension', 20, 20));
    jButtonTime(5).setPreferredSize(java_scaled('dimension', 24, 20));
    jButtonTime(6).setPreferredSize(java_scaled('dimension', 28, 20));
    % Buttons properties
    for i = 1:length(jButtonTime)
        jButtonTime(i).setBorder([]);
        jButtonTime(i).setMargin(java_scaled('insets', 0, 3, 0, 3));
        jButtonTime(i).setFocusPainted(0);
        java_setcb(jButtonTime(i), 'KeyPressedCallback', @(h,ev)TimeKeyCallback(ev));
    end
    % Buttons tooltips
    jButtonTime(3).setToolTipText('<HTML><TABLE><TR><TD>Previous sample</TD></TR><TR><TD>Related shortcuts: <BR><B> - [ARROW LEFT]<BR> - [ARROW DOWN]</B></TD></TR> </TABLE>');
    jButtonTime(4).setToolTipText('<HTML><TABLE><TR><TD>Next sample</TD></TR><TR><TD>Related shortcuts: <BR><B> - [ARROW RIGHT]<BR> - [ARROW UP]</B></TD></TR></TABLE>');
    % Different shortcuts for MacOS
    if strncmp(computer,'MAC',3)
        jButtonTime(1).setToolTipText('<HTML><TABLE><TR><TD>Previous epoch/page/file</TD></TR><TR><TD>Related shortcuts:<BR><B> - [CTRL+SHIFT+ARROW LEFT]<BR> - [SHIFT+ARROW DOWN]<BR> - [SHIFT+Fn+F3]</B></TD></TR> <TR><TD>Other scrolling options:<BR><B> - [SHIFT+Fn+F4]</B> : Half page<BR><B> - [SHIFT+Fn+F6]</B> : Full page with no overlap<BR><B> - [CTRL+PAGE DOWN]</B>: -10 pages</TD></TR></TABLE>');
        jButtonTime(2).setToolTipText('<HTML><TABLE><TR><TD>Previous sample (x10)</TD></TR><TR><TD>Shortcut: <B>[Fn+ARROW DOWN]</B></TD></TR></TABLE>');
        jButtonTime(5).setToolTipText('<HTML><TABLE><TR><TD>Next sample (x10)</TD></TR><TR><TD>Shortcut: <B>[Fn+ARROW UP]]</B></TD></TR></TABLE>');
        jButtonTime(6).setToolTipText('<HTML><TABLE><TR><TD>Next epoch/page/file</TD></TR><TR><TD>Related shortcuts:<BR><B> - [CTRL+SHIFT+ARROW RIGHT]<BR> - [SHIFT+ARROW UP]<BR> - [Fn+F3]</B></TD></TR> <TR><TD>Other scrolling options:<BR><B> - [Fn+F4]</B> : Half page<BR><B> - [Fn+F6]</B> : Full page with no overlap<BR><B> - [CTRL+PAGE UP]</B>: +10 pages</TD></TR></TABLE>');
    else
        jButtonTime(1).setToolTipText('<HTML><TABLE><TR><TD>Previous epoch/page/file</TD></TR><TR><TD>Related shortcuts:<BR><B> - [CTRL+ARROW LEFT]<BR> - [SHIFT+ARROW DOWN]<BR> - [SHIFT+F3]</B></TD></TR> <TR><TD>Other scrolling options:<BR><B> - [SHIFT+F4]</B> : Half page<BR><B> - [SHIFT+F6]</B> : Full page with no overlap<BR><B> - [CTRL+PAGE DOWN]</B>: -10 pages</TD></TR></TABLE>');
        jButtonTime(2).setToolTipText('<HTML><TABLE><TR><TD>Previous sample (x10)</TD></TR><TR><TD>Shortcut: <B>[PAGE DOWN]</B></TD></TR></TABLE>');
        jButtonTime(5).setToolTipText('<HTML><TABLE><TR><TD>Next sample (x10)</TD></TR><TR><TD>Shortcut: <B>[PAGE UP]</B></TD></TR></TABLE>');
        jButtonTime(6).setToolTipText('<HTML><TABLE><TR><TD>Next epoch/page/file</TD></TR><TR><TD>Related shortcuts:<BR><B> - [CTRL+ARROW RIGHT]<BR> - [SHIFT+ARROW UP]<BR> - [F3]</B></TD></TR> <TR><TD>Other scrolling options:<BR><B> - [F4]</B> : Half page<BR><B> - [F6]</B> : Full page with no overlap<BR><B> - [CTRL+PAGE UP]</B>: +10 pages</TD></TR></TABLE>');
    end
    jTextCurrent.setToolTipText('<HTML>Current time <B>[editable]</B>');
    
    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jPanelTimeWindow',    jPanelNew, ...
                                  'jLabelTime',          jLabelTime, ...
                                  'jTextCurrent',        jTextCurrent, ...
                                  'jButtonTime',         jButtonTime));
                              

                              
    %% =================================================================================
    %  === CONTROLS CALLBACKS  =========================================================
    %  =================================================================================
    %% ===== TEXT AREA VALIDATION CALLBACK =====
    function isValidated = TextValidationCallback(h, event, varargin)
        % Get and check value
        value = str2double(char(event.getSource.getText()));
        if isempty(value) || isnan(value)
            isValidated = 0;
            return
        else
            isValidated = 1;
        end
        % Get time units
        timeUnit = GetTimeUnit();
        % Update value according to time units
        if strcmpi(timeUnit, 'ms')
            value = value / 1000;
        end
        % Set focus to panel container panel
        event.getSource.getParent.grabFocus();
        % Change current time
        SetCurrentTime(value);
    end

end


%% =================================================================================
%  === OTHER FUNCTIONS  ============================================================
%  =================================================================================
%% ===== UPDATE PANEL =====
function UpdatePanel(varargin)
    global GlobalData;
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'Time Window');
    if isempty(ctrl)
        return
    end
    % Get time unit
    [timeUnit, isRaw, precision] = GetTimeUnit();
    % There is data : display values
    if ~isempty(GlobalData.UserTimeWindow.Time)
        % For lower sampling frequencies: display decimals
        if (1 / GlobalData.UserTimeWindow.SamplingRate < 100)
            strSmp = sprintf('%1.2f', 1 / GlobalData.UserTimeWindow.SamplingRate);
        else
            strSmp = sprintf('%d', round(1 / GlobalData.UserTimeWindow.SamplingRate));
        end
        % Time window to display
        if isRaw 
            TimeBounds = GlobalData.FullTimeWindow.Epochs(GlobalData.FullTimeWindow.CurrentEpoch).Time([1 end]);
            strSmp = sprintf('Sampling: %s Hz', strSmp);
        else
            TimeBounds = GlobalData.UserTimeWindow.Time;
            if (GlobalData.UserTimeWindow.NumberOfSamples > 2)
                strSmp = sprintf('Sampling: %s Hz    %d samples', strSmp, GlobalData.UserTimeWindow.NumberOfSamples);
            else
                strSmp = 'Time average';
            end
        end
        % Format strings
        strTimeCur = FormatValue(GlobalData.UserTimeWindow.CurrentTime, timeUnit, precision);
        strTimeWindow = ['[' FormatValue(TimeBounds(1), timeUnit, precision) ', ' FormatValue(TimeBounds(2), timeUnit, precision) ']'];
        % Time window description
        strTime = ['<HTML><TABLE><TR><TD>  Time:   <B>' strTimeWindow '</B> ' timeUnit '</TD></TR><TR><TD>  ' strSmp '</TD></TR></TABLE>'];
        strTime = strrep(strTime, ' ', '&nbsp;');
        ctrl.jLabelTime.setText(strTime);
        % Current time
        ctrl.jTextCurrent.setText(strTimeCur);
        % Enable all panel controls
        ctrl.jTextCurrent.setEnabled(1);
        ctrl.jTextCurrent.setBackground(javax.swing.UIManager.getColor('Panel.background'));
        for i = 1:length(ctrl.jButtonTime)
            ctrl.jButtonTime(i).setEnabled(1);
        end
    else
        % Disable all panel controls
        ctrl.jTextCurrent.setEnabled(0);
        ctrl.jLabelTime.setText('<HTML><CENTER><FONT color=#555555>&nbsp;&nbsp;No data loaded.</FONT></CENTER>');
        for i = 1:length(ctrl.jButtonTime)
            ctrl.jButtonTime(i).setEnabled(0);
        end
    end
end


%% ===== SET CURRENT TIME =====
function SetCurrentTime(value)
    global GlobalData;
    % Parse inputs
    if isempty(GlobalData) || isempty(GlobalData.UserTimeWindow) || isempty(GlobalData.UserTimeWindow.Time)
        return
    end
    % Save old value for CurrentTime
    oldTime = GlobalData.UserTimeWindow.CurrentTime;

    % If value is valid, set new value
    if (~isempty(value) && ~isnan(value))
        % Do not modify value (saturated later...)
    % Use previous value
    else
        value = GlobalData.UserTimeWindow.Time(2);
    end
    % Update value in global variable 'data'
    newTime = value;

    % Current time bounds
    TimeBounds = GlobalData.UserTimeWindow.Time;
    % If there is a raw file loaded: use its full window
    iDSRaw = bst_memory('GetRawDataSet');
    if ~isempty(iDSRaw)
        FullTimeBounds = GlobalData.FullTimeWindow.Epochs(GlobalData.FullTimeWindow.CurrentEpoch).Time([1 end]);
        % If new time is outside of the current page but inside the full time definition
        if ((newTime < TimeBounds(1)) || (newTime > TimeBounds(2))) && (newTime >= FullTimeBounds(1)) && (newTime <= FullTimeBounds(2))
            % Define the new page to load
            if (newTime > TimeBounds(2))
                startTime = newTime - .1 * (TimeBounds(2) - TimeBounds(1));
            else
                startTime = newTime - .9 * (TimeBounds(2) - TimeBounds(1));
            end
            % Get raw viewer window
            panel_record('SetStartTime', startTime, GlobalData.FullTimeWindow.CurrentEpoch);
            % Get new time window
            TimeBounds = GlobalData.UserTimeWindow.Time;
        end
    end
    
    % CURRENT TIME value must be > START and < STOP
	newTime = bst_saturate(newTime, TimeBounds);
    % Distance from UserTimeWindow.Time(1) must be a multiple of UserTimeWindow.SamplingRate
    newTime = round((newTime - TimeBounds(1)) / GlobalData.UserTimeWindow.SamplingRate) * GlobalData.UserTimeWindow.SamplingRate + TimeBounds(1);
    % Rectification (if CurrentTime is > STOP after alignment witch SamplingRate)
    if (newTime - TimeBounds(2) > 1e-6)
        newTime = newTime - GlobalData.UserTimeWindow.SamplingRate;
    end

    % If current time changed
    if (oldTime ~= newTime)
        % Actually change time
        GlobalData.UserTimeWindow.CurrentTime = newTime;
        % Force redraw static figures ONLY if there is currently only the static files visible
        ForceTime = (GlobalData.UserTimeWindow.NumberOfSamples <= 2);
        % Update plots
        bst_figures('FireCurrentTimeChanged', ForceTime);
    end
    % Update panel
    UpdatePanel();
end


%% ===== GET TIME UNIT =====
function [timeUnit, isRaw, precision] = GetTimeUnit()
    global GlobalData;
    % Default values
    timeUnit = 'ms';
    isRaw = 0;
    precision = 0;
    % In case of weird behavior
    if isempty(GlobalData)
        return
    end
    % If there is a raw file loaded: use its full window
    isRaw = ~isempty(bst_memory('GetRawDataSet'));
    if isRaw
        TimeBounds = GlobalData.FullTimeWindow.Epochs(GlobalData.FullTimeWindow.CurrentEpoch).Time([1 end]);
    else
        TimeBounds = GlobalData.UserTimeWindow.Time;
    end
    if isempty(TimeBounds)
        return;
    end
    % If max time large: use seconds instead of miliseconds
    if (abs(TimeBounds(2)) > 2)
        timeUnit = 's';
        dt = GlobalData.UserTimeWindow.SamplingRate;
    else
        timeUnit = 'ms';
        dt = 1000 * GlobalData.UserTimeWindow.SamplingRate;
    end
    % Number of signative digits
    if (dt < 1)
        precision = ceil(-log10(dt));
    elseif (dt == 1)
        precision = 0;
    else
        precision = 1;
    end
end


%% ===== FORMAT TIME =====
function strVal = FormatValue(val, units, precision)
    % Time display depends on the units
    if strcmpi(units, 'ms')
        val = 1000 * val;
    end
    % Adapted fromat for required precision
    if (precision == 0)
        textFormat = '%d';
        val = round(val);
    else
        textFormat = ['%1.' num2str(precision) 'f'];
        val = round(val .* 10^precision) ./ 10^precision;
    end
    % Replace the zeros with abs(0), not to have the typical "-0.0"
    val(val == 0) = abs(0);
    % Print string
    if isempty(val)
        strVal = '';
    elseif (length(val) > 1)
        strVal = sprintf([textFormat ' '], val);
        strVal(end) = [];
    else
        strVal = sprintf(textFormat, val);
    end
end



%% ===== SLIDER KEYBOARD ACTION =====
function TimeKeyCallback(ev)    
    global GlobalData;
    if isempty(GlobalData.UserTimeWindow.Time)
        return;
    end
    % Set a mutex to prevent to enter twice at the same time in the routine
    global TimeSliderMutex;
    if (isempty(TimeSliderMutex))
        tic
        % Set mutex
        TimeSliderMutex = 1;
        
        % === CONVERT KEY EVENT TO MATLAB ===
        [keyEvent, isControl, isShift] = gui_brainstorm('ConvertKeyEvent', ev);
        if isempty(keyEvent.Key)
            TimeSliderMutex = [];
            return
        end
        
        % === PROCESS KEY ===
        isRaw = ~isempty(bst_memory('GetRawDataSet'));
        isEpoch = isRaw && (length(GlobalData.FullTimeWindow.Epochs) > 1);
        % Convert f3 and f4
        if isRaw
            if strcmpi(keyEvent.Key, 'f3')
                if isShift
                    keyEvent.Key = 'epoch-';
                else
                    keyEvent.Key = 'epoch+';
                end
            elseif strcmpi(keyEvent.Key, 'f4')
                if isShift
                    keyEvent.Key = 'halfpage-';
                else
                    keyEvent.Key = 'halfpage+';
                end
            elseif strcmpi(keyEvent.Key, 'f6')
                if isShift
                    keyEvent.Key = 'nooverlap-';
                else
                    keyEvent.Key = 'nooverlap+';
                end
            end
        end
        % EPOCH: NEXT+2, NEXT+3
        if isEpoch && (ismember(keyEvent.Key, {'epoch+','epoch++'}) || ...
                       (isControl && strcmpi(keyEvent.Key, 'pageup')) || ...
                       (~isShift && strcmpi(keyEvent.Key, 'f3')))
            panel_record('SpinnerButtonUp');
        % EPOCH: PREV-2, PREV-3
        elseif isEpoch && (ismember(keyEvent.Key, {'epoch-','epoch--'}) || ...
                           (isControl && strcmpi(keyEvent.Key, 'pagedown')) || ...
                           (isShift && strcmpi(keyEvent.Key, 'f3')))
            panel_record('SpinnerButtonDown');
        % RAW: NEXT+2, NEXT+3, PREV-2, PREV-3
        elseif isRaw && ((isShift && ismember(keyEvent.Key, {'uparrow','downarrow','pageup','pagedown'})) || ...
                         (isControl && ismember(keyEvent.Key, {'rightarrow','leftarrow','pageup','pagedown'})) || ...
                          ismember(keyEvent.Key, {'epoch+','epoch++','epoch-','epoch--','halfpage+','halfpage-','nooverlap+','nooverlap-'}))
            panel_record('RawKeyCallback', keyEvent);
        % RAW+Shift: move to the next/previous event
        elseif ismember('shift', keyEvent.Modifier) && ismember(keyEvent.Key, {'rightarrow','leftarrow','pageup','pagedown'})
            panel_record('JumpToEvent', keyEvent.Key);
        % Normal time change
        else
            % Get current time window
            CurrentTime  = GlobalData.UserTimeWindow.CurrentTime;
            SamplingRate = GlobalData.UserTimeWindow.SamplingRate;
            % Switch between different keys
            switch (keyEvent.Key)
                case {'leftarrow', 'downarrow'},  SetCurrentTime(CurrentTime - SamplingRate);
                case {'rightarrow', 'uparrow'},   SetCurrentTime(CurrentTime + SamplingRate);     
                case 'pageup',                    SetCurrentTime(CurrentTime + 10 * SamplingRate);
                case 'pagedown',                  SetCurrentTime(CurrentTime - 10 * SamplingRate);
                case {'epoch+', 'epoch++', 'halfpage+', 'nooverlap+'},  bst_navigator('DbNavigation', 'NextData');
                case {'epoch-', 'epoch--', 'halfpage-', 'nooverlap-'},  bst_navigator('DbNavigation', 'PreviousData');
                case 'home',                      SetCurrentTime(GlobalData.UserTimeWindow.Time(1));
                case 'end',                       SetCurrentTime(GlobalData.UserTimeWindow.Time(2));
            end
        end
        drawnow;
        % Release mutex
        TimeSliderMutex = [];
        
    else
        % Release mutex if last keypress was processed more than one 2s ago
        % (restore keyboard after a bug...)
        t = toc;
        if (t > 2)
            TimeSliderMutex = [];
        end
    end
end


%% ===== INPUT TIME WINDOW =====
% USAGE:  [TimeWindow, isUpdatedTime] = InputTimeWindow(maxTimeWindow, Comment, defTimeWindow=[maxTimeWindow], timeUnit=[detect], rawTimeWindow=[])
%         [TimeWindow, isUpdatedTime] = InputTimeWindow(maxTimeWindow, Comment)
function [TimeWindow, isUpdatedTime] = InputTimeWindow(maxTimeWindow, Comment, defTimeWindow, timeUnit, rawTimeWindow) %#ok<DEFNU>
    % Initialize returned value
    isUpdatedTime = 0;
    % No expandable time window
    if (nargin < 5) || isempty(rawTimeWindow)
        rawTimeWindow = [];
    end
    % No time units: use the maximum time window to define it
    if (nargin < 4) || isempty(timeUnit)
        if (max(abs(maxTimeWindow)) > 2)
            timeUnit = 's';
        else
            timeUnit = 'ms';
        end
    end
    % No default time window: offer the whole time
    if (nargin < 3) || isempty(defTimeWindow)
        defTimeWindow = maxTimeWindow;
    end
    % Get time factor
    if strcmpi(timeUnit, 's')
        timeFactor = 1;
        strPrecision = '%1.4f';
    else
        timeFactor = 1000;
        strPrecision = '%1.2f';
    end
    % Ask until getting a valid time window
    validTime = 0;
    while(~validTime)
        % Display dialog to ask user time window for baseline
        res = java_dialog('input', {['Start (' timeUnit '):'], ['Stop (' timeUnit '):']}, Comment, ...
                          [], {num2str(defTimeWindow(1) * timeFactor, strPrecision), num2str(defTimeWindow(end) * timeFactor, strPrecision)});
        if isempty(res)
            TimeWindow = [];
            return
        end
        % Check values
        tStart = str2num(res{1}) ./ timeFactor;
        tStop = str2num(res{2}) ./ timeFactor;
        % If the requested selection is not available in the current page
        if isempty(tStart) || isempty(tStop) || (tStart >= tStop) || (tStart < maxTimeWindow(1)-1e-6) || (tStop > maxTimeWindow(end)+1e-6)
            % If the requested selection is available in the file: adjust current page
            if ~isempty(rawTimeWindow) && (tStart >= rawTimeWindow(1)-1e-6) && (tStop <= rawTimeWindow(end)+1e-6)
                timeLength = tStop - tStart;
                newWindow = [max(tStart - 0.1 * timeLength, rawTimeWindow(1)), ...
                             min(tStop  + 0.1 * timeLength, rawTimeWindow(end))];
                % Change time start AND duration
                if (timeLength > maxTimeWindow(end) - maxTimeWindow(1))
                    panel_record('SetStartTime', newWindow(1), [], 0);
                    panel_record('SetTimeLength', newWindow(2)-newWindow(1), 1);
                % Change time start only
                else
                    panel_record('SetStartTime', newWindow(1), [], 1);
                end
                validTime = 1;
                isUpdatedTime = 1;
            else
                java_dialog('warning', 'Invalid time window.');
            end
        else
            validTime = 1;
        end
    end
    % Apply units
    TimeWindow = [tStart tStop];
end


%% ===== GET TIME INDICES =====
function iTime = GetTimeIndices(TimeVector, TimeRange) %#ok<DEFNU>
    % If the two segments are not overlapping: empty time range
    if (TimeRange(2) < TimeVector(1)) || (TimeRange(1) > TimeVector(end)) || (TimeRange(1) > TimeRange(2)) || (length(TimeRange) ~= 2)
        iTime = [];
        return;
    end
    % Get closest indices for start and stop samples
    [distMin, iStart] = min(abs(TimeVector - TimeRange(1)));
    [distMax, iStop]  = min(abs(TimeVector - TimeRange(2)));
    % Return all the time samples between the two bounds
    iTime = iStart:iStop;
end


%% ===== GET RAW TIME =====
function TimeVector = GetRawTimeVector(sFile) %#ok<DEFNU>
    % Rebuild time vector
    if ~isempty(sFile.epochs)
        Samples = round([sFile.epochs(1).times(1), sFile.epochs(1).times(2)] .* sFile.prop.sfreq);
    else
        Samples = round([sFile.prop.times(1), sFile.prop.times(2)] .* sFile.prop.sfreq);
    end
    TimeVector = (Samples(1):Samples(2)) ./ sFile.prop.sfreq;
end


