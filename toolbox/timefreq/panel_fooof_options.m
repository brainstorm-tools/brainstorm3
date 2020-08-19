function varargout = panel_fooof_options(varargin)
% PANEL_FOOOF_OPTIONS: Options for FOOOF modelling.
% 
% USAGE:  bstPanelNew = panel_fooof_options('CreatePanel')
%                   s = panel_fooof_options('GetPanelContents')

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
    panelName = 'FOOOFOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    
    fooof_type = sProcess.options.fooofType.Value;
    panelTitle = ['Displaying options for FOOOF type: ', ...
        sProcess.options.fooofType.Comment{fooof_type}];
    % Create main main panel
    jPanelNew = gui_river(panelTitle);
    options = bst_get('TimefreqOptions_fooof');
    
    % ===== FREQUENCY RANGE =====
    jPanelFreqs = gui_river([1,1]);
                            gui_component('label', jPanelFreqs, [], 'Frequency range for analysis:');
        jTextFreqLower =    gui_component('text', jPanelFreqs, 'hfill', []);
        jTextFreqLower.setHorizontalAlignment(javax.swing.JTextField.RIGHT);
                            gui_component('label', jPanelFreqs, [], ' - ');
        jTextFreqUpper =    gui_component('text', jPanelFreqs, 'hfill', []);
        jTextFreqUpper.setHorizontalAlignment(javax.swing.JTextField.RIGHT);
                            gui_component('label', jPanelFreqs, [], ' Hz  ');
        jCheckFreqAll =     gui_component('checkbox', jPanelFreqs, [], 'All frequencies', [], [], @AllFreqCallback);
        jCheckFreqAll.setSelected(options.allFreqs)
        precision = 1; bounds = {-1e30, 1e30, 10};
        valUnits = gui_validate_text(jTextFreqLower, [], jTextFreqUpper, bounds, 'Hz', precision, options.freqRange(1), []);
        gui_validate_text(jTextFreqUpper, jTextFreqLower, [], bounds, valUnits, precision, options.freqRange(2), []);
    jPanelNew.add('br', jPanelFreqs);
    
    % ===== PEAK TYPE =====
    if fooof_type == 1
        jPanelPeakType = gui_river([1,1]);
                            gui_component('label', jPanelPeakType, 'br', 'Peak Model:');
        jButtonGroup2 = ButtonGroup();
            jRadioGauss =   gui_component('radio', jPanelPeakType, [], 'Gaussian', jButtonGroup2);
            jRadioCauchy =  gui_component('radio', jPanelPeakType, [], 'Cauchy*', jButtonGroup2);
            jRadioBest =    gui_component('radio', jPanelPeakType, [], 'Best of Both*', jButtonGroup2);
                            gui_component('label', jPanelPeakType, [], '(* experimental)');
        % Maintain selected option
        jRadioGauss.setSelected(options.peakType == 1);
        jRadioCauchy.setSelected(options.peakType == 2);
        jRadioBest.setSelected(options.peakType == 3);
        jPanelNew.add('br', jPanelPeakType);
    end
    
    % ===== PEAK WIDTH LIMITS =====
    jPanelPeakWidth = gui_river([1,1]);
                                gui_component('label', jPanelPeakWidth, [], 'Peak Width Limits:');
        jTextPeakWidthLower =   gui_component('text', jPanelPeakWidth, 'hfill', '0.5');
        jTextPeakWidthLower.setHorizontalAlignment(javax.swing.JTextField.RIGHT);
                                gui_component('label', jPanelPeakWidth, [], ' - ');
        jTextPeakWidthUpper =   gui_component('text', jPanelPeakWidth, 'hfill', '12.0');
        jTextPeakWidthUpper.setHorizontalAlignment(javax.swing.JTextField.RIGHT);
                                gui_component('label', jPanelPeakWidth, [], ' Hz');                
        precision = 1;
        gui_validate_text(jTextPeakWidthLower, [], jTextPeakWidthUpper, bounds, 'Hz', precision, options.peakWidthLimits(1), []);
        gui_validate_text(jTextPeakWidthUpper, jTextPeakWidthLower, [], bounds, 'Hz', precision, options.peakWidthLimits(2),  []);
    jPanelNew.add('br', jPanelPeakWidth);
    
    % ===== MAX NUMBER OF PEAKS =====
    jPanelMaxPeaks = gui_river([1,1]);
                        gui_component('label', jPanelMaxPeaks, [], 'Maximum number of peaks:');
        jTextMaxPeaks = gui_component('text', jPanelMaxPeaks, 'hfill', '3');
        jTextMaxPeaks.setHorizontalAlignment(javax.swing.JTextField.RIGHT);
        precision = 0;
        gui_validate_text(jTextMaxPeaks, [], [], bounds, 'Hz', precision, options.maxPeaks, []);
    jPanelNew.add('br', jPanelMaxPeaks);
    
    % ===== MIN PEAK HEIGHT =====
    jPanelMinPeakH = gui_river([1,1]);
                        gui_component('label', jPanelMinPeakH, [], 'Minimum peak height:');
        jTextMinPeakH = gui_component('text', jPanelMinPeakH, 'hfill', '3.0');
        jTextMinPeakH.setHorizontalAlignment(javax.swing.JTextField.RIGHT);
                        gui_component('label', jPanelMinPeakH, [], ' dB');
        precision = 1;
        gui_validate_text(jTextMinPeakH, [], [], bounds, 'Hz', precision, options.minPeakHeight, []);
    jPanelNew.add('br', jPanelMinPeakH);
    
    % ===== PEAK THRESHOLD =====
    jPanelPeakThresh = gui_river([1,1]);
                            gui_component('label', jPanelPeakThresh, [], 'Peak threshold:');
        jTextPeakThresh =   gui_component('text', jPanelPeakThresh, 'hfill', '2.0');
        jTextPeakThresh.setHorizontalAlignment(javax.swing.JTextField.RIGHT);
                            gui_component('label', jPanelPeakThresh, [], ' stdev of noise');
        precision = 1;
        gui_validate_text(jTextPeakThresh, [], [], bounds, 'Hz', precision, options.peakThresh, []);
    jPanelNew.add('br', jPanelPeakThresh);
    
    % ===== PROXIMITY THRESHOLD =====
    if fooof_type == 1
        jPanelProxThresh = gui_river([1,1]);
                                gui_component('label', jPanelProxThresh, [], 'Proximity Threshold:');
            jTextProxThresh =   gui_component('text', jPanelProxThresh, 'hfill', '2.0');
            jTextProxThresh.setHorizontalAlignment(javax.swing.JTextField.RIGHT);
                                gui_component('label', jPanelProxThresh, [], ' stdev of distribution');
            precision = 1;
            gui_validate_text(jTextProxThresh, [], [], bounds, 'Hz', precision, options.proxThresh, []);
        jPanelNew.add('br', jPanelProxThresh);
    end
    
    % ===== REPEAT THRESHOLDING OPTIONS =====    
    if fooof_type == 1
        jPanelRepOpt = gui_river([1,1]);
            jCheckRep =     gui_component('checkbox', jPanelRepOpt, [], 'Threshold after fitting (experimental)');
        % Maintain selected option
        jCheckRep.setSelected(options.repOpt);
        jPanelNew.add('br', jPanelRepOpt);
    end
    
    % ===== APERIODIC MODE =====
    jPanelAperMode = gui_river([1,1]);
                        gui_component('label', jPanelAperMode, 'br', 'Aperiodic Mode:');
    jButtonGroup1 = ButtonGroup();
        jRadioFixed =   gui_component('radio', jPanelAperMode, [],   'Fixed', jButtonGroup1);
        jRadioKnee =    gui_component('radio', jPanelAperMode, [], 'Knee', jButtonGroup1);
    % Maintain selected option
    jRadioFixed.setSelected(options.aperMode == 1);
    jRadioKnee.setSelected(options.aperMode == 2);
    jPanelNew.add('br', jPanelAperMode);
    
    % ===== GUESS WEIGHT =====
    if fooof_type == 1
        jPanelGuessWeight = gui_river([1,1]);
                         gui_component('label', jPanelGuessWeight, 'br', 'Guess Weight:');
        jButtonGroup3 = ButtonGroup();
            jRadioNone = gui_component('radio', jPanelGuessWeight, [], 'None', jButtonGroup3);
            jRadioWeak = gui_component('radio', jPanelGuessWeight, [], 'Weak', jButtonGroup3);
            jRadioStrong = gui_component('radio', jPanelGuessWeight, [], 'Strong', jButtonGroup3);
        % Set Default
        jRadioNone.setSelected(options.guessWeight == 1);
        jRadioWeak.setSelected(options.guessWeight == 2);
        jRadioStrong.setSelected(options.guessWeight == 3);
        jPanelNew.add('br', jPanelGuessWeight);
    end
    % ===== VALIDATION BUTTON =====
    gui_component('Button', jPanelNew, 'br right', 'OK', [], [], @ButtonOk_Callback);

    % ===== PANEL CREATION =====
    % Put everything in a big scroll panel
    jPanelScroll = javax.swing.JScrollPane(jPanelNew);

    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Controls list
    if fooof_type == 1
        ctrl = struct('jTextFreqLower',      jTextFreqLower, ...
                      'jTextFreqUpper',      jTextFreqUpper, ...
                      'jCheckFreqAll',       jCheckFreqAll, ...
                      'jRadioGauss',         jRadioGauss, ...
                      'jRadioCauchy',        jRadioCauchy, ...
                      'jRadioBest',          jRadioBest, ...
                      'jTextPeakWidthLower', jTextPeakWidthLower, ...
                      'jTextPeakWidthUpper', jTextPeakWidthUpper, ...
                      'jTextMaxPeaks',       jTextMaxPeaks, ...
                      'jTextMinPeakH',       jTextMinPeakH, ...
                      'jTextPeakThresh',     jTextPeakThresh, ...
                      'jTextProxThresh',     jTextProxThresh, ...
                      'jCheckRep',           jCheckRep, ...
                      'jRadioFixed',         jRadioFixed, ...
                      'jRadioKnee',          jRadioKnee, ...
                      'jRadioNone',          jRadioNone, ...
                      'jRadioWeak',          jRadioWeak, ...
                      'jRadioStrong',        jRadioStrong, ...
                      'FooofType',           fooof_type);
    elseif fooof_type == 2
        ctrl = struct('jTextFreqLower',      jTextFreqLower, ...
                      'jTextFreqUpper',      jTextFreqUpper, ...
                      'jCheckFreqAll',       jCheckFreqAll, ...
                      'jTextPeakWidthLower', jTextPeakWidthLower, ...
                      'jTextPeakWidthUpper', jTextPeakWidthUpper, ...
                      'jTextMaxPeaks',       jTextMaxPeaks, ...
                      'jTextMinPeakH',       jTextMinPeakH, ...
                      'jTextPeakThresh',     jTextPeakThresh, ...
                      'jRadioFixed',         jRadioFixed, ...
                      'jRadioKnee',          jRadioKnee, ...
                      'FooofType',           fooof_type);
    end
    % Callback to frequency option
    AllFreqCallback()
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
    function AllFreqCallback(varargin)
        ctrl.jTextFreqLower.setEnabled(~ctrl.jCheckFreqAll.isSelected());
        ctrl.jTextFreqUpper.setEnabled(~ctrl.jCheckFreqAll.isSelected());
    end
