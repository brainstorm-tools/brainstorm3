function isUpdated = bst_update(AskConfirm)
% BST_UPDATE:  Download and install the latest version of Brainstorm.
%
% USAGE:  isUpdated = bst_update(AskConfirm)
%         isUpdated = bst_update()
%
% INPUT:
%    - AskConfirm: {0,1}, If 1, ask user confirmation before proceeding to update

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
% Authors: Francois Tadel, 2009-2019

% Java imports
import org.brainstorm.icon.*;
% Parse inputs
if (nargin == 0) || isempty(AskConfirm)
    AskConfirm = 0;
end
isUpdated = 0;

% === ASKING CONFIRMATION ===
if AskConfirm
    res = java_dialog('confirm', ['Download latest Brainstorm update ?' 10 10 ...
                                  'To turn off automatic updates, edit software preferences.' 10 10], 'Update');
    if ~res
        return
    end
end

% === DOWNLOAD NEW VERSION ===
% Get update zip file
urlUpdate  = 'http://neuroimage.usc.edu/bst/getupdate.php?c=UbsM09&src=1';
installDir = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
zipFile    = fullfile(installDir, 'brainstorm_update.zip');

% Check permissions
if ~file_attrib(installDir, 'w') || ~file_attrib(fullfile(installDir, 'brainstorm3'), 'w')
    strMsg = 'Error: Installation folder is read-only...';
    if ispc
        strMsg = [strMsg 10 10 ...
                  'On some Windows 7 or 8 computers, the user folders Documents and Downloads' 10 ...
                  'and the system folder C:\Programs\ are seen as read-only by Matlab.' 10 ...
                  'Try with admin privileges (right-click on Matlab > Run as Administrator)' 10 ...
                  'and if you still cannot update, move the brainstorm3 folder somewhere else.'];
    end
    disp(['BST> ' strrep(strMsg, char(10), [char(10) 'BST> '])]);
    if AskConfirm
        java_dialog('msgbox', [strMsg 10 10], 'Update');
    end
    return
end

% Download file
errMsg = gui_brainstorm('DownloadFile', urlUpdate, zipFile, 'Brainstorm update');
% If file was not downloaded correctly
if ~isempty(errMsg)
    disp('BST> Update: Unable to download updates.');
    disp(['BST>     ' strrep(errMsg, char(10), [10 'BST>     '])]);
    if AskConfirm
        java_dialog('msgbox', ['Could not download new packages:' 10 errMsg 10 10 ...
                               'Software was not updated.' 10 10], 'Update');
    end
    return
end

% === STOP BRAINSTORM ===
if isappdata(0, 'BrainstormRunning')
    bst_exit();
end

% === DELETE THE PREVIOUS INSTALLATION ===
% New progress bar
jProgressBar = javax.swing.JProgressBar();
jProgressBar.setIndeterminate(1);
jProgressBar.setStringPainted(0);
jLabel = javax.swing.JLabel('Installing new version...');
jPanel = gui_river();
jPanel.add('p hfill vfill', jLabel);
jPanel.add('p hfill', jProgressBar);
jDialog = javax.swing.JFrame('Brainstorm update');
jDialog.setAlwaysOnTop(1);
jDialog.setResizable(0);
jDialog.setPreferredSize(java.awt.Dimension(350, 130));
jDialog.setDefaultCloseOperation(javax.swing.JFrame.DISPOSE_ON_CLOSE);
jDialog.getContentPane().add(jPanel);
jDialog.pack();
jDialog.setLocationRelativeTo([]);
jDialog.setVisible(1);
jDialog.getContentPane().repaint();
jDialog.setIconImage(IconLoader.ICON_APP.getImage());
disp('BST> Update: Removing previous installation...');

% Go to zip folder (to make sure we are not in a folder we are deleting)
cd(installDir);
% Try the folders separately
warning('off', 'MATLAB:RMDIR:RemovedFromPath');
try
    rmdir(fullfile(installDir, 'brainstorm3', 'toolbox'), 's');
end
try
    rmdir(fullfile(installDir, 'brainstorm3', 'external'), 's');
end
try
    rmdir(fullfile(installDir, 'brainstorm3', 'bin'), 's');
end
try
    rmdir(fullfile(installDir, 'brainstorm3', 'defaults', 'anatomy', 'ICBM152'), 's');
end
try
    rmdir(fullfile(installDir, 'brainstorm3', 'defaults', 'eeg', 'ICBM152'), 's');
end
try
    rmdir(fullfile(installDir, 'brainstorm3', 'defaults', 'anatomy', 'Colin27'), 's');
end
try
    rmdir(fullfile(installDir, 'brainstorm3', 'defaults', 'eeg', 'Colin27'), 's');
end
try
    rmdir(fullfile(installDir, 'brainstorm3', 'defaults', 'anatomy', 'MNI_Colin27'), 's');
end
try
    rmdir(fullfile(installDir, 'brainstorm3', 'defaults', 'eeg', 'MNI_Colin27'), 's');
end
try
    rmdir(fullfile(installDir, 'brainstorm3', 'defaults', 'eeg', 'NotAligned'), 's');
end
warning('on', 'MATLAB:RMDIR:RemovedFromPath');

% === UNZIP FILE ===
disp('BST> Update: Unzipping...');
% Unzip update file
unzip(zipFile);
% Delete temporary update file
delete(zipFile);
% Add some folders to the path again
addpath(fullfile(installDir, 'brainstorm3', 'toolbox', 'misc'));
addpath(fullfile(installDir, 'brainstorm3', 'toolbox', 'core'));
addpath(fullfile(installDir, 'brainstorm3', 'toolbox', 'io'));
addpath(fullfile(installDir, 'brainstorm3', 'toolbox', 'gui'));

% === DISPLAY RELEASE NOTES ===
% Close waitbar
jDialog.setVisible(0);
jDialog.dispose();
% Display the latest updates
bst_mutex('create', 'ReleaseNotes');
jFrame = view_text(fullfile(installDir, 'brainstorm3', 'doc', 'updates.txt'), 'Release notes', 1);
java_setcb(jFrame, 'WindowClosingCallback', @CloseFigureCallback);
bst_mutex('waitfor', 'ReleaseNotes');


% === RESET ENVIRONMENT ===
% Clear everything in memory
warning('off', 'MATLAB:objectStillExists');
clear global
clear java
warning('on', 'MATLAB:objectStillExists');
% Get last warning
[warnTxt,warnId] = lastwarn();
% If not all objects were deleted: need matlab restart
% if strcmpi(warnId, 'MATLAB:objectStillExists')
%     disp('BST> Update: You need to restart Matlab before starting Brainstorm.');
%     isRestart = 1;
% else
%     isRestart = 0;
% end
isRestart = 1;
isUpdated = 1;
disp('BST> Update: Done.');


% === RESTART MATLAB/BRAINSTORM ===
if isRestart
    h = msgbox(['Brainstorm updated successfully.' 10 10 ...
                'Matlab will now be closed.' 10 ...
                'Restart Matlab and run brainstorm.m to finish installation.' 10 10], 'Update');
    waitfor(h);
    exit;
else
    % Start brainstorm again
    cd brainstorm3
    brainstorm
end

end


% === CALLBACK TO CLOSE RELEASE NOTES ===
function CloseFigureCallback(h,ev)
    bst_mutex('release', 'ReleaseNotes');
end





