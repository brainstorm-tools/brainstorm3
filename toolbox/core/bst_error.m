function fullErrMsg = bst_error(errMsg, errTitle, isStack)
% BST_ERROR: Process an error (Display error message, and send a bug report)
%
% Usage : bst_error()                          : Display lasterror
%         bst_error(errMsg, errTitle, isStack) : Report an error
%         bst_error(errMsg, errTitle)          : Report an error (stack is displayed)
%         bst_error(errMsg)                    : Report an error (errTitle is the name of the calling script)     
%         fullErrMsg = bst_error(...)          : Do not display anything, just return the full error message

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2015

global GlobalData;

% Display lasterror
if (nargin == 0)
    e = lasterror;
    % If no error available: create an empty error
    if isempty(e)
        try
            error('Brainstorm:NoError', 'NoError');
        catch
        end
        e = lasterror;
    end
    % Catch OUT OF MEMORY errors
    if strcmpi(e.identifier, 'MATLAB:nomem')
        errStack = e.stack;
        errMsg   = ['Out of memory. ' 10 10 'Please unload some datasets (or restart Matlab) an try again.'];
        errTitle = '';
        isStack  = 1;
    % Get lasterror stack and error message
    else
        % If error stack is empty, use current call stack
        if isempty(e.stack)
            % Get current stack trace
            errStack = dbstack();
            % Remove call to bst_error() from stack
            errStack(1) = [];
        else
            errStack = e.stack;
        end
        errMsg   = e.message;
        errTitle = '';
        isStack  = 1;
        % Remove HTML tags
        errMsg = str_striptag(errMsg);
        % Remove "Error using"
        errMsg = strrep(errMsg, 'Error using ==>', '');
        errMsg = strrep(errMsg, 'Error using', '');
    end
% Else : display bst_error line
else
    % Get current stack trace
    errStack = dbstack();
    % Remove call to bst_error() from stack
    errStack(1) = [];
    % Get error title if not defined
    if (nargin < 2)
        errTitle = '';
    end
    % If isStack not defined : set default to 1
    if (nargin < 3)
        isStack = 1;
    end
end

if isempty(errStack)
    return
end

% Set default default title
if isempty(errTitle)
    [tmp__, errFile] = fileparts(errStack(1).file);
    errTitle = ['Error in ' errFile '.m'];
end

% Print line number
strLine = [];
if isStack
    strLine = sprintf('Line %d: ', errStack(1).line);
end
% Print stack trace
strStack = [];
if isStack
    % For each stack level
    for i = 1:length(errStack)
        % Get filename 
        [tmp__, errFile] = fileparts(errStack(i).file);
        errFile = [errFile, '.m']; %#ok<AGROW>
        % If s.name = s.file : do not display name
        if strcmpi(errFile, [errStack(i).name '.m'])
            strStack = sprintf('%s>%s at %d\n', strStack, errFile, errStack(i).line);
        else
            strStack = sprintf('%s>%s>%s at %d\n', strStack, errFile, errStack(i).name, errStack(i).line);
        end
    end
    strStack = sprintf('\n_______________________________________________\nCall stack:\n%s_______________________________________________\n', strStack);
end

% Full dialog error message
fullErrMsg = sprintf('%s%s\n%s', strLine, errMsg, strStack);
% Full console error message
consoleMsg = strrep(fullErrMsg(1:end-1), '_______________________________________________', '');
consoleMsg = strrep(consoleMsg, char([10 10]), char(10));
consoleMsg = strrep(consoleMsg, char(10), [10 '** ']);
consoleMsg = [10 '***************************************************************************' 10 ...
              '** Error: ' consoleMsg ...
              10 '***************************************************************************' 10];

% If no text output: display messages
if (nargout == 0)
    % Do not display java dialog in case of server mode
    if isempty(GlobalData) || ~isfield(GlobalData, 'Program') || ~isfield(GlobalData.Program, 'GuiLevel') || (GlobalData.Program.GuiLevel >= 0)
        % Hide progress bar
        bst_progress('stop');
        % Display error message window
        java_dialog('errorhelp', fullErrMsg, errTitle);
    end
    % Display error message in Matlab console
    disp(consoleMsg);
    % Close all the open files
    fclose all;
end

% %% ===== SENDING BUG REPORT =====
% % Send email only if error is not a known error (arguments are given to the function)
% if (nargin == 0)
%     % Send bug report (if configuration is ok...)
%     panel_bug('SendBugReport', consoleMsg);
% end

% Close all files
%fclose('all');


        