end

%% =================================================================================
%  === EXTERNAL CALLBACK ===========================================================
%  =================================================================================   
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents()
    ctrl = bst_get('PanelControls', 'FOOOFOptions');
    s = bst_get('TimefreqOptions_fooof');
    if isempty(ctrl) % If options not opened
        return;
    end
    
    if ctrl.FooofType == 1 % Matlab standalone
        s.freqRange =      [str2double(ctrl.jTextFreqLower.getText()) str2double(ctrl.jTextFreqUpper.getText())];
        s.allFreqs =        ctrl.jCheckFreqAll.isSelected();
        if ctrl.jRadioGauss.isSelected()
            s.peakType = 1;
        elseif ctrl.jRadioCauchy.isSelected()
            s.peakType = 2; else
            s.peakType = 3;
        end
        s.peakWidthLimits =[str2double(ctrl.jTextPeakWidthLower.getText()) str2double(ctrl.jTextPeakWidthUpper.getText())];
        s.maxPeaks =        str2double(ctrl.jTextMaxPeaks.getText());
        s.minPeakHeight =   str2double(ctrl.jTextMinPeakH.getText());
        s.peakThresh =      str2double(ctrl.jTextPeakThresh.getText());
        s.proxThresh =      str2double(ctrl.jTextProxThresh.getText());
        s.repOpt =         ctrl.jCheckRep.isSelected();
        if ctrl.jRadioFixed.isSelected()
            s.aperMode =    1;   else    
            s.aperMode =    2;
        end
        if      ctrl.jRadioNone.isSelected()
            s.guessWeight = 1;   
        elseif  ctrl.jRadioWeak.isSelected()
            s.guessWeight = 2;   else    
            s.guessWeight = 3;
        end
    else % Python
        s.freqRange =      [str2double(ctrl.jTextFreqLower.getText()) str2double(ctrl.jTextFreqUpper.getText())];
        s.allFreqs =        ctrl.jCheckFreqAll.isSelected();
        s.peakWidthLimits =[str2double(ctrl.jTextPeakWidthLower.getText()) str2double(ctrl.jTextPeakWidthUpper.getText())];
        s.maxPeaks =        str2double(ctrl.jTextMaxPeaks.getText());
        s.minPeakHeight =   str2double(ctrl.jTextMinPeakH.getText());
        s.peakThresh =      str2double(ctrl.jTextPeakThresh.getText());
        s.proxThresh =      2; % Corrects bug when using python then matlab 
        s.guessWeight =     1; % versions without opening fooof options
        s.peakType =        1;
        if ctrl.jRadioFixed.isSelected()
            s.aperMode =    1;   else    
            s.aperMode =    2;
        end
    end
    bst_set('TimefreqOptions_fooof', s);
end
