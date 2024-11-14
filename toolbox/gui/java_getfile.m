function [ fileList, fileFormat, fileFilter ] = java_getfile( DialogType, WindowTitle, DefaultDir, SelectionMode, FilesOrDir, Filters, defaultFilter)
% JAVA_GETFILE: Java-based file selection for opening and saving.
%
% USAGE: [fileList, fileFormat, fileFilter] = java_getfile(DialogType,WindowTitle,DefaultDir,SelectionMode, FilesOrDir,Filters,defaultFilter)
%
% INPUT :
%    - DialogType    : {'open', 'save'}
%    - WindowTitle   : String
%    - DefaultDir    : To ignore, set to []
%    - SelectionMode : {'single', 'multiple'}
%    - FilesOrDir    : {'files', 'dirs', 'files_and_dirs'}
%    - Filters       : {NbFilters x 2} cell array
%                      Filters(i,:) = {{'.ext1', '.ext2', '_tag1'...}, Description}
%    - defaultFilter : can be 1) the index of the default file filter
%                             2) the name of the filer to be used
% OUTPUT:
%    - fileList      : Cell-array of strings, full paths to the files that were selected
%    - fileFormat    : String that represents the format of the files that were selected
%    - fileFilter    : File filter that was selected when selecting the files

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
% Authors: Francois Tadel, 2008-2014

import org.brainstorm.file.*;

global GlobalData FileSelectorStatus;

%% ===== CONFIGURE DIALOG =====
% Initialize returned variables
fileList   = {};
fileFormat = '';
fileFilter = [];

% DialogType
if strcmpi(DialogType, 'save')
    DialogType = BstFileSelector.TYPE_SAVE;
else
    DialogType = BstFileSelector.TYPE_OPEN;
end
% SelectionMode
if strcmpi(SelectionMode, 'multiple')
    SelectionMode = BstFileSelector.SELECTION_MULTIPLE;
else
    SelectionMode = BstFileSelector.SELECTION_SINGLE;
end
% Files and/or directories
switch lower(FilesOrDir)
    case 'dirs'
        FilesOrDir = BstFileSelector.DIRECTORIES_ONLY;
    case 'files_and_dirs'
        FilesOrDir = BstFileSelector.FILES_AND_DIRECTORIES;
    otherwise
        FilesOrDir = BstFileSelector.FILES_ONLY;
end
% Default folder: user folder
if isempty(DefaultDir)
    DefaultDir = bst_get('UserDir');
end

% Filters
iDefaultFileFilter = 1;
for i=1:size(Filters, 1)
    % Filters cell array has the following format:
    %   - One row per filter,
    %   - A filter row can be {{'extensions_list'}, 'Description', 'FormatName'}
    %                      or {{'extensions_list'}, 'Description'}
    if (size(Filters, 2) == 3)
        fileFilters(i) = java_create('org.brainstorm.file.BstFileFilter', '[Ljava.lang.String;Ljava.lang.String;Ljava.lang.String;', Filters{i,1}, Filters{i,2}, Filters{i,3});
    else
        fileFilters(i) = java_create('org.brainstorm.file.BstFileFilter', '[Ljava.lang.String;Ljava.lang.String;', Filters{i,1}, Filters{i,2});
    end
    % If it is default file filter
    if ~isempty(defaultFilter) && (isnumeric(defaultFilter) && (i == defaultFilter)) || ...
            (ischar(defaultFilter) && (size(Filters, 2) == 3) && strcmpi(Filters{i,3}, defaultFilter))
        iDefaultFileFilter = i; 
    end
end

% If a progress bar is displayed : hide it while displaying the file selector
pBar = GlobalData.Program.ProgressBar;
if ~isempty(pBar) && isfield(pBar, 'jWindow') && java_call(pBar.jWindow, 'isVisible')
    pBarHidden = 1;
    bst_progress('hide');
else
    pBarHidden = 0;
end


