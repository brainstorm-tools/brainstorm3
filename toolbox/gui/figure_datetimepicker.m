function dt = figure_datetimepicker(initialValue)
%figure_datetimepicker  Open a small GUI to select a date and time.
%
%   DT = figure_datetimepicker() opens a dialog allowing the user to pick a date,
%   hour, and minute. The function returns a datetime object if the user
%   presses OK, or an empty array [] if the user cancels or closes the
%   window.
%
%   DT = figure_datetimepicker(INITIALVALUE) initializes the GUI with a previously
%   selected date/time. INITIALVALUE may be:
%       - a datetime object
%       - a char or string in the format 'YYYY/MM/DD HH:mm'
%       - empty [] (equivalent to calling with no input)
%
%   Example:
%       dt = figure_datetimepicker('2025/03/10 14:20');
%       dt = figure_datetimepicker(datetime(2024,12,25,8,30,0));
%       dt = figure_datetimepicker([]);
%
%   The function uses:
%       - uidatepicker for selecting the date
%       - uispinner for selecting hour and minute
%
%   Closing the dialog via Cancel or the window's red X returns [].
%

    % ------------------------------------------
    % Parse input
    % ------------------------------------------
    if nargin == 0 || isempty(initialValue)
        base = datetime('now');
    elseif isa(initialValue, 'datetime')
        base = initialValue;
    else
        try
            base = parseInitialDate(initialValue);
        catch
            error('Input string must be in format YYYY/MM/DD HH:mm');
        end
    end

    
    % Default return value
    dt = [];

    % Create dialog
    d = uifigure('Position',[100 100 260 200], ...
                'Name','Select Date & Time', ...
                'CloseRequestFcn', @onClose);

    % Date picker
    if ( bst_get('MatlabVersion') >= 907) % Matlab 2019b
        uilabel(d,'Position',[20 150 60 20],'Text','Date:');
        dp = uidatepicker(d,'Position',[80 150 150 22], 'Value', base);
        dp.DisplayFormat = 'dd/MM/yyyy';
    else
        
        uilabel(d,'Position',[20 150 60 20],'Text','Date:');
        dp = uitextarea(d,...
                    'Value', {datestr(base, 'yyyy/mm/dd')}, ...
                    'Position',[80 150 150 22]);
    end

    %% Checkbox: Specify time?
    cb = uicheckbox(d, 'Text','Specify time', ...
        'Position',[20 125 120 20], ...
        'Value', true, ...
        'ValueChangedFcn', @(src,event) onToggleTime());

    %% Time entry text field
    labelTime = uilabel(d,'Position',[20 95 60 20],'Text','Time:');
    tfTime = uitextarea(d, ...
        'Position',[80 95 120 25], ...
        'Value',{datestr(base,'HH:MM:SS')}, ...
        'Editable','on');


    % OK button
    uibutton(d,'Position',[30 20 80 30],'Text','OK', ...
        'ButtonPushedFcn', @(btn,event) onOK());
    
    % Cancel button
    uibutton(d,'Position',[150 20 80 30],'Text','Cancel', ...
        'ButtonPushedFcn', @(btn,event) onCancel());

    drawnow
    % Wait for user choice
    uiwait(d);

    % --- Nested callback: OK pressed ---
    function onOK()
        if isa(dp, 'matlab.ui.control.TextArea')
            selectedDate = parseInitialDate(dp.Value{1});
        else
            selectedDate = dp.Value;
        end
        % If user wants to specify the time:
        if cb.Value
            timestr = strtrim(tfTime.Value{1});

            % Try parsing HH:mm or HH:mm:ss formats
            timeParsed = parseTime(timestr);
            if isempty(timeParsed)
                uialert(d,'Invalid time format. Use HH:mm or HH:mm:ss','Time Error');                
                return;
            end

            dt = datetime(selectedDate.Year, selectedDate.Month, selectedDate.Day, hour(timeParsed), minute(timeParsed), second(timeParsed));            
        else
            dt = datetime(selectedDate.Year, selectedDate.Month, selectedDate.Day);
        end

        uiresume(d);  % wake up uiwait immediately
        delete(d);
    end

    function dt = parseInitialDate(str)
        %PARSEINITIALDATE Parse initial date strings for figure_datetimepicker.
        %
        %   DT = parseInitialDate(STR)
        %       STR may be in one of the following formats:
        %           'yyyy/MM/dd'
        %           'yyyy/MM/dd HH:mm'
        %           'yyyy/MM/dd HH:mm:ss'
        %
        %   Returns a datetime object.
        %   Throws an error if the format does not match.

        if ~ischar(str) && ~isstring(str)
            error('Input must be a char or string.');
        end
    
        str = char(str);
    
        % ---- Pattern 1: yyyy/MM/dd (DATE ONLY) ----
        pat_date_only = '^(\d{4})/(\d{2})/(\d{2})$';
    
        % ---- Pattern 2: yyyy/MM/dd HH:mm or HH:mm:ss ----
        pat_date_time = '^(\d{4})/(\d{2})/(\d{2})\s+([01]\d|2[0-3]):([0-5]\d)(:([0-5]\d))?$';
    
        % Try date only
        tok = regexp(str, pat_date_only, 'tokens', 'once');
        if ~isempty(tok)
            yyyy = str2double(tok{1});
            MM   = str2double(tok{2});
            dd   = str2double(tok{3});
            dt   = datetime(yyyy, MM, dd, 0, 0, 0);   % default to midnight
            return;
        end
    
        % Try date + time
        tok = regexp(str, pat_date_time, 'tokens', 'once');
        if isempty(tok)
            error(['Invalid format. Expected one of:' newline ...
                   '  yyyy/MM/dd' newline ...
                   '  yyyy/MM/dd HH:mm' newline ...
                   '  yyyy/MM/dd HH:mm:ss']);
        end

        yyyy = str2double(tok{1});
        MM   = str2double(tok{2});
        dd   = str2double(tok{3});
        HH   = str2double(tok{4});
        mm   = str2double(tok{5});
    
        % Nested seconds group → only appears in tok{7}
        if numel(tok) >= 6 && ~isempty(tok{6})
            ss = str2double(tok{6}(2:end));
        else
            ss = 0;
        end
    
        dt = datetime(yyyy, MM, dd, HH, mm, ss);
    end


    function timeParsed = parseTime(timestr)

        % Accept HH:mm or HH:mm:ss using regex
        timePattern = '^([01]\d|2[0-3]):([0-5]\d)(:([0-5]\d))?$';
        tokens = regexp(timestr, timePattern, 'tokens', 'once');
        
        if isempty(tokens)
            timeParsed = [];
            return;
        end
        
        hour   = str2double(tokens{1});
        minute = str2double(tokens{2});
        
        if length(tokens) == 3 && ~isempty(tokens{3})
            second = str2double(tokens{3}(2:end));
        else
            second = 0;
        end
        
        timeParsed = datetime([0, 0, 0, hour, minute, second]);

    end

    function onToggleTime()
        tfTime.Enable = cb.Value();
        labelTime.Enable = cb.Value();
    end

    function onCancel()
        close(d);
    end

    function onClose(~,~)
        % Handles clicking the red X
        dt = [];
        uiresume(d);  % wake up uiwait immediately
        delete(d);
    end
end