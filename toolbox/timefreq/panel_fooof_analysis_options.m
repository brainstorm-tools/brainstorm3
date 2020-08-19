function varargout = panel_fooof_analysis_options(varargin)
% PANEL_FOOOF_ANALYSIS_OPTIONS: Options for analyzing FOOOF models.
% 
% USAGE:  bstPanelNew = panel_fooof_analysis_options('CreatePanel')
%                   s = panel_fooof_analysis_options('GetPanelContents')

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
% Authors: Francois Tadel, Martin Cousineau, Luc Wilson 2020

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(sProcess, sFiles)  %#ok<DEFNU>
    panelName = 'FOOOFAnalysisOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    
    extPeaks = sProcess.options.extPeaks.Value;
    extAper = sProcess.options.extAper.Value;
    extStats = sProcess.options.extStats.Value;
    % Create main main panel
    jPanelNew = gui_river('Manage FOOOF analysis options');
    options = bst_get('TimefreqOptions_fooof_analysis');
    
    % In case no options selected
    if ~any([extPeaks extStats])
        jPanelNote = gui_river();
        if any(extAper) % Modular if statement
            gui_component('label', jPanelNote, [], 'No options available for selected feature(s)');
        else
            gui_component('label', jPanelNote, [], 'Please select at least one feature to extract');
        end
        jPanelNew.add('br', jPanelNote);
    end
    
% ===== PEAK EXTRACTION =====
    jPanelPeaks = gui_river([1,1],[],'Peak Extraction Settings');
                        gui_component('label', jPanelPeaks, [], 'Sort peaks using: ');
    jButtonGroup = ButtonGroup();
        jRadioOrder =   gui_component('radio', jPanelPeaks, [], 'Peak Parameters', jButtonGroup,[], @UpdatePeakOption);
        jRadioFreqBands=gui_component('radio', jPanelPeaks, [], 'Frequency Bands', jButtonGroup, [], @UpdatePeakOption);
    jRadioOrder.setSelected(options.PeakType == 1);
    jRadioFreqBands.setSelected(options.PeakType == 2);
                        gui_component('label', jPanelPeaks, 'br', 'Sort by Peak... ');
    jButtonGroup2 = ButtonGroup();                    
        jRadioFreq =    gui_component('radio', jPanelPeaks, [], 'Frequency', jButtonGroup2); 
        jRadioAmp =     gui_component('radio', jPanelPeaks, [], 'Amplitude', jButtonGroup2); 
        jRadioStd =     gui_component('radio', jPanelPeaks, [], 'St. Dev. ', jButtonGroup2); 
    jRadioFreq.setSelected(options.SortBy == 1);
    jRadioAmp.setSelected(options.SortBy == 2);
    jRadioStd.setSelected(options.SortBy == 3);
    strFreqBands = process_fooof_bands('FormatBands', options.FreqBands);
    jTextFreqBands =    gui_component('textfreq', jPanelPeaks, 'br hfill', strFreqBands);
    % Button Reset
    jButtonFreqBands =  gui_component('button', jPanelPeaks, 'br', 'Reset', [], [], @ResetFreqBands);
    jButtonFreqBands.setMargin(Insets(0,3,0,3));
    % Only display if desired
    if extPeaks
        jPanelNew.add('br', jPanelPeaks);
    end
    % ===== STATS EXTRACTION =====
    jPanelStats = gui_river([1,1],[],'Stat Extraction Settings');
                        gui_component('label', jPanelStats, [], 'Extract: ');
    jCheckMSE =         gui_component('Checkbox', jPanelStats, [], 'MSE');
    jCheckR2 =          gui_component('Checkbox', jPanelStats, [], 'R-squared');
    jCheckFreqError =   gui_component('Checkbox', jPanelStats, [], 'Absolute Error by Frequency');
    jCheckMSE.setSelected(options.pullMSE);
    jCheckR2.setSelected(options.pullR2);
    jCheckFreqError.setSelected(options.pullFreqError);
    if extStats
        jPanelNew.add('br', jPanelStats);
    end
    
    % ===== VALIDATION BUTTON =====
    gui_component('Button', jPanelNew, 'br right', 'OK', [], [], @ButtonOk_Callback);

    % ===== PANEL CREATION =====
    % Put everything in a big scroll panel
    jPanelScroll = javax.swing.JScrollPane(jPanelNew);

    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Controls list
    ctrl = struct('jRadioOrder',         jRadioOrder, ...
                  'jRadioFreqBands',     jRadioFreqBands, ...
                  'jRadioFreq',          jRadioFreq, ...
                  'jRadioAmp',           jRadioAmp, ...
                  'jRadioStd',           jRadioStd, ...
                  'jTextFreqBands',      jTextFreqBands, ...
                  'jButtonFreqBands',    jButtonFreqBands,...
                  'jCheckMSE',           jCheckMSE, ...
                  'jCheckR2',            jCheckR2, ...
                  'jCheckFreqError',     jCheckFreqError);
    % Callback to frequency option
    UpdatePeakOption()
    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, jPanelScroll, ctrl);
    