%% ===== HIDE MODAL WINDOWS =====
% Get brainstorm frame
jBstFrame = bst_get('BstFrame');
% If the frame is defined
if ~isempty(jBstFrame)
    jDialogModal = [];
    jDialogAlwaysOnTop = [];
    for i=1:length(GlobalData.Program.GUI.panels)
        panelContainer = get(GlobalData.Program.GUI.panels(i), 'container');
        panelContainer = panelContainer.handle{1};
        if isa(panelContainer, 'javax.swing.JDialog') && java_call(panelContainer, 'isModal')
            % A modal JDialog is found => Set it non non-modal
            jDialogModal = panelContainer;
            java_call(jDialogModal, 'setModal', 'Z', 0);
        end
        if (isa(panelContainer, 'javax.swing.JDialog') || isa(panelContainer, 'javax.swing.JFrame')) && java_call(panelContainer, 'isAlwaysOnTop')
            % An AlwaysOnTop frame is found => Remove always on top attribute
            jDialogAlwaysOnTop = panelContainer;
            java_call(jDialogAlwaysOnTop, 'setAlwaysOnTop', 'Z', 0);
        end
    end
end


%% ===== CREATE SELECTION DIALOG =====
% Initialize dialog status
FileSelectorStatus = 0;
% Create object
jBstSelector = java_create('org.brainstorm.file.BstFileSelector', 'ILjava.lang.String;Ljava.lang.String;II[Lorg.brainstorm.file.BstFileFilter;I', ...
                           DialogType, WindowTitle, DefaultDir, SelectionMode, FilesOrDir, fileFilters, iDefaultFileFilter - 1);
% Initialize a mutex (a figure that will be closed in the BstFileSelector close callback)
bst_mutex('create', 'FileSelector');
% Get JFileChooser dialog
jFileChooser = java_call(jBstSelector, 'getJFileChooser');
% Set dialog callback 
java_setcb(jFileChooser, 'ActionPerformedCallback', @FileSelectorAction, ...
                         'PropertyChangeCallback',  @FileSelectorPropertyChanged);
% Search for panel to add show/hide hidden menu
jObjects  = jFileChooser;
jFilePane = [];
while ~isempty(jObjects)
    switch class(jObjects(1))
        case 'sun.swing.FilePane'
            jFilePane = jObjects(1);
            break
        case {'javax.swing.JPanel', 'javax.swing.JFileChooser'}
            jObjects = [jObjects, jObjects(1).getComponents];
        otherwise
            % do nothing
    end
    jObjects = jObjects(2:end);
end
% Linux and Windows have a JFilePane object with a PopupMenu
if ~isempty(jFilePane)
    jPopup = jFilePane.getComponentPopupMenu;
    jFont  = jPopup.getFont;
% macOs does not have JFilePane object, add PopupMenu to jFileChooser
else
    jPopup = java_create('javax.swing.JPopupMenu');
    jFont  = [];
    jFileChooser.setComponentPopupMenu(jPopup);
end
jCheckHidden = gui_component('CheckBoxMenuItem', jPopup, [], 'Show hidden files', [], [], @(h,ev)ToogleHiddenFiles(), jFont);
showHiddenFiles = bst_get('ShowHiddenFiles');
jCheckHidden.setSelected(showHiddenFiles);
jFileChooser.setFileHidingEnabled(~showHiddenFiles);

drawnow;
% Display file selector
java_call(jBstSelector, 'showSameThread');
% MAGIC: Print something to the console output to get it to flush something, if not it crashes on MacOS 10.9.2
drawnow;
fprintf(1, ' \b');
% Wait for the file selector to be closed by the user
if ~isempty(bst_mutex('get', 'FileSelector'))
    bst_mutex('waitfor', 'FileSelector');
end


%% ===== PROCESS SELECTED FILES =====
% If user clicked OK after having selected a valid file
if FileSelectorStatus
    % Get file filter => file format
    fileFilter = java_call(jFileChooser, 'getFileFilter');
    fileFormat = char(java_call(fileFilter, 'getFormatName'));
    
    % If multiple selection
    if (SelectionMode == BstFileSelector.SELECTION_MULTIPLE)    
        % Get selected files
        fs = java_call(jFileChooser, 'getSelectedFiles');
        % Convert them to a cell array of filenames
        fileList = cell(length(fs), 1);
        for i=1:length(fs)
            fileList{i} = char(java_call(fs(i), 'getAbsolutePath'));
        end
    % Else: single selection
    else
        % Get selected file
        fileList = char(java_call(jFileChooser, 'getSelectedFile'));
        
        % If SAVE dialog
        if (DialogType == BstFileSelector.TYPE_SAVE)
            % Get required extension
            suffix = fileFilter.getSuffixes();
            suffix = char(suffix(1));
            % Replace current extension with required extension (ONLY IF SUFFIX IS EXTENSION)
            if (suffix(1) == '.') && ~isequal(suffix, '.folder')
                [selPath, selBase, selExt] = bst_fileparts(fileList);
                fileList = bst_fullfile(selPath, [selBase, suffix]);
            end
            
            % If file already exist
            if file_exist(fileList) && ~isequal(suffix, '.folder') && ~isdir(fileList)
                if ~java_dialog('confirm', sprintf('File already exist.\nDo you want to overwrite it?'), 'Save file')
                    fileList = [];
                    fileFormat = [];
                    fileFilter = [];
                end
            end
        end
    end
