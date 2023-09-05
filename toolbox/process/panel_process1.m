function varargout = panel_process1(varargin)
% PANEL_PROCESS1: Creation and management of list of files to apply some batch proccess.
%
% USAGE:  bstPanelNew = panel_process1('CreatePanel')

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
% Authors: Francois Tadel, 2010-2015

eval(macro_method);
end

%% ===== CREATE PANEL ===== 
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'Process1';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % Create list of nodes
    nodelist = panel_nodelist('CreatePanel', 'Process1', 'Files to process', 'tree');
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           nodelist.jPanel, ...
                           struct('nodelist', nodelist));
end

%% =========================================================================
%  ===== PROCESSING FUNCTIONS ==============================================
%  =========================================================================
%% ===== RUN PROCESS =====
function sOutputs = RunProcess(varargin) %#ok<DEFNU>
    global GlobalData;
    nodelistName = 'Process1';
    % Get files
    sFiles = panel_nodelist('GetFiles', nodelistName);
    if isequal(sFiles, -1)
        return;
    end
    % If nothing in the list: create a pseudo-file "import"
    if isempty(sFiles)
        sFiles = db_template('importfile');
    end
    % Warning for read-only
    if bst_get('ReadOnly')
        java_dialog('warning', ['The protocol is opened in read-only mode.' 10 ...
                                'All the processes will crash because they cannot save the results.' 10], ...
                                'Read-only');
    end
    % For recordings: check for mixed raw/imported files
    if ~isempty(sFiles) && any(strcmpi({sFiles.FileType}, 'data')) && any(strcmpi({sFiles.FileType}, 'raw'))
        bst_error('Cannot process imported data and raw recordings at the same time.', 'Process', 0);
        return;
    end
    % If pipeline editor is already open: close it and open it again
    bstPanel1 = bst_get('Panel', 'ProcessOne');
    if ~isempty(bstPanel1)
        disp('BST> Pipeline editor is already open: closing it...');
        gui_hide(bstPanel1);
    end
    bstPanel2 = bst_get('Panel', 'ProcessTwo');
    if ~isempty(bstPanel2)
        disp('BST> Pipeline editor is already open: closing it...');
        gui_hide(bstPanel2);
    end
    
    % If running a process on a raw file that is currently opened: close the raw viewer
    [iDS, isRaw] = panel_record('GetCurrentDataset');
    if ~isempty(iDS) && any(file_compare(GlobalData.DataSet(iDS).DataFile, {sFiles.FileName}))
        if isRaw
            strWarningRaw = [...
             'For immediate interactivity, you can run event detections' 10 ...
             'and SSP computations from the SSP menu in the Event tab.' 10 10];
        else
            strWarningRaw = '';
        end
        % Warning message
        isClose = java_dialog('confirm', ...
            ['Warning: One of the files you selected is currently opened,' 10 ...
             'the viewer has to be closed to start processing this file.' 10 10 ...
             strWarningRaw ...
             'Close the file viewer now?'], 'Close file viewer');
        % Not closing: cancel process selection
        if ~isClose
            return;
        end
        % Close viewer
        bst_memory('UnloadAll', 'Forced');
        % Check that the raw viewer was closed (that user didn't cancel)
        iDS = panel_record('GetCurrentDataset');
        if ~isempty(iDS)
            return;
        end
    end
    
    % Disable all the controls in the lists
    panel_nodelist('SetListEnabled', 0);
    % Get process to apply
    sProcesses = gui_show_dialog('Pipeline editor', @panel_process_select, 0, [50 100], sFiles);
    % Enables the controls again
    panel_nodelist('SetListEnabled', 1);
    % No selected processes: nothing to do
    if isempty(sProcesses)
        return
    end   
    % Timefreq and Connectivity: make sure the advanced options were reviewed
    for iProc = 1 : length(sProcesses)
        procFunc = func2str(sProcesses(iProc).Function);
        if (ismember(procFunc, {'process_timefreq', 'process_hilbert', 'process_psd'}) && ...
                                (~isfield(sProcesses(iProc).options.edit, 'Value') || isempty(sProcesses(iProc).options.edit.Value))) || ... % check 'edit' field
           (ismember(procFunc, {'process_henv1', 'process_henv1n', 'process_henv2', ...
                               'process_cohere1', 'process_cohere1n', 'process_cohere2', ...
                               'process_plv1', 'process_plv1n', 'process_plv2'}) && ...
                                (~isfield(sProcesses(iProc).options.tfedit, 'Value') || isempty(sProcesses(iProc).options.tfedit.Value)))    % check 'tfedit' field
            bst_error(['Please check the advanced options of the process "', sProcesses(iProc).Comment, '" before running the pipeline.'], 'Pipeline editor', 0);
            panel_process_select('ShowPanel', {sFiles.FileName}, sProcesses);
            return
        end
    end

    % Call process function
    sOutputs = bst_process('Run', sProcesses, sFiles, [], 1);
    
    % Update files list
    bst_progress('start', 'File selection', 'Updating file count...');
    %panel_nodelist('UpdatePanel', {'Process1'}, 1, 0);
    panel_nodelist('CheckContents', 'Process1');
    bst_progress('stop');
end




  


