function varargout = panel_wmne(varargin)
% PANEL_WMNE: Options for Minimum Norm estimation (GUI).
% 
% USAGE:  bstPanelNew = panel_wmne('CreatePanel', OPTIONS, DataTypes)
%         bstPanelNew = panel_wmne('CreatePanel', sProcess, sFiles)
%                   s = panel_wmne('GetPanelContents')

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
% Authors: Francois Tadel, 2010-2012

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(OPTIONS, DataTypes)  %#ok<DEFNU>  
    panelName = 'InverseOptionsWMNE';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % CALL:  panel_wmne('CreatePanel', OPTIONS, DataTypes)
    if iscell(DataTypes)
        f = OPTIONS.flagSourceOrient;
    % CALL:  panel_wmne('CreatePanel', sProcess, sFiles)
    else
        sProcess = OPTIONS;
        sFiles   = DataTypes;
        OPTIONS  = sProcess.options.wmne.Value;
        % List of sensors
        DataTypes = intersect(sFiles(1).ChannelTypes, {'MEG MAG', 'MEG GRAD', 'MEG', 'EEG', 'ECOG', 'SEEG'});
        if any(ismember({'MEG MAG','MEG GRAD'}, DataTypes))
            DataTypes = setdiff(DataTypes, 'MEG');
        end
        % Default source orientation
        if isempty(OPTIONS.SourceOrient)
            f = [0 0 0 0];
        else
            f = [1 1 1 1];
            switch (OPTIONS.SourceOrient{1})
                case 'fixed',      f(1) = 2;
                case 'loose',      f(2) = 2;
                case 'free',       f(3) = 2;
                case 'truncated',  f(4) = 2;
            end
        end
    end
    % Constants
    TEXT_WIDTH  = 40;
    DEFAULT_HEIGHT = 20;
    % Create main main panel
    jPanelNew = gui_river();
    
    % ===== SOURCE ORIENTATION =====   
    jPanelOrient = gui_river([1,1], [0,6,6,6], 'Source orientations');
        jButtonGroupOrient = ButtonGroup();
        % Source orientation : Constrained
        jPanelOrient.add(JLabel(''));
        jRadioOrientConstr = JRadioButton('Constrained (Normal / cortex)');
        jRadioOrientConstr.setSelected(f(1) == 2);
        jRadioOrientConstr.setEnabled(f(1) > 0);
        java_setcb(jRadioOrientConstr, 'ActionPerformedCallback', @(h,ev)UpdatePanel());
        jButtonGroupOrient.add(jRadioOrientConstr);
        jPanelOrient.add(jRadioOrientConstr);
        % Source orientation : Loose
        jPanelOrient.add('br', JLabel(''));
        jRadioOrientLoose = JRadioButton('Loose');
        jRadioOrientLoose.setSelected(f(2) == 2);
        jRadioOrientLoose.setEnabled(f(2) > 0);
        java_setcb(jRadioOrientLoose, 'ActionPerformedCallback', @(h,ev)UpdatePanel());
        jButtonGroupOrient.add(jRadioOrientLoose);
        jPanelOrient.add(jRadioOrientLoose);
        % Amount of looseness (Label)
        jLabelLoose = JLabel('');
        jPanelOrient.add(jLabelLoose);
        % Amount of looseness (Text)
        jTextLoose = JTextField(num2str(OPTIONS.loose));
        jTextLoose.setPreferredSize(java_scaled('dimension', TEXT_WIDTH, DEFAULT_HEIGHT));
        jTextLoose.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
        jPanelOrient.add(jTextLoose);
        % Source orientation : Unconstrained
        jPanelOrient.add('br', JLabel(''));
        jRadioOrientUnconstr = JRadioButton('Unconstrained');
        jRadioOrientUnconstr.setSelected(f(3) == 2);
        jRadioOrientUnconstr.setEnabled(f(3) > 0);
        java_setcb(jRadioOrientUnconstr, 'ActionPerformedCallback', @(h,ev)UpdatePanel());
        jButtonGroupOrient.add(jRadioOrientUnconstr);
        jPanelOrient.add(jRadioOrientUnconstr);
        % Source orientation : Truncated
        jPanelOrient.add('br', JLabel(''));
        jRadioOrientTrunc = JRadioButton('Truncated (remove radial component)');
        jRadioOrientTrunc.setSelected(f(4) == 2);
        jRadioOrientTrunc.setEnabled(f(4) > 0);
        java_setcb(jRadioOrientTrunc, 'ActionPerformedCallback', @(h,ev)UpdatePanel());
        jButtonGroupOrient.add(jRadioOrientTrunc);
        jPanelOrient.add(jRadioOrientTrunc);
    jPanelNew.add('br hfill', jPanelOrient);

    % ===== SIGNAL PROPERTIES ======
    jPanelSignal = gui_river([1,2], [5,15,15,10], 'Signal properties');
        % Estimated SNR (Label)
        jPanelSignal.add(JLabel('Signal-to-noise ratio (SNR): '));
        % Estimated SNR (Text)
        jTextSnr = JTextField(num2str(OPTIONS.SNR));
        jTextSnr.setPreferredSize(java_scaled('dimension', TEXT_WIDTH, DEFAULT_HEIGHT));
        jTextSnr.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
        jPanelSignal.add('tab', jTextSnr);
        % Use PCA whitening
        is_pca = ~OPTIONS.diagnoise && OPTIONS.pca;
        jCheckPca = gui_component('CheckBox', jPanelSignal, 'br', 'Whitening: PCA', [], [], @(h,ev)eval(sprintf('OPTIONS.pca=%d;',ev.getSource().isSelected())), []);
        jCheckPca.setEnabled(~OPTIONS.diagnoise);
        jCheckPca.setSelected(is_pca);
    jPanelNew.add('br hfill', jPanelSignal);
        
    % ===== NOISE COVARIANCE MATRIX =====
    jPanelNoisecov = gui_river([1,2], [5,15,15,10], 'Noise covariance matrix');
        buttonGroup = ButtonGroup();
        % Diagonal noise covariance
        jRadioFullnoise = gui_component('Radio', jPanelNoisecov, 'br', 'Full noise covariance', [], [], @UpdatePanel, []);
        jRadioFullnoise.setSelected(~OPTIONS.diagnoise);
        buttonGroup.add(jRadioFullnoise);
        % Full noise covariance
        jRadioDiagnoise = gui_component('Radio', jPanelNoisecov, 'br', 'Diagonal noise covariance', [], [], @UpdatePanel, []);
        jRadioDiagnoise.setSelected(OPTIONS.diagnoise);
        buttonGroup.add(jRadioDiagnoise);
        % Regularize noise covariance
        jCheckRegnoise = gui_component('CheckBox', jPanelNoisecov, 'br', 'Regularize noise covariance', [], [], @UpdatePanel, []);
        jCheckRegnoise.setSelected(OPTIONS.regnoise);
        
        % Regularization of MEG MAG 
        if ismember('MEG MAG', DataTypes)
            % Label
            jLabelMagreg = JLabel('       Reg. for MEG MAG: ');
            jPanelNoisecov.add('br', jLabelMagreg);
            % Text
            jTextMagreg = JTextField(num2str(OPTIONS.magreg));
            jTextMagreg.setPreferredSize(java_scaled('dimension', TEXT_WIDTH, DEFAULT_HEIGHT));
            jTextMagreg.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jPanelNoisecov.add('tab', jTextMagreg);
        else
            jLabelMagreg = [];
            jTextMagreg = [];
        end
        
        % Regularization of MEG GRAD 
        if ismember('MEG GRAD', DataTypes)
            % Label
            jLabelGradreg = JLabel('       Reg. for MEG GRAD: ');
            jPanelNoisecov.add('br', jLabelGradreg);
            % Text
            jTextGradreg = JTextField(num2str(OPTIONS.gradreg));
            jTextGradreg.setPreferredSize(java_scaled('dimension', TEXT_WIDTH, DEFAULT_HEIGHT));
            jTextGradreg.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jPanelNoisecov.add('tab', jTextGradreg);
        else
            jLabelGradreg = [];
            jTextGradreg = [];
        end
        
        % Regularization of MEG (ALL)
        if ismember('MEG', DataTypes)
            % Label
            jLabelMegreg = JLabel('       Reg. for MEG: ');
            jPanelNoisecov.add('br', jLabelMegreg);
            % Text
            jTextMegreg = JTextField(num2str(OPTIONS.gradreg));
            jTextMegreg.setPreferredSize(java_scaled('dimension', TEXT_WIDTH, DEFAULT_HEIGHT));
            jTextMegreg.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jPanelNoisecov.add('tab', jTextMegreg);
        else
            jLabelMegreg = [];
            jTextMegreg = [];
        end
        
        % Regularization of EEG
        if ismember('EEG', DataTypes)
            % Label
            jLabelEegreg = JLabel('       Reg. for EEG: ');
            jPanelNoisecov.add('br', jLabelEegreg);
            % Text
            jTextEegreg = JTextField(num2str(OPTIONS.eegreg));
            jTextEegreg.setPreferredSize(java_scaled('dimension', TEXT_WIDTH, DEFAULT_HEIGHT));
            jTextEegreg.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jPanelNoisecov.add('tab', jTextEegreg);
        else
            jLabelEegreg = [];
            jTextEegreg = [];
        end
        
        % Regularization of ECOG
        if ismember('ECOG', DataTypes)
            % Label
            jLabelEcogreg = JLabel('       Reg. for ECOG: ');
            jPanelNoisecov.add('br', jLabelEcogreg);
            % Text
            jTextEcogreg = JTextField(num2str(OPTIONS.ecogreg));
            jTextEcogreg.setPreferredSize(java_scaled('dimension', TEXT_WIDTH, DEFAULT_HEIGHT));
            jTextEcogreg.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jPanelNoisecov.add('tab', jTextEcogreg);
        else
            jLabelEcogreg = [];
            jTextEcogreg = [];
        end
        % Regularization of SEEG
        if ismember('SEEG', DataTypes)
            % Label
            jLabelSeegreg = JLabel('       Reg. for SEEG: ');
            jPanelNoisecov.add('br', jLabelSeegreg);
            % Text
            jTextSeegreg = JTextField(num2str(OPTIONS.seegreg));
            jTextSeegreg.setPreferredSize(java_scaled('dimension', TEXT_WIDTH, DEFAULT_HEIGHT));
            jTextSeegreg.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jPanelNoisecov.add('tab', jTextSeegreg);
        else
            jLabelSeegreg = [];
            jTextSeegreg = [];
        end
    jPanelNew.add('br hfill', jPanelNoisecov);

    
    % ===== DEPTH WEIGHTING ======
    jPanelDepth = gui_river([1,2], [5,15,15,10], 'Depth weighting');
        % Use depth weighting
        jCheckDepth = JCheckBox('Use depth weighting', OPTIONS.depth);
        java_setcb(jCheckDepth, 'ActionPerformedCallback', @(h,ev)UpdatePanel());
        jPanelDepth.add(jCheckDepth);
        
        % Weightexp (Label)
        jLabelWeightexp = JLabel('       Order [0,1]: ');
        jPanelDepth.add('br', jLabelWeightexp);
        % weightexp (Text)
        jTextWeightexp = JTextField(num2str(OPTIONS.weightexp));
        jTextWeightexp.setPreferredSize(java_scaled('dimension', TEXT_WIDTH, DEFAULT_HEIGHT));
        jTextWeightexp.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
        jPanelDepth.add('tab', jTextWeightexp);

        % Weightexp (Label)
        jLabelWeightlimit = JLabel('       Maximal amount: ');
        jPanelDepth.add('br', jLabelWeightlimit);
        % weightexp (Text)
        jTextWeightlimit = JTextField(num2str(OPTIONS.weightlimit));
        jTextWeightlimit.setPreferredSize(java_scaled('dimension', TEXT_WIDTH, DEFAULT_HEIGHT));
        jTextWeightlimit.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
        jPanelDepth.add('tab', jTextWeightlimit);
    jPanelNew.add('br hfill', jPanelDepth);

    % ===== VALIDATION BUTTONS =====
    gui_component('button', jPanelNew, 'br right', 'Cancel', [], [], @ButtonCancel_Callback, []);
    gui_component('button', jPanelNew, [], 'OK', [], [], @ButtonOk_Callback, []);

    % ===== PANEL CREATION =====
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Controls list
    ctrl = struct('jRadioOrientConstr',   jRadioOrientConstr, ...
                  'jRadioOrientUnconstr', jRadioOrientUnconstr, ...
                  'jRadioOrientLoose',    jRadioOrientLoose, ...
                  'jRadioOrientTrunc',    jRadioOrientTrunc, ...
                  'jLabelLoose',          jLabelLoose, ...
                  'jTextLoose',           jTextLoose, ...
                  'jTextSnr',             jTextSnr, ...
                  'jLabelMegreg',         jLabelMegreg, ...
                  'jLabelMagreg',         jLabelMagreg, ...
                  'jLabelGradreg',        jLabelGradreg, ...
                  'jLabelEegreg',         jLabelEegreg, ...
                  'jLabelEcogreg',        jLabelEcogreg, ...
                  'jLabelSeegreg',        jLabelSeegreg, ...
                  'jTextMegreg',          jTextMegreg, ...
                  'jTextMagreg',          jTextMagreg, ...
                  'jTextGradreg',         jTextGradreg, ...
                  'jTextEegreg',          jTextEegreg, ...
                  'jTextEcogreg',         jTextEcogreg, ...
                  'jTextSeegreg',         jTextSeegreg, ...
                  'jRadioDiagnoise',      jRadioDiagnoise, ...
                  'jRadioFullnoise',      jRadioFullnoise, ...
                  'jCheckRegnoise',       jCheckRegnoise, ...
                  'jCheckPca',            jCheckPca, ...
                  'jCheckDepth',          jCheckDepth, ...
                  'jLabelWeightexp',      jLabelWeightexp, ...
                  'jLabelWeightlimit',    jLabelWeightlimit, ...
                  'jTextWeightexp',       jTextWeightexp, ...
                  'jTextWeightlimit',     jTextWeightlimit);
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);
    % Update panel
    UpdatePanel();
    