%% =================================================================================
%  === INTERNAL CALLBACK ===========================================================
%  =================================================================================
%% ===== OK BUTTON =====
    function ButtonOk_Callback(varargin)
        % Save panel values
        GetPanelContents();
        % Release mutex and keep the panel opened
        bst_mutex('release', panelName);
    end

%% ===== ALL FREQS CHECKBOX =====
    function UpdatePeakOption(varargin)
        if jRadioOrder.isSelected()
            jRadioFreq.setEnabled(1);
            jRadioAmp.setEnabled(1);
            jRadioStd.setEnabled(1);
            jTextFreqBands.setEnabled(0);
            jButtonFreqBands.setEnabled(0);
        elseif jRadioFreqBands.isSelected()
            jRadioFreq.setEnabled(0);
            jRadioAmp.setEnabled(0);
            jRadioStd.setEnabled(0);
            jTextFreqBands.setEnabled(1);
            jButtonFreqBands.setEnabled(1);
        end
    end
    %% ===== RESET FREQ BANDS =====
    function ResetFreqBands(varargin)
        % Get default options
        TimefreqOptions = bst_get('TimefreqOptions_fooof_analysis');
        TimefreqOptions = rmfield(TimefreqOptions, 'FreqBands');
        bst_set('TimefreqOptions_fooof_analysis', TimefreqOptions);
        TimefreqOptions = bst_get('TimefreqOptions_fooof_analysis');
        % Update text field
        strFreqBands = process_fooof_bands('FormatBands', TimefreqOptions.FreqBands);
        jTextFreqBands.setText(strFreqBands);
    end
end

%% =================================================================================
%  === EXTERNAL CALLBACK ===========================================================
%  =================================================================================   
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents()
    ctrl = bst_get('PanelControls', 'FOOOFAnalysisOptions');
    s = bst_get('TimefreqOptions_fooof_analysis');
    if isempty(ctrl) % If options not opened
        return;
    end
    s.PeakType = ctrl.jRadioFreqBands.isSelected()+1;
    if ctrl.jRadioFreq.isSelected()
        s.SortBy = 1;
        elseif ctrl.jRadioAmp.isSelected()
        s.SortBy = 2; else
        s.SortBy = 3;
    end
    if s.PeakType == 2
        s.FreqBands = process_fooof_bands('ParseBands', char(ctrl.jTextFreqBands.getText()));
    end
    s.pullMSE = ctrl.jCheckMSE.isSelected();
    s.pullR2 = ctrl.jCheckR2.isSelected();
    s.pullFreqError = ctrl.jCheckFreqError.isSelected();
    bst_set('TimefreqOptions_fooof_analysis', s);
end