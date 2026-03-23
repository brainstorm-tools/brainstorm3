function pBar = bst_progress(varargin)
% bst_progress: Manage the Brainstorm progress bar
%
% USAGE : pBar = bst_progress('start', title, msg, valStart, valStop) : Create a progress bar with start and stop bounds
%         pBar = bst_progress('start', title, msg)                    : Create a progress bar (unlimited)
%         pBar = bst_progress('stop')        : stop and hide progress bar
%         pBar = bst_progress('inc', valInc) : increment of 'valInc' the position of the progress bar
%         pBar = bst_progress('set', pos)    : set the position
%          pos = bst_progress('get')         : get the position
%         pBar = bst_progress('text', txt)   : set the text
%    isVisible = bst_progress('isvisible')   : return 1 if progress bar is visible, 0 else
%         pBar = bst_progress('show')        : display previously defined progress bar
%         pBar = bst_progress('hide')        : hide progress bar
%         pBar = bst_progress('setimage', imagefile) : display an image in the wait bar
%         pBar = bst_progress('setlink', url)        : clicking on the image opens a browser to display the url
%         pBar = bst_progress('removeimage')         : Remove the image from the wait bar
%         pBar = bst_progress('removelink')          : Remove click-on-image action
%   pBarParams = bst_progress('getbarparams')        : Get current bar parameters
%         pBar = bst_progress('setbarparams', pBarParams) : Set bar parameters
%         pBar = bst_progress('setpluginlogo', plugName/plugDesc) : display plugin logo with click-on image link

% NOTES : The window is created once, and then never deleted, just hidden.
%         Progress bar is represented by a structure: 
%            |- jWindow
%            |- jLabel
%            |- jProgressBar
%
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
% Authors: Francois Tadel, 2008-2013
%          Edouard Delaire, 2026

% JAVA imports
import org.brainstorm.icon.*;
import java.awt.Dimension;

global GlobalData;


%% ===== PARSE INPUTS =====
if ((nargin >= 1) && ischar(varargin{1}))
    commandName = varargin{1};
else
    error('Usage : bst_progress(commandName, parameters)');
end

% Do nothing in case of server mode
if ~isempty(GlobalData) && ~isempty(GlobalData.Program) && isfield(GlobalData.Program, 'GuiLevel') && (GlobalData.Program.GuiLevel == -1)
    if ismember(lower(commandName), {'pos','isvisible'})
        pBar = 0;
    else
        pBar = [];
    end
    return;
elseif isempty(GlobalData)
    GlobalData = db_template('globaldata');
end
% If running in NOGUI mode: just display the message in the command window
if ~bst_get('isGUI')
    switch lower(commandName)
        case 'start',     disp(['PROGRESS> ' varargin{2} ': ' varargin{3}]); pBar = [];
        case 'text',      disp(['PROGRESS> ' varargin{2}]); pBar = [];
        case 'get',       pBar = 1;
        case 'isvisible', pBar = 0;
    end
    return;
end