%% =================================================================================
%  === INTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== CANCEL BUTTON =====
    function ButtonCancel_Callback(hObject, event)
        % Close panel without saving (release mutex automatically)
        gui_hide(panelName);
    end

%% ===== OK BUTTON =====
    function ButtonOk_Callback(varargin)       
        % Release mutex and keep the panel opened
        bst_mutex('release', panelName);
    end

%% ===== UPDATE PANEL =====
    function UpdatePanel(varargin)
        % Loose orientation
        isLoose = jRadioOrientLoose.isSelected();
        jLabelLoose.setEnabled(isLoose);
        jTextLoose.setEnabled(isLoose || all(f==0));
        % Whitening
        isDiagnoise = jRadioDiagnoise.isSelected();
        jCheckPca.setEnabled(~isDiagnoise);
        jCheckPca.setSelected(~isDiagnoise && OPTIONS.pca);
        % Regularized/diagonal noise covariance matrix
        isRegNoise = jCheckRegnoise.isSelected();
        if ~isempty(jTextMagreg)
            jLabelMagreg.setEnabled(isRegNoise);
            jTextMagreg.setEnabled(isRegNoise);
        end
        if ~isempty(jTextGradreg)
            jLabelGradreg.setEnabled(isRegNoise);
            jTextGradreg.setEnabled(isRegNoise);
        end
        if ~isempty(jTextMegreg)
            jLabelMegreg.setEnabled(isRegNoise);
            jTextMegreg.setEnabled(isRegNoise);
        end        
        if ~isempty(jTextEegreg)
            jLabelEegreg.setEnabled(isRegNoise);
            jTextEegreg.setEnabled(isRegNoise);
        end
        if ~isempty(jTextEcogreg)
            jLabelEcogreg.setEnabled(isRegNoise);
            jTextEcogreg.setEnabled(isRegNoise);
        end
        if ~isempty(jTextSeegreg)
            jLabelSeegreg.setEnabled(isRegNoise);
            jTextSeegreg.setEnabled(isRegNoise);
        end
        % Depth weighting
        isDepth = jCheckDepth.isSelected();
        jLabelWeightexp.setEnabled(isDepth);
        jLabelWeightlimit.setEnabled(isDepth);
        jTextWeightexp.setEnabled(isDepth);
        jTextWeightlimit.setEnabled(isDepth);
    end