else
    fileList = [];
end

% Restore modal panels
if ~isempty(jBstFrame)
    if ~isempty(jDialogModal)
        java_call(jDialogModal, 'setModal', 'Z', 1);
    end
    if ~isempty(jDialogAlwaysOnTop)
        java_call(jDialogAlwaysOnTop, 'setAlwaysOnTop', 'Z', 1);
    end
end
% Restore progress bar
if pBarHidden
    bst_progress('show');
end



%% ===== CALLBACK FUNCTION =====
    function FileSelectorAction(h, ev)
        switch (char(java_call(ev, 'getActionCommand')))
            case 'ApproveSelection'
                FileSelectorStatus = 1;
            otherwise
                FileSelectorStatus = 0;
        end
        % Release mutex
        bst_mutex('release', 'FileSelector');
    end

    function FileSelectorPropertyChanged(h, ev)
        import org.brainstorm.file.*;
        % Release mutex if Dialog was closed
        propertyName = char(java_call(ev, 'getPropertyName'));
        if strcmpi(propertyName, 'JFileChooserDialogIsClosingProperty') && isempty(java_call(ev, 'getNewValue'))
            bst_mutex('release', 'FileSelector');
            return
        end
        % Only when saving 
        if (DialogType == BstFileSelector.TYPE_SAVE)
            switch char(java_call(ev, 'getPropertyName'))
                case 'fileFilterChanged'
                    % Get new filter
                    newFilter = java_call(ev, 'getNewValue');
                    % New suffix
                    newSuffix = java_call(newFilter, 'getSuffixes');
                    newSuffix = char(newSuffix(1));
                    if isequal(newSuffix, '.folder')
                        newSuffix = '';
                    end
                    % Get old filename 
                    selFile = java_call(jFileChooser, 'getSelectedFile');
                    if isempty(selFile)
                        oldFilename = DefaultDir;
                    else
                        jSelFile = java_call(jFileChooser, 'getSelectedFile');
                        oldFilename = char(java_call(jSelFile, 'getAbsolutePath'));
                    end

                    % Replace old extension by new one
                    [fPath, fBase, fExt] = bst_fileparts(oldFilename);
                    % Brainstorm or external file
                    if ~isempty(newSuffix) && (newSuffix(1) == '_')
                        fBase = strrep(fBase, ['_' newSuffix(2:end)], '');
                        fBase = strrep(fBase, [newSuffix(2:end) '_'], '');
                        fBase = [newSuffix(2:end) '_' fBase];
                        fExt  = '.mat';
                    else
                        fExt = newSuffix;
                    end
                    newFilename = bst_fullfile(fPath, [fBase, fExt]);
                    % Update default filename
                    java_call(jFileChooser, 'setSelectedFile', 'Ljava.io.File;', java_create('java.io.File', 'Ljava.lang.String;', newFilename));

                case 'directoryChanged'
                    DefaultDir = strrep(DefaultDir, char(java_call(ev, 'getOldValue')), char(java_call(ev, 'getNewValue')));
            end
        end
    end

    function ToogleHiddenFiles()
        showHiddenFiles = bst_get('ShowHiddenFiles');
        showHiddenFiles = ~showHiddenFiles;
        bst_set('ShowHiddenFiles', showHiddenFiles);
        jFileChooser.setFileHidingEnabled(~showHiddenFiles);
        jCheckHidden.setSelected(showHiddenFiles);
    end
end




    