% Linux: need to print something on the command window (don't know why...)
if strcmpi(commandName, 'stop') && ismember(computer('arch'), {'glnx86', 'glnxa64'})
    drawnow();
    fprintf(' ');
    fprintf('\b');
    drawnow();
    % The dialog needs to be displayed for a short period before being hidden
    pause(0.05);
end

% Retrieve the progress bar
[caller_name, stacklist]     = getCallerName();
[pBar, ix]                   = getProgressBar(caller_name, stacklist);

% Get Brainstorm GUI context
jBstFrame   = bst_get('BstFrame');
if isempty(jBstFrame)
    jBstFrame = struct('setCursor', @(x)nan );
end
DefaultSize = java_scaled('dimension', 350, 130);

if isempty(pBar)  && ~strcmpi(commandName, 'start')
    % Restore cursor
    jBstFrame.setCursor([]);

    if ismember(lower(commandName), {'pos','isvisible'})
        pBar = 0;
    end
    return
end

%% ===== SWITCH BETWEEN COMMANDS =====
switch (lower(commandName))
    % ==== START ====
    case 'start'
        % Create a new progress bar
        ix = ix + 1;
        pBar = createProgressBar(DefaultSize, caller_name, ix);
        GlobalData.Program.ProgressBar{ix} = pBar;

        
        pBar = start(pBar, varargin{2:end});

    % ==== STOP ====
    case 'stop'
        % Restore cursor
        jBstFrame.setCursor([]);

        java_call(pBar.jWindow, 'dispose');
        GlobalData.Program.ProgressBar = GlobalData.Program.ProgressBar(1:end-1);
    % ==== INCREMENT ====
    case 'inc'
        % Parse arguments
        if ((nargin == 2) && isnumeric(varargin{2}))
            valInc = varargin{2};
        else
            error('Usage : bst_progress(''inc'', valInc)');
        end
        % Get current value
        minValue = GlobalData.Program.ProgressBar{ix}.Values.Minimum;
        maxValue = GlobalData.Program.ProgressBar{ix}.Values.Maximum;
        curValue = GlobalData.Program.ProgressBar{ix}.Values.Value;
        newVal = min(curValue + valInc + minValue, maxValue);
        % Plot the incremented progress if it moves at least 1% of the bar range
        if (abs(newVal - GlobalData.Program.ProgressBar{ix}.Values.LastVal) / (maxValue - minValue)) > 1/100
            % Get the incremented progress bar position
            pBar.jProgressBar.setValue(newVal);
            % Update value in GlobalData
            GlobalData.Program.ProgressBar{ix}.Values.LastVal = newVal;
        end
        GlobalData.Program.ProgressBar{ix}.Values.Value = newVal;

    % ==== SET POSITION ====
    case 'set'
        pBar = set (pBar, varargin{2:end});
        
    % ==== GET POSITION ====
    case 'get'
        % Get the incremented progress bar position
        pBar = GlobalData.Program.ProgressBar{ix}.Values.Value;
        
    % ==== SET TEXT ====
    case 'text'
        % Parse arguments
        if ((nargin == 2) && ischar(varargin{2}))
            % Set new label
            pBar.jLabel.setText(varargin{2});
        else
            % Get label
            pBar.jLabel.getText();
        end
        
    % ==== IS VISIBLE ====
    case 'isvisible'
        pBar = pBar.jWindow.isVisible();
    % ==== SHOW ====
    case 'show'
        % Set as "always on top"
        java_call(pBar.jWindow, 'setAlwaysOnTop', 'Z', 1);
        java_call(pBar.jWindow, 'setFocusable',   'Z', 0);
        java_call(pBar.jWindow, 'setFocusableWindowState', 'Z', 0);
        % Show window
        java_call(pBar.jWindow, 'setVisible', 'Z', 1);
        % Set watch cursor
        jBstFrame.setCursor(java_create('java.awt.Cursor', 'I', java.awt.Cursor.WAIT_CURSOR));
    
    % ==== HIDE ====
    case 'hide'
        % Remove the "always on top" status
        java_call(pBar.jWindow, 'setAlwaysOnTop', 'Z', 0);
        java_call(pBar.jWindow, 'setFocusable',   'Z', 1);
        java_call(pBar.jWindow, 'setFocusableWindowState', 'Z', 1);
        % Hide window
        java_call(pBar.jWindow, 'setVisible', 'Z', 0);
        % Restore cursor
        jBstFrame.setCursor([]);
        
    % ==== SET IMAGE ====
    case 'setimage'
        % Get image path
        imagefile = varargin{2};
        searchDirs = {'', bst_get('BrainstormDocDir'), bst_fullfile(bst_get('BrainstormDocDir'), 'plugins')};
        for iDir = 1 : length(searchDirs)
            tmp = bst_fullfile(searchDirs{iDir}, imagefile);
            if file_exist(tmp)
                imagefile = tmp;
                break
            end
        end
        if ~file_exist(imagefile)
            warning(['Image not found: ' imagefile]);
            return
        end
        % Image in label
        pBar.jImage.setIcon(javax.swing.ImageIcon(imagefile));
        GlobalData.Program.ProgressBar{ix}.isImage = 1;
        % Extend size of the frame
        UpdateConstraints(pBar, 1);
        pBar.jWindow.setPreferredSize([]);
        pBar.jWindow.pack();
        
    % ==== SET LINK ====
    case 'setlink'
        url = varargin{2};
        java_setcb(pBar.jImage, 'MouseClickedCallback', @(h,ev)web(url, '-browser'));
        
    % ==== REMOVE IMAGE ====
    case 'removeimage'
        % Remove image
        GlobalData.Program.ProgressBar{ix}.isImage = 0;
        pBar.jImage.setIcon([]);
        java_setcb(pBar.jImage, 'MouseClickedCallback', []);
        UpdateConstraints(pBar,0);
        pBar.jWindow.setPreferredSize(DefaultSize);
        pBar.jWindow.pack();

    % ==== REMOVE LINK ====
    case 'removelink'
        java_setcb(pBar.jImage, 'MouseClickedCallback', []);

    % ==== GET BAR PARAMETERS ====
    case 'getbarparams'
        % Get a copy of the bar parameters
        pBarParams.isImage = pBar.isImage;
        pBarParams.Title = pBar.jWindow.getTitle().toCharArray';
        pBarParams.Msg = pBar.jLabel.getText().toCharArray';
        pBarParams.isIndeterminate = pBar.jProgressBar.isIndeterminate();
        pBarParams.Value = GlobalData.Program.ProgressBar{ix}.Values.Value;
        pBarParams.Min = GlobalData.Program.ProgressBar{ix}.Values.Minimum; 
        pBarParams.Max = GlobalData.Program.ProgressBar{ix}.Values.Maximum;
        pBar = pBarParams;

    % ==== SET BAR PARAMETERS ====
    case 'setbarparams'
        % Parse arguments
        if (nargin == 2)
            pBarParams = varargin{2};
        else
            error('Usage : bst_progress(''setbarparams'', barParams)');
        end
        % (Re)start bar
        if pBarParams.isIndeterminate
            pBar = start(pBar, pBarParams.Title, pBarParams.Msg);
        else
            pBar = start(pBar, pBarParams.Title, pBarParams.Msg, pBarParams.Min, pBarParams.Max);
            pBar = set (pBar, pBarParams.Value);
        end

    % ==== SET PLUGIN LOGO ====
    case 'setpluginlogo'
        % PlugName/PlugDesc is required
        if (nargin < 2)
            return
        else
            % Get plugin descriptor
            PlugDesc = varargin{2};
            if ischar(PlugDesc)
                PlugDesc = bst_plugin('GetSupported', PlugDesc);
            end
            if isempty(PlugDesc)
                return
            end
        end
        % Get logo if not defined in the plugin structure
        if isempty(PlugDesc.LogoFile)
            PlugDesc.LogoFile = bst_plugin('GetLogoFile', PlugDesc);
        end
        % Start progress bar if needed
        if ~pBar.jWindow.isVisible()
            pBar = start(pBar,  ['Plugin: ' PlugDesc.Name], '');
        end
        % Set logo file
        if ~isempty(PlugDesc.LogoFile)
        % Image in label
            pBar.jImage.setIcon(javax.swing.ImageIcon(PlugDesc.LogoFile));
            GlobalData.Program.ProgressBar.isImage = 1;
            % Extend size of the frame
            UpdateConstraints(1);
            pBar.jWindow.setPreferredSize([]);
            pBar.jWindow.pack();
        end
        % Set link
        if ~isempty(PlugDesc.URLinfo)
            java_setcb(pBar.jImage, 'MouseClickedCallback', @(h,ev)web(PlugDesc.URLinfo, '-browser'));
        end

    otherwise
        error('Unknown command: %s', commandName);
end

 
%     %% ===== CLOSE CALLBACK =====
%     function CloseCallback()
%         % Hide progress bar
%         %java_call(pBar.jWindow, 'setVisible', 'Z', 0);
%         bst_progress('stop');
%         
%         if bst_iscompiled()
%             try 
%                 % Get command window
%                 cmdWindow = com.mathworks.mde.cmdwin.CmdWin.getInstance();
%                 cmdWindow.grabFocus();
%                 %2) Wait for focus transfer to complete (up to 2 seconds)
%                 focustransferTimer = tic;
%                 while ~cmdWindow.isFocusOwner
%                     pause(0.1);  %Pause some small interval
%                     if (toc(focustransferTimer) > 2)
%                         error('Error transferring focus for CTRL+C press.')
%                     end
%                 end
% 
%                 %3) Use Java robot to execute a CTRL+C in the (now focused) command window.
% 
%                 %3.1)  Setup a timer to relase CTRL + C in 0.3 second
%                 %  Try to reuse an existing timer if possible (this would be a holdover
%                 %  from a previous execution)
%                 t_all = timerfindall;
%                 releaseTimer = [];
%                 ix_timer = 1;
%                 while isempty(releaseTimer) && (ix_timer<= length(t_all))
%                     if isequal(t_all(ix_timer).TimerFcn, @releaseCtrl_C)
%                         releaseTimer = t_all(ix_timer);
%                     end
%                     ix_timer = ix_timer+1;
%                 end
%                 if isempty(releaseTimer)
%                     releaseTimer = timer;
%                     releaseTimer.TimerFcn = @(h,ev)releaseCtrl_C;
%                 end
%                 releaseTimer.StartDelay = 0.3;
%                 start(releaseTimer);
% 
%                 %3.2)  Press press CTRL+C
%                 pressCtrl_C();
%             catch
%                 disp('BST> Could not post a CTRL+C signal in the command window.');
%             end
%         end
%     end
% 
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     function pressCtrl_C()
%         SimKey = java.awt.Robot;
%         SimKey.keyPress(java.awt.event.KeyEvent.VK_CONTROL);
%         SimKey.keyPress(java.awt.event.KeyEvent.VK_C);
%     end
% 
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     function releaseCtrl_C()
%         SimKey = java.awt.Robot;
%         SimKey.keyRelease(java.awt.event.KeyEvent.VK_CONTROL);
%         SimKey.keyRelease(java.awt.event.KeyEvent.VK_C);
%         jBstFrame.setVisible(1);
%     end


