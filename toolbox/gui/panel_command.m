function varargout = panel_command(varargin)
% PANEL_COMMAND: Create a panel to execute matlab code in the base workspace.
% 
% USAGE:  bstPanelNew = panel_command('CreatePanel')

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
% Authors: Francois Tadel, 2013-2019

eval(macro_method);
end


%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'Command';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % Create tools panel
    jPanelNew = gui_component('Panel');
    jPanelNew.setPreferredSize(java_scaled('dimension', 400, 300));
    
    % Text editor
    jText = JTextArea(6, 12);
    jText.setFont(Font('Monospaced', Font.PLAIN, 11));
    jScroll = JScrollPane(jText);
    jPanelNew.add(jScroll, BorderLayout.CENTER);
    
    % Confirmation buttons
    jPanelBottom = gui_river();   
    gui_component('Button', jPanelBottom, 'br right', 'Execute', [], [], @ButtonRun_Callback, []);
    gui_component('Button', jPanelBottom, [],         'Close',   [], [], @ButtonClose_Callback,   []);
    jPanelNew.add(jPanelBottom, BorderLayout.SOUTH);
           
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jText', jText));

                       
                       
%% =================================================================================
%  === CONTROLS CALLBACKS  =========================================================
%  =================================================================================               
%% ===== SAVE OPTIONS =====
    function ButtonRun_Callback(varargin)
        try
            evalin('base', char(jText.getText()));
        catch
            disp('BST> Error executing command:');
            disp(lasterr);
        end
    end

%% ===== CANCEL BUTTON =====
    function ButtonClose_Callback(varargin)
        % Hide panel
        gui_hide(panelName);
    end
    
end


%% =================================================================================
%  === EXTERNAL CALLBACKS  =========================================================
%  =================================================================================  
function ExecuteScript(ScriptFile, varargin) %#ok<DEFNU>
    % Select file to execute
    if (nargin < 1) || isempty(ScriptFile)
        ScriptFile = java_getfile('open', 'Select Brainstorm script', '', 'single', 'files', ...
            {{'.m'}, 'Brainstorm script (*.m)', 'M-FILE'}, 1);
        if isempty(ScriptFile)
            return;
        end
    end
    % Check file existance
    if ~file_exist(ScriptFile)
        error(['File does not exist: ' ScriptFile]);
    end
    % Open file
    fid = fopen(ScriptFile, 'rt');
    if (fid < 0)
        error(['Could not open script file: ' ScriptFile]);
    end
    % Read file as text
    txtScript = fread(fid, [1, Inf], '*char');
    % Close file
    fclose(fid);
    % Split in lines
    cellLines = str_split(txtScript, [10 13]);
    % Analyze the script line by line
    iDelete = [];
    nLines = 0;
    isConverted = 0;
    for i = 1:length(cellLines)
        % Remove spaces
        cellLines{i} = strtrim(cellLines{i});
        % Remove empty lines and comments
        if isempty(cellLines{i}) || (cellLines{i}(1) == '%')
            iDelete(end+1) = i;
            continue;
        end
        % Detect if script contains function
        if (length(cellLines{i}) >= 8) && strcmp(cellLines{i}(1:8), 'function')
            % If all the file is a function, try to convert to a script
            if (nLines == 0)
                disp('WARNING: This file is a function, trying to convert to a script...');
                % Get opening and closing parenthesis
                iParent1 = find(cellLines{i} == '(');
                iParent2 = find(cellLines{i} == ')');
                if ((length(iParent1) ~= 1) || (length(iParent2) ~= 1))
                    error('Function declaration has multiple or no parenthesis. Don''t know what to do...');
                end
                % Get list of arguments
                argList = cellLines{i}(iParent1+1:iParent2-1);
                argList(argList == ' ') = [];
                % No arguments: simply remove the function declaration
                if isempty(argList)
                    iDelete(end+1) = i;
                % Replace arguments with inputs
                else
                    argNames = str_split(cellLines{i}(iParent1+1:iParent2-1), ',');
                    % Number of arguments must match the number of inputs
                    if (length(argNames) ~= length(varargin))
                        error('The number of argmuents in the function does not match the number of parameters passed in the command line.');
                    end
                    % Set the arguments variables
                    strSetArg = '';
                    for iArg = 1:length(argNames)
                        if ~ischar(varargin{iArg})
                            error('All arguments passed in command line must be strings.');
                        end
                        strSetArg = [strSetArg, argNames{iArg}, '=''', varargin{iArg}, ''';'];
                    end
                    cellLines{i} = strSetArg;
                end
                isConverted = 1;
            else
                error('Cannot execute functions: Rewrite your code as a script without subfunctions.');
            end
        end
        nLines = nLines + 1;
    end
    % Delete lines
    cellLines(iDelete) = [];
    % Concatenate lines again
    txtScript = sprintf('%s\n', cellLines{:});
    % Evaluate script
    try
        eval(txtScript);
    catch
        iEnd = find(cellfun(@(c)(strcmp(c,'end') || strcmp(c,'end;')), cellLines));
        % If the code was a function converted to a script, try to remove the last "end" statement
        if isConverted && ~isempty(iEnd)
            disp('WARNING: First execution attempt failed, try removing the last "end" statement.');
            try
                % Remove the last "end" statement
                cellLines(iEnd(end)) = [];
                txtScript = sprintf('%s\n', cellLines{:});
                % Try evaluating again
                eval(txtScript);
            catch
                error(['Error while executing script: ' 10 lasterr]);
            end
        else
            error(['Error while executing script: ' 10 lasterr]);
        end
    end
end



