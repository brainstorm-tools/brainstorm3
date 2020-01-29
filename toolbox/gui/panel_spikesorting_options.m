function varargout = panel_spikesorting_options(varargin)
% PANEL_SPIKESORTING_OPTIONS: Options for spike sorting computation.
% 
% USAGE:  bstPanelNew = panel_spikesorting_options('CreatePanel')
%                   s = panel_spikesorting_options('GetPanelContents')

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
% Authors: Martin Cousineau, 2018

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
    
    % Create main main panel
    jPanelNew = gui_river();

    % ===== FREQUENCY PANEL =====
    jTextOptions = gui_component('textarea', jPanelNew, 'br hfill', 'test');
    
    % ===== VALIDATION BUTTON =====
    gui_component('Button', jPanelNew, 'br right', 'OK', [], [], @ButtonOk_Callback);

    % ===== PANEL CREATION =====
    % Put everything in a big scroll panel
    jPanelScroll = javax.swing.JScrollPane(jPanelNew);
    %jPanelScroll.add(jPanelNew);
    %jPanelScroll.setPreferredSize(jPanelNew.getPreferredSize());
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Controls list
    ctrl = struct('jTextOptions',    jTextOptions, ...
        'spikeSorter', spikeSorter);
    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, jPanelScroll, ctrl);
    
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
                header = [char(join(header, newline)) newline];
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
        [optionFile, skipLines] = GetSpikeSorterOptionFile(spikeSorter);
        
        if exist(optionFile, 'file') ~= 2
            java_dialog('error', 'Could not find spike-sorter''s parameters file.');
            bstPanelNew = [];
            bst_mutex('release', panelName);
            return;
        end
        
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
        jTextOptions.setText(char(join(optionText, newline)));
    end
end

function [optionFile, skipLines, skipValidate] = GetSpikeSorterOptionFile(spikeSorter)
    skipLines = 0;
    skipValidate = 0;
    
    switch lower(spikeSorter)
        case 'waveclus'
            optionFile = bst_fullfile(bst_get('BrainstormUserDir'), 'waveclus', 'set_parameters.m');
            skipLines = 2;

        case 'ultramegasort2000'
            optionFile = bst_fullfile(bst_get('BrainstormUserDir'), 'UltraMegaSort2000', 'ss_default_params.m');
            skipLines = 2;
            skipValidate = 1;
            
        case 'kilosort'
            optionFile = bst_fullfile(bst_get('BrainstormUserDir'), 'kilosort', 'KilosortStandardConfig.m');

        otherwise
            error('The chosen spike sorter is currently unsupported by Brainstorm.');
    end
    
    % Check whether the file exists, i.e. the spike sorter is installed
    if exist(optionFile, 'file') ~= 2
        if java_dialog('confirm', ...
                ['The ' spikeSorter ' spike-sorter is not installed on your computer.' 10 10 ...
                 'Download and install the latest version?'], spikeSorter)
            switch lower(spikeSorter)
                case 'waveclus'
                    process_spikesorting_waveclus('downloadAndInstallWaveClus');

                case 'ultramegasort2000'
                    process_spikesorting_ultramegasort2000('downloadAndInstallUltraMegaSort2000');

                case 'kilosort'
                    process_spikesorting_kilosort('downloadAndInstallKiloSort');

                otherwise
                    error('The chosen spike sorter is currently unsupported by Brainstorm.');
            end
        end
    end
end

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