function pBar = start(pBar, wndTitle, msg, valStart, valStop)
    % JAVA imports
    import org.brainstorm.icon.*;
    % Set as "always on top"
    java_call(pBar.jWindow, 'setAlwaysOnTop', 'Z', 1);
    java_call(pBar.jWindow, 'setFocusable',   'Z', 0);
    java_call(pBar.jWindow, 'setFocusableWindowState', 'Z', 0);
    % Call: bst_progress(''start'', title, msg)
    if (nargin == 3) && ischar(wndTitle) && ischar(msg)
        % Set Progress bar in inderminate mode
        pBar.jProgressBar.setIndeterminate(1);
        pBar.jProgressBar.setStringPainted(0);
        % Set progress bar bounds
        pBar.jProgressBar.setMinimum(0);
        pBar.jProgressBar.setMaximum(100);
        % Set initial value to start
        pBar.jProgressBar.setValue(0);
        % Update values in GlobalData
        GlobalData.Program.ProgressBar{end}.Values.Minimum = 0;
        GlobalData.Program.ProgressBar{end}.Values.Maximum = 100;
        GlobalData.Program.ProgressBar{end}.Values.Value   = 0;
        GlobalData.Program.ProgressBar{end}.Values.LastVal = 0;
        
    % Call: bst_progress(''start'', title, msg, start, stop)
    elseif ((nargin == 5) && ischar(wndTitle) && ischar(msg) && isnumeric(valStart) && isnumeric(valStop))
        % Set Progress bar in derminate mode
        pBar.jProgressBar.setIndeterminate(0);
        pBar.jProgressBar.setStringPainted(1);

        % Test bounds
        if ( (valStart >= valStop) || (valStop <= 0) )
            % Set indeterminate bounds
            pBar.jProgressBar.setIndeterminate(1);
            pBar.jProgressBar.setStringPainted(0);
            valStart = 0;
            valStop  = 100;
        end
        % Set progress bar bounds
        pBar.jProgressBar.setMinimum(valStart);
        pBar.jProgressBar.setMaximum(valStop);
        pBar.jProgressBar.setValue(valStart);
        % Update values in GlobalData
        GlobalData.Program.ProgressBar{end}.Values.Minimum = valStart;
        GlobalData.Program.ProgressBar{end}.Values.Maximum = valStop;
        GlobalData.Program.ProgressBar{end}.Values.Value   = valStart;
        GlobalData.Program.ProgressBar{end}.Values.LastVal = valStart;
    else
        error(['Usage : bst_progress(''start'', title, comment) ' 10 '        bst_progress(''start'', title, comment, valStart, valStop)']);
    end
    % Set window title
    pBar.jWindow.setTitle(wndTitle);
    % Set window comment (central label)
    pBar.jLabel.setText(msg);
    % Show window
    java_call(pBar.jWindow, 'setVisible', 'Z', 1);
    % Repaing window
    pBar.jWindow.getContentPane().repaint();
    % Set watch cursor
    jBstFrame.setCursor(java_create('java.awt.Cursor', 'I', java.awt.Cursor.WAIT_CURSOR));

