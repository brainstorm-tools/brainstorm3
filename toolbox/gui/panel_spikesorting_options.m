function varargout = panel_spikesorting_options(varargin)
% PANEL_SPIKESORTING_OPTIONS: Options for spike sorting computation.
% 
% USAGE:  bstPanelNew = panel_spikesorting_options('CreatePanel')
%                   s = panel_spikesorting_options('GetPanelContents')

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
% Authors: Martin Cousineau, 2018
%          Francois Tadel, 2022

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(sProcess, sFiles)  %#ok<DEFNU>  
    panelName = 'SpikesortingOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % No input
    if isempty(sFiles) || strcmpi(sFiles(1).FileType, 'import')
        bstPanelNew = [];
        panelName = [];
        return;
    end
    % Check chosen spike sorter
    spikeSorter = sProcess.options.spikesorter.Value;
    
    % Create main panel
    jPanelNew = gui_component('panel');
    % Create edit box
    jTextOptions = java_create('javax.swing.JTextArea', 'Ljava.lang.String;', 'Loading...');
    jTextOptions.setBackground(Color(1,1,1));
    jTextOptions.setMargin(java_create('java.awt.Insets', 'IIII', 10,25,10,25));
    jTextOptions.setFont(bst_get('Font', 12, 'Courier New'));
    jPanelNew.add(JScrollPane(jTextOptions));
    % Validation button
    gui_component('button', jPanelNew, BorderLayout.SOUTH, 'Save options', [], [], @ButtonOk_Callback);

    % Set maximum panel size
    maxSize = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment.getMaximumWindowBounds();
    jPanelNew.setPreferredSize(java.awt.Dimension(700, maxSize.getHeight() - 200));

    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Controls list
    ctrl = struct('jTextOptions', jTextOptions, ...
                  'spikeSorter',  spikeSorter);
    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);
    
    % Load options file into the panel
    UpdatePanel();
    

%% =================================================================================
%  === INTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== OK BUTTON =====
    function ButtonOk_Callback(varargin)
        [optionFile, skipLines, skipValidate] = GetSpikeSorterOptionFile(spikeSorter);
        textOptions = char(jTextOptions.getText());
        
        % Validate
        if skipValidate || ValidateOptions(textOptions)
            % Load header if applicable
            if skipLines > 0
                fid = fopen(optionFile,'rt');
                idx = 1;
                while ~feof(fid) && idx <= skipLines
                    line = fgetl(fid);
                    header{idx,1} = line;
                    idx = idx + 1;
                end
                fclose(fid);
                header = [char(join(header, char(10))), char(10)];
            else
                header = '';
            end
            
            % Write to file
            fid = fopen(optionFile,'w');
            fwrite(fid, header);
            fwrite(fid, textOptions);
            fclose(fid);
        
            % Release mutex and keep the panel opened
            bst_mutex('release', panelName);
        end
    end


%% ===== UPDATE PANEL =====
    function UpdatePanel(varargin)
        % Get option file
        [optionFile, skipLines] = GetSpikeSorterOptionFile(spikeSorter);
        % Options file is not found
        if exist(optionFile, 'file') ~= 2
            java_dialog('error', 'Could not find spike-sorter''s parameters file.');
            bstPanelNew = [];
            bst_mutex('release', panelName);
            return;
        end
        % Read options file
        fid = fopen(optionFile,'rt');
        idx = 1;
        optionText = {};
        while ~feof(fid)
            line = fgetl(fid);
            if skipLines > 0
                skipLines = skipLines - 1;
            else
                optionText{idx,1} = line;
                idx = idx + 1;
            end
        end
        fclose(fid);
        % Set as panel contents
        jTextOptions.setText(char(join(optionText, char(10))));
    end
end


%% ===== GET OPTIONS FILE =====
function [optionFile, skipLines, skipValidate] = GetSpikeSorterOptionFile(spikeSorter)
    skipLines = 0;
    skipValidate = 0;
    optionFile = [];

    % Get plugin
    PlugDesc = bst_plugin('GetInstalled', spikeSorter);
    % Install plugin if not available
    if isempty(PlugDesc)
        [isInstalled, errMsg, PlugDesc] = bst_plugin('Install', spikeSorter, 1);
        if ~isInstalled
            error(errMsg);
        end
    end

    % Get default options file for each spike sorting application
    switch lower(spikeSorter)
        case 'waveclus'
            optionFile = bst_fullfile(PlugDesc.Path, PlugDesc.SubFolder, 'set_parameters.m');
            skipLines = 2;
        case 'ultramegasort2000'
            optionFile = bst_fullfile(PlugDesc.Path, PlugDesc.SubFolder, 'ss_default_params.m');
            skipLines = 2;
            skipValidate = 1;
        case 'kilosort'
            optionFile = bst_fullfile(PlugDesc.Path, PlugDesc.SubFolder, 'KilosortStandardConfig.m');
    end
    % Handling errors: File not found
    if ~file_exist(optionFile)
        error(['File not found: ' optionFile]);
    end
end


%% ===== VALIDATE OPTIONS FILE =====
function passed = ValidateOptions(textOptions)
    try
        eval(textOptions);
        passed = 1;
    catch
        java_dialog('error', ...
            ['An error occurred.' 10 'Please double check your changes, valid Matlab code is required.'], ...
            'Spike Sorter Options');
        passed = 0;
    end
end
