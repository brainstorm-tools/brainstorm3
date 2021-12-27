function [TimeUnits, precision] = gui_validate_text(jTextValid, jTextMin, jTextMax, TimeVector, TimeUnits, precision, initValue, fcnCallback)
% GUI_VALIDATE_TEXT: Define the callbacks to make a JTextField work as a value selection device.
%
% INPUT:
%     - jTextValid     : Java pointer to a JTextField object
%     - jTextMin       : Value in jTextValid must be superior to value in jTextMin (set to [] to ignore)
%     - jTextMax       : Value in jTextValid must be inferior to value in jTextMax (set to [] to ignore)
%     - TimeVector     : Either a full time vector (matrix) or {start, stop, sfreq} (cell)
%     - TimeUnits      : Units used to represent the values: {'ms','s','scalar','list','optional'}; detected if not specified
%     - precision      : Number of digits to display after the point (0=integer); detected if not specified
%     - initValue      : Initial value of the control
%     - fcnCallback    : Callback that is executed after each validation of the jTextValid control

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
% Authors: Francois Tadel, 2009-2017


%% ===== PARSE INPUTS =====
% Compatibility check with previous versions:
if ~iscell(TimeVector) && (length(TimeVector) == 3) && (TimeVector(3) <= TimeVector(2))
    TimeVector = {TimeVector(1), TimeVector(2), TimeVector(3)};
end
% Time type: full vector or bounds + frequency
if iscell(TimeVector)
    if (length(TimeVector) ~= 3)
        error('When TimeVector is a cell, its length must be 3: {start, stop, sfreq}');
    end
    bounds = [TimeVector{1}, TimeVector{2}];
    sfreq  = TimeVector{3};
    TimeVector = [];
else
    if (length(TimeVector) < 2)
        error('When TimeVector is a matrix, its length must be >= 2');
    end
    bounds = [TimeVector(1), TimeVector(end)];
    sfreq = 1 ./ (TimeVector(2) - TimeVector(1)); 
end
% Detect units (s or ms)
if strcmpi(TimeUnits, 'time')
    if (max(abs(bounds)) > 2)
        TimeUnits = 's';
    else
        TimeUnits = 'ms';
    end
end
% Detect precision
if isempty(precision)
    % Duration of one time frame, in text length
    if strcmpi(TimeUnits, 'ms')
        dt = 1/sfreq * 1000;
    else
        dt = 1/sfreq;
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
% Initialize current value
currentValue = [];
% Set init value
if ~isempty(initValue)
    SetValue(jTextValid, initValue);
    TextValidation_Callback(0);
else
    jTextValid.setText('');
end
% Set validation callbacks
java_setcb(jTextValid, 'ActionPerformedCallback', @(h,ev)TextValidation_Callback(1), ...
                       'FocusLostCallback',       @(h,ev)TextValidation_Callback(1));

            
%% ===== VALIDATION FUNCTION =====
    function TextValidation_Callback(isCallback)
        % Get value that was entered by user in the text field
        newVal = GetValue(jTextValid);
        % Hzlist: do not accept 0Hz as an entry
        if ~isempty(newVal) && strcmpi(TimeUnits, 'Hzlist')
            newVal = setdiff(unique(newVal), 0);
            isChanged = 1;
        % List/optional: accept empty input
        elseif isempty(newVal) && ismember(TimeUnits, {'list','optional'})
            isChanged = 1;
        % If no valid value entered, use previous value
        elseif isempty(newVal) && isempty(currentValue)
            return
        elseif isempty(newVal) && ~isempty(currentValue)
            newVal = currentValue;
            isChanged = 0;
        elseif ~isempty(newVal) && isempty(currentValue)
            currentValue = newVal;
            isChanged = 1;
        else
            isChanged = ~isequal(currentValue, newVal);
        end
        % Look for the closest available value
        if ~isempty(TimeVector)
            [dist, iVal] = min(abs(TimeVector - newVal));
            newVal = TimeVector(iVal);
        else
            newVal = round(newVal * sfreq) / sfreq;
            newVal = bst_saturate(newVal, bounds);
            % Accept multiple values only for 'list'
            if ((length(newVal) >= 2) && ~strcmpi(TimeUnits, 'list'))
                newVal = newVal(1);
            end
        end
        % Get min and max values from other text fields
        if ~isempty(jTextMin)
            textMinVal = GetValue(jTextMin);
            if (newVal < textMinVal)
                %newVal = currentValue;
                SetValue(jTextMin, newVal);
            end
        end
        if ~isempty(jTextMax)
            textMaxVal = GetValue(jTextMax);
            if (newVal > textMaxVal)
                %newVal = currentValue;
                SetValue(jTextMax, newVal);
            end
        end
        % Update text field
        SetValue(jTextValid, newVal);
        % Save new value
        currentValue = newVal;
        % Call additional callback
        if ~isempty(fcnCallback) && isCallback && isChanged
            fcnCallback();
        end
    end


%% ===== GET VALUES =====
    function val = GetValue(jText)
        % Get and check value
        strVal = char(jText.getText());
        if isempty(strVal)
            val = [];
        else
            val = str2num(strVal);
            if isempty(val)
                val = [];
            % Convert back to ms
            elseif strcmpi(TimeUnits, 'ms')
                val = val / 1000; 
            end
        end
    end

%% ===== SET VALUES =====
    function SetValue(jText, val)
        strVal = panel_time('FormatValue', val, TimeUnits, precision);
        jText.setText(strVal);
    end

end