end
    function [caller_name, stacklist] = getCallerName()
    
    % Get the name of the function that is calling bst_progress
        stacks        = dbstack(2);
        if isempty(stacks)
            stacks   = struct('name_file', 'cmd_windows'); 
        else
            % We find the first progress bar, that is a parent of the caller
            for i = 1:length(stacks)
                stacks(i).name_file = sprintf('%s/%s', stacks(i).file, stacks(i).name);
            end
        end
        caller_name   = stacks(1).name_file;
        stacklist     = {stacks.name_file};
    end

    function pBar = set (pBar, newVal)
        % Parse arguments
        if ~((nargin == 2) && isnumeric(varargin{2}))
            error('Usage : bst_progress(''set'', pos)');
        end

        % Get current value
        curValue = GlobalData.Program.ProgressBar{ix}.Values.Value;
        % Plot the position if it changes
        if (curValue ~= newVal)
            newVal = min(newVal, GlobalData.Program.ProgressBar{ix}.Values.Maximum);
            pBar.jProgressBar.setValue(newVal);
            % Update value in GlobalData
            GlobalData.Program.ProgressBar{ix}.Values.Value   = newVal;
            GlobalData.Program.ProgressBar{ix}.Values.LastVal = newVal;
        end
    end

    function [pBar, ix] = getProgressBar(caller_name, stacklist)
    
        pBar = [];
        ix = 0;
    
        if isempty(GlobalData) || isempty(GlobalData.Program.ProgressBar)
            return;
        end
    
        progress_list = cellfun(@(x) x.Values.Caller, GlobalData.Program.ProgressBar, 'UniformOutput',false);
        ix            = find(strcmp(progress_list, caller_name), 1, 'last');
        
        if isempty(ix)
            ix = find(cellfun(@(x) any(strcmp(stacklist,x)), progress_list),1,'last');
        
            if isempty(ix)
                ix = 0;
            end
        end
    
        % Close all progress bar that are not a parent of the caller
        for iBar = (ix+1):length(progress_list)
            java_call(GlobalData.Program.ProgressBar{iBar}.jWindow, 'dispose');
        end
        GlobalData.Program.ProgressBar = GlobalData.Program.ProgressBar(1:ix);
        
        if ~isempty(GlobalData.Program.ProgressBar)
            pBar = GlobalData.Program.ProgressBar{end};
        end
    end
    
    function pBar = createProgressBar(DefaultSize, caller_name, n_progress)
    
        % JAVA imports
        import org.brainstorm.icon.*;
        import java.awt.Dimension;
    
        % Create a JDialog, if possible dependent of the main Brainstorm JFrame
        pBar.jWindow = java_create('javax.swing.JDialog');
        % Set icon
        try
            pBar.jWindow.setIconImage(IconLoader.ICON_APP.getImage());
        catch
            % Old matlab... just ignore...
        end
        % Set as always-on-top / non-focusable
        pBar.jWindow.setAlwaysOnTop(1);
        pBar.jWindow.setFocusable(0);
        pBar.jWindow.setFocusableWindowState(0);
        % Non-modal
        pBar.jWindow.setModal(0);
        
        % Closing callback
    %     if bst_iscompiled()
            pBar.jWindow.setDefaultCloseOperation(pBar.jWindow.HIDE_ON_CLOSE);
    %     else
    %         pBar.jWindow.setDefaultCloseOperation(pBar.jWindow.DO_NOTHING_ON_CLOSE);
    %         java_setcb(pBar.jWindow, 'WindowClosingCallback', @(h,ev)CloseCallback);
    %     end
    
        % Configure window
        pBar.jWindow.setPreferredSize(DefaultSize);
        % Main panel
        pBar.jPanel = java_create('javax.swing.JPanel');
        pBar.jPanel.setLayout(java_create('java.awt.GridBagLayout'));
    
        % Create objects
        pBar.isImage = 0;
        pBar.jImage = java_create('javax.swing.JLabel');
        pBar.jLabel = java_create('javax.swing.JLabel', 'Ljava.lang.String;', '...');
        pBar.jLabel.setFont(bst_get('Font'));
        pBar.jProgressBar = java_create('javax.swing.JProgressBar', 'II', 0, 99);
        % Update constraints
        UpdateConstraints(pBar,0);
        
        % Add the main Panel
        pBar.jWindow.getContentPane.add(pBar.jPanel);
        pBar.jWindow.pack();
        % Set window size and location
        %pBar.jWindow.setLocationRelativeTo(pBar.jWindow.getParent());
    
        if isstruct(jBstFrame)
            pos = [0, 0];
        else
            jLoc = jBstFrame.getLocation();
            jSize = jBstFrame.getSize();
            pos = [jLoc.getX() + ((jSize.getWidth() - DefaultSize.getWidth()) / 2)  , ...
                   jLoc.getY() + ((jSize.getHeight() - DefaultSize.getHeight()) / 2)];
        end
        pos(1) = pos(1) + n_progress * (10+DefaultSize.getWidth());
        pBar.jWindow.setLocation(pos(1), pos(2));
        pBar.Values = struct('Minimum', [], 'Maximum', [], 'Value', [], 'LastVal', [], 'Caller', caller_name);   
    end
    
    %% ===== ADD COMPONENTS =====
    function UpdateConstraints(pBar, isImage)
        import java.awt.GridBagConstraints;
        import java.awt.Insets;
        % Remove all components
        pBar.jPanel.removeAll();
        % Generic constraints
        c = GridBagConstraints();
        c.fill = GridBagConstraints.BOTH;
        c.gridx = 1;
        c.weightx = 1;
        % IMAGE
        c.gridy = 1;
        c.weighty = isImage;
        c.insets = Insets(0,0,0,0);
        pBar.jPanel.add(pBar.jImage, c);
        % TEXT
        c.gridy = 2;
        c.weighty = ~isImage;
        c.insets = Insets(5,12,5,12);
        pBar.jPanel.add(pBar.jLabel, c);
        % PROGRESS BAR
        c.gridy = 3;
        c.weighty = 0;
        c.insets = Insets(0,12,9,12);
        pBar.jPanel.add(pBar.jProgressBar, c);
    %         % CANCEL BUTTON
    %         c.gridy = 4;
    %         c.weighty = 0;
    %         c.insets = Insets(0,12,9,12);
    %         c.weightx = 0;
    %         pBar.jPanel.add(pBar.jButtonCancel, c);
    end
end