end



%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================   
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents() %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'InverseOptionsWMNE');
    
    % ===== SOURCE ORIENTATION =====
    if ctrl.jRadioOrientConstr.isSelected()
        s.SourceOrient = {'fixed'};
    elseif ctrl.jRadioOrientLoose.isSelected()
        s.SourceOrient = {'loose'};
    elseif ctrl.jRadioOrientUnconstr.isSelected()
        s.SourceOrient = {'free'};
    elseif ctrl.jRadioOrientTrunc.isSelected()
        s.SourceOrient = {'truncated'};
    end
    % Loose parameter
    s.loose = str2double(char(ctrl.jTextLoose.getText()));
    if isempty(s.loose) || isnan(s.loose)
        error('Invalid value for loose parameter.');
    end
    
    % ===== SIGNAL PROPERTIES =====
    % SNR
    s.SNR = str2double(char(ctrl.jTextSnr.getText()));
    if isempty(s.SNR) || isnan(s.SNR)
        error('Invalid value for SNR.');
    end
    % PCA
    s.pca = ctrl.jCheckPca.isSelected();
    % Diagonal noise covariance
    s.diagnoise = ctrl.jRadioDiagnoise.isSelected();
    % Regularize
    s.regnoise = ctrl.jCheckRegnoise.isSelected();
    % Regularization for MEG (ALL)
    if ~isempty(ctrl.jTextMegreg)
        % Save the same value for MAG and GRAD
        s.magreg = str2double(char(ctrl.jTextMegreg.getText()));
        if isempty(s.magreg) || isnan(s.magreg) || (s.magreg > 1) || (s.magreg < 0)
            error('Invalid value for MEG MAG regularization.');
        end
        s.gradreg = s.magreg;
    end
    % Regularization for MEG MAG
    if ~isempty(ctrl.jTextMagreg)
        s.magreg = str2double(char(ctrl.jTextMagreg.getText()));
        if isempty(s.magreg) || isnan(s.magreg) || (s.magreg > 1) || (s.magreg < 0)
            error('Invalid value for MEG MAG regularization.');
        end
    end
    % Regularization for MEG GRAD
    if ~isempty(ctrl.jTextGradreg)
        s.gradreg = str2double(char(ctrl.jTextGradreg.getText()));
        if isempty(s.gradreg) || isnan(s.gradreg) || (s.gradreg > 1) || (s.gradreg < 0)
            error('Invalid value for MEG GRAD regularization.');
        end
    end
    % Regularization for EEG
    if ~isempty(ctrl.jTextEegreg)
        s.eegreg = str2double(char(ctrl.jTextEegreg.getText()));
        if isempty(s.eegreg) || isnan(s.eegreg) || (s.eegreg > 1) || (s.eegreg < 0)
            error('Invalid value for EEG regularization.');
        end
    end
    % Regularization for ECOG
    if ~isempty(ctrl.jTextEcogreg)
        s.ecogreg = str2double(char(ctrl.jTextEcogreg.getText()));
        if isempty(s.ecogreg) || isnan(s.ecogreg) || (s.ecogreg > 1) || (s.ecogreg < 0)
            error('Invalid value for ECOG regularization.');
        end
    end
    % Regularization for SEEG
    if ~isempty(ctrl.jTextSeegreg)
        s.seegreg = str2double(char(ctrl.jTextSeegreg.getText()));
        if isempty(s.seegreg) || isnan(s.seegreg) || (s.seegreg > 1) || (s.seegreg < 0)
            error('Invalid value for SEEG regularization.');
        end
    end
    
    % ===== DEPTH WEIGHTING =====
    % Use depth weighting
    s.depth = ctrl.jCheckDepth.isSelected();
    % weightexp
    s.weightexp = str2double(char(ctrl.jTextWeightexp.getText()));
    if isempty(s.weightexp) || isnan(s.weightexp) || (s.weightexp > 1) || (s.weightexp < 0)
        error('Invalid value for weightexp.');
    end
    % weightlim
    s.weightlimit = str2double(char(ctrl.jTextWeightlimit.getText()));
    if isempty(s.weightlimit) || isnan(s.weightlimit) 
        error('Invalid value for weightlimit.');
    end
end